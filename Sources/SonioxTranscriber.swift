import AVFoundation
import Foundation

/// Live speech-to-text through Soniox's real-time WebSocket API, split into utterances.
///
/// One multilingual model follows English and French inside the same sentence, and the
/// culinary glossary (`CulinaryTerms`) is sent as context so French kitchen terms come back
/// spelled correctly. Same surface as `Transcriber` (`onUtterance`, `onFailure`, `append`,
/// `discardCurrent`, `stop`), so it can replace it directly; `start` takes the Soniox API key.
@MainActor
final class SonioxTranscriber {
    enum StartError: LocalizedError {
        case missingAPIKey
        var errorDescription: String? { "Chưa nhập Soniox API key." }
    }

    /// (utterance id, text so far, isFinal)
    var onUtterance: ((UUID, String, Bool) -> Void)?
    /// (utterance id, Vietnamese translation so far). Soniox translates each finalized stretch of
    /// speech right after it, so this can arrive after the utterance's final text.
    var onTranslation: ((UUID, String) -> Void)?
    var onFailure: ((String) -> Void)?

    private static let endpoint = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
    nonisolated private static let chunkBytes = 3_200 // 100 ms of 16 kHz mono PCM16
    /// Silent chunks sent after speech before audio pauses (2 s; endpoints arrive within that).
    nonisolated private static let pauseAfterSilentChunks = 20
    /// Audio sent ahead of the first sound when resuming after a pause (400 ms).
    nonisolated private static let preRollBytes = 4 * chunkBytes
    /// When Soniox falls this far behind the audio sent, start a fresh stream: a line that arrives
    /// later than this is useless in a live conversation, so the stale audio is dropped.
    private static let maxLagMs = 10_000
    /// While audio is being sent, no reply for this long means the stream stalled (measured: Soniox
    /// went silent for 18-20 s with our audio stuck unsent, then closed with 408); start a fresh one.
    private static let stallSeconds = 6.0

    private var apiKey = ""
    private var running = false
    private var generation = 0 // bumped by every start; streams of older starts are ignored
    private var currentID = UUID()
    private var currentFinal = "" // finalized tokens of the utterance in progress
    private var currentPending = "" // its non-final tokens; may still change
    private var discarding = false // skip the rest of a discarded utterance until its <end>
    /// The last final token closed a sentence (or a long clause); the utterance ends at the next word.
    private var atBoundary = false
    /// Soniox translates finalized speech stretch by stretch: the final words of a stretch arrive, then
    /// its translation, which can cover several of our utterances (we split at sentence ends; Soniox may
    /// translate two sentences as one). `untranslated` collects final words per utterance since the last
    /// translation token; the next translation fills that stretch in order, one translated sentence per
    /// spoken sentence, and its last utterance takes the rest, so a mismatch never spills further.
    private var untranslated: [(id: UUID, text: String)] = []
    private var translating: [(id: UUID, text: String)] = []
    private var translatingIndex = 0
    private var translatedInStretch = "" // translation given to translating[translatingIndex] so far
    /// An endpoint came after the stretch: everything before it has been translated.
    private var stretchEnded = false
    private var translations: [UUID: String] = [:] // final translation per utterance
    private var connectedAt = Date()
    private var quickFailures = 0
    private var keepAliveTimer: Timer?
    private var lastMessageAt = Date()

    // Shared with the audio thread, guarded by `lock`.
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var socket: URLSessionWebSocketTask?
    nonisolated(unsafe) private var converter: AVAudioConverter?
    nonisolated(unsafe) private var outgoing = Data()
    nonisolated(unsafe) private var lastSentAt = Date.distantPast
    nonisolated(unsafe) private var sentBytes = 0 // on the current stream, for the debug lag report
    nonisolated private let writtenLock = NSLock()
    nonisolated(unsafe) private var writtenBytes = 0 // of `sentBytes`, handed to the network (writtenLock)
    nonisolated(unsafe) private var silentChunks = 0 // consecutive digitally silent chunks
    nonisolated(unsafe) private var paused = false // not sending audio during a long silence
    nonisolated(unsafe) private var resumedAt = Date.distantPast // last resume after a silence pause
    nonisolated(unsafe) private var leadIn = Data() // last 400 ms of silence, sent first when sound returns
    nonisolated private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!

    func start(apiKey: String) throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw StartError.missingAPIKey }
        self.apiKey = key
        running = true
        generation += 1 // a stream of an earlier start, still closing, no longer counts
        quickFailures = 0
        connect()
        // Soniox closes a stream that receives neither audio nor keepalive for 20 seconds.
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sendKeepAliveIfIdle()
                self?.reconnectIfStalled()
            }
        }
    }

    /// Stops sending audio; words still in flight are finalized and delivered.
    func stop() {
        running = false
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        let (socket, rest) = lock.withLock { () -> (URLSessionWebSocketTask?, Data) in
            defer { self.socket = nil; outgoing.removeAll() }
            return (self.socket, outgoing)
        }
        guard let socket else { return }
        if !rest.isEmpty { socket.send(.data(rest)) { _ in } }
        socket.send(.string("")) { _ in } // empty text frame = end of audio
    }

    /// Drops the utterance in progress (used when the conversation is cleared). Words not yet final
    /// would come back later as part of the next utterance, so Soniox finalizes them now and they are
    /// skipped up to its <fin>; speech after the clear is kept.
    func discardCurrent() {
        if !currentPending.isEmpty, let socket = lock.withLock({ socket }) {
            discarding = true
            socket.send(.string(#"{"type":"finalize"}"#)) { _ in }
        }
        currentID = UUID()
        currentFinal = ""
        currentPending = ""
        resetTranslation() // the cleared rows are gone; later translations of them are dropped
    }

    private func resetTranslation() {
        untranslated = []
        translating = []
        translatingIndex = 0
        translatedInStretch = ""
        translations = [:]
        stretchEnded = false
    }

    /// Called from the audio thread for every captured buffer.
    nonisolated func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let socket else { return }
        if converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
            converter?.downmix = true
        }
        guard let converter,
              let pcm = Self.convert(buffer, with: converter),
              let samples = pcm.int16ChannelData
        else { return }
        outgoing.append(UnsafeBufferPointer(start: samples[0], count: Int(pcm.frameLength)))
        guard outgoing.count >= Self.chunkBytes else { return }
        let chunk = outgoing
        outgoing.removeAll(keepingCapacity: true)

        // Soniox falls further and further behind real time while it receives digital silence
        // (measured: 13 s behind after 150 s of it), so the next sentence arrived 10+ s late or not
        // at all. After a short silence, stop sending audio instead: finalize what was said and keep
        // the stream open with keepalives; on sound, resume at once with 400 ms of pre-roll (the
        // onset chunk itself is always sent whole, so the first syllable is never cut).
        if Self.isSilent(chunk) {
            silentChunks += 1
            if silentChunks > Self.pauseAfterSilentChunks {
                if !paused {
                    paused = true
                    socket.send(.string(#"{"type":"finalize"}"#)) { _ in }
                    DebugLog.log("soniox pause: silence, finalize sent")
                }
                // Once a second, 100 ms of inaudible dither keeps Soniox ready, so speech after a long
                // silence is transcribed as fast as mid-speech (measured: lag stays ~80 ms over 150 s).
                if silentChunks % 10 == 0 { send(Self.dithered(chunk), on: socket) }
                leadIn.append(chunk)
                if leadIn.count > Self.preRollBytes { leadIn.removeFirst(leadIn.count - Self.preRollBytes) }
                return
            }
        } else {
            silentChunks = 0
            if paused {
                paused = false
                resumedAt = Date() // the stall watchdog counts from here, not from the last reply
                DebugLog.log("soniox resume")
                send(leadIn, on: socket)
                leadIn = Data()
            }
        }
        send(chunk, on: socket)
    }

    /// Caller holds `lock`. Takes PCM16 and sends it as 8-bit mu-law: half the bytes, so the stream
    /// keeps up on a slow uplink (measured 31 KB/s to Soniox on a lossy network, below PCM16's 32 KB/s,
    /// and the lag grew without bound). Byte counters stay in PCM16 units.
    nonisolated private func send(_ chunk: Data, on socket: URLSessionWebSocketTask) {
        lastSentAt = Date()
        sentBytes += chunk.count
        let count = chunk.count
        socket.send(.data(Self.muLaw(chunk))) { [weak self] _ in // a broken socket surfaces in the receive loop
            guard let self, DebugLog.enabled else { return }
            self.writtenLock.withLock { self.writtenBytes += count } // not `lock`: send may call back at once
        }
    }

    /// A chunk of the same length holding inaudible noise (+-24 LSB, about -63 dBFS): never digital
    /// zeros, which Soniox falls behind on. Smaller values would round to zero in mu-law.
    nonisolated private static func dithered(_ chunk: Data) -> Data {
        var out = Data(count: chunk.count)
        out.withUnsafeMutableBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in samples.indices { samples[i] = Bool.random() ? 24 : -24 }
        }
        return out
    }

    /// G.711 mu-law encoding of little-endian PCM16 (one byte per sample).
    nonisolated static func muLaw(_ pcm: Data) -> Data {
        var out = Data(count: pcm.count / 2)
        pcm.withUnsafeBytes { source in
            out.withUnsafeMutableBytes { target in
                let samples = source.bindMemory(to: Int16.self)
                let bytes = target.bindMemory(to: UInt8.self)
                for i in bytes.indices { bytes[i] = muLaw(samples[i]) }
            }
        }
        return out
    }

    nonisolated private static func muLaw(_ sample: Int16) -> UInt8 {
        var magnitude = Int(sample)
        let sign = magnitude < 0 ? 0x80 : 0
        magnitude = min(abs(magnitude), 32_635) + 0x84
        var exponent = 7
        while exponent > 0, magnitude & (0x80 << exponent) == 0 { exponent -= 1 }
        let mantissa = (magnitude >> (exponent + 3)) & 0x0F
        return UInt8(~(sign | exponent << 4 | mantissa) & 0xFF)
    }

    /// Digital silence (what the tap delivers while nothing plays), allowing for rounding noise.
    nonisolated private static func isSilent(_ chunk: Data) -> Bool {
        chunk.withUnsafeBytes { bytes in
            stride(from: 0, to: bytes.count - 1, by: 2).allSatisfy { i in
                abs(Int32(Int16(bitPattern: UInt16(bytes[i]) | UInt16(bytes[i + 1]) << 8))) <= 2
            }
        }
    }

    // MARK: - Connection

    private func connect() {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        connectedAt = Date()
        DebugLog.log("soniox connect")
        socket.resume()
        let generation = generation
        Task { await run(socket, generation: generation) }
    }

    private func run(_ socket: URLSessionWebSocketTask, generation: Int) async {
        var failure: String?
        var fatal = false
        var fellBehind = false
        do {
            try await socket.send(.string(Self.configJSON))
            if running, generation == self.generation { // audio flows from here on
                lock.withLock {
                    self.socket = socket
                    sentBytes = 0
                    writtenLock.withLock { writtenBytes = 0 }
                    silentChunks = 0
                    paused = false
                }
            }
            DebugLog.log(String(format: "soniox open after %.2f s", Date().timeIntervalSince(connectedAt)))
            var lastMessage = Date()
            lastMessageAt = lastMessage
            var lastLagReport = Date()
            loop: while true {
                let response = try Self.decode(try await socket.receive())
                if generation != self.generation { break loop } // restarted: a newer stream owns the text
                let quiet = Date().timeIntervalSince(lastMessage)
                if quiet > 3 { DebugLog.log(String(format: "soniox message after %.1f s without one", quiet)) }
                lastMessage = Date()
                lastMessageAt = lastMessage
                if DebugLog.enabled, Date().timeIntervalSince(lastLagReport) >= 5, let processed = response.totalAudioProcMs {
                    lastLagReport = Date()
                    let sentMs = lock.withLock { sentBytes } / 32 // 32 bytes per ms
                    let writtenMs = writtenLock.withLock { writtenBytes } / 32
                    DebugLog.log("soniox lag \(sentMs - processed) ms (sent \(sentMs / 1000) s, not yet written \(sentMs - writtenMs) ms, final lag \(sentMs - (response.finalAudioProcMs ?? 0)) ms)")
                }
                if let code = response.errorCode {
                    failure = "Soniox lỗi \(code): \(response.errorMessage ?? "không rõ")"
                    fatal = [400, 401, 402, 403].contains(code) // retrying won't fix these
                    break loop
                }
                apply(response.tokens ?? [])
                if response.finished == true { break loop }
                if let processed = response.totalAudioProcMs,
                   lock.withLock({ sentBytes }) / 32 - processed > Self.maxLagMs {
                    fellBehind = true
                    break loop
                }
            }
        } catch {
            failure = error.localizedDescription
        }
        lock.withLock { if self.socket === socket { self.socket = nil } }
        socket.cancel(with: .normalClosure, reason: nil)
        DebugLog.log(String(format: "soniox closed after %.0f s: %@", Date().timeIntervalSince(connectedAt),
                            failure ?? (fellBehind ? "fell more than 10 s behind" : "finished")))
        // A stream of an earlier start must not reconnect (a second stream) or touch the new text.
        guard generation == self.generation else { return }
        disconnected(failure: failure, fatal: fatal, immediately: fellBehind)
    }

    private func disconnected(failure: String?, fatal: Bool, immediately: Bool = false) {
        // Never finalized on this connection: keep it as heard. When the last final word closed a
        // sentence, the pending words are the next sentence, so they get their own utterance.
        let pending = currentPending
        currentPending = ""
        if atBoundary, !pending.isEmpty {
            finishUtterance()
            currentFinal = pending
        } else {
            currentFinal += pending
        }
        discarding = false
        finishUtterance()
        resetTranslation() // a closed stream sends no more translations
        guard running else { return } // stopped on purpose
        if let failure {
            quickFailures = Date().timeIntervalSince(connectedAt) < 5 ? quickFailures + 1 : 0
            if fatal || quickFailures >= 3 {
                stop()
                onFailure?(failure)
                return
            }
        }
        if immediately { // fell behind: catch up with live audio now
            connect()
            return
        }
        // Stream ended (300-minute limit) or a transient error: reconnect after a short pause.
        DebugLog.log("soniox reconnect in 1 s")
        Task {
            try? await Task.sleep(for: .seconds(1))
            if running { connect() }
        }
    }

    private func reconnectIfStalled() {
        let (socket, resumedAt) = lock.withLock {
            (!paused && Date().timeIntervalSince(lastSentAt) < 2 ? self.socket : nil, self.resumedAt)
        }
        // After a silence pause, Soniox had nothing to reply to, so the wait starts at the resume.
        let since = max(lastMessageAt, resumedAt)
        guard let socket, Date().timeIntervalSince(since) > Self.stallSeconds else { return }
        DebugLog.log(String(format: "soniox stalled: no reply for %.0f s, reconnecting", Date().timeIntervalSince(since)))
        socket.cancel(with: .goingAway, reason: nil) // the receive loop fails and reconnects
    }

    private func sendKeepAliveIfIdle() {
        let socket = lock.withLock { Date().timeIntervalSince(lastSentAt) > 8 ? self.socket : nil }
        guard let socket else { return }
        DebugLog.log("soniox keepalive")
        socket.send(.string(#"{"type":"keepalive"}"#)) { _ in }
    }

    // MARK: - Utterances

    private func apply(_ tokens: [Response.Token]) {
        guard !tokens.isEmpty else { return }
        var pending = ""
        var pendingTranslation: [UUID: String] = [:]
        var translated: [UUID] = [] // in order, to report
        for token in tokens {
            if token.text == "<end>" || token.text == "<fin>" { // endpoint, or our finalize at a pause
                DebugLog.log("soniox \(token.text)")
                if discarding { discarding = false } else { finishUtterance() }
                pending = ""
                stretchEnded = true
            } else if discarding {
                continue
            } else if token.translationStatus == "translation" {
                guard token.isFinal else { // a provisional translation of the words still being spoken
                    pendingTranslation[currentID, default: ""] += token.text
                    if !translated.contains(currentID) { translated.append(currentID) }
                    continue
                }
                // Words of the next stretch can be final before this stretch's translation is complete;
                // its tail still belongs here.
                if !untranslated.isEmpty {
                    if stretchEnded || stretchTranslated {
                        startTranslatingStretch()
                    } else if let next = untranslated.first, next.id == translating.last?.id {
                        // More words of the same utterance (Soniox translates parts of a sentence):
                        // this translation continues it, so they join the current stretch.
                        translating[translating.count - 1].text += next.text
                        untranslated.removeFirst()
                    }
                }
                guard translatingIndex < translating.count else { continue }
                let id = translating[translatingIndex].id
                if !translated.contains(id) { translated.append(id) }
                translations[id, default: ""] += token.text
                translatedInStretch += token.text
                if translatingIndex < translating.count - 1,
                   Self.sentenceCount(translatedInStretch) >= max(1, Self.sentenceCount(translating[translatingIndex].text)) {
                    translatingIndex += 1
                    translatedInStretch = ""
                }
            } else if token.isFinal {
                // Someone talking without pauses never triggers <end>, so close the utterance at a
                // sentence boundary instead; it can then be translated while they keep talking.
                // Waiting for the next word (leading space) avoids splitting "3.5" or "e.g".
                if atBoundary, token.text.first?.isWhitespace == true { finishUtterance() }
                currentFinal += token.text
                atBoundary = Self.endsUtterance(currentFinal)
                if untranslated.last?.id == currentID {
                    untranslated[untranslated.count - 1].text += token.text
                } else {
                    untranslated.append((currentID, token.text))
                }
            } else {
                // The boundary itself is final, so the next word may start the new utterance even
                // before it is final.
                if atBoundary, pending.isEmpty, token.text.first?.isWhitespace == true { finishUtterance() }
                pending += token.text
            }
        }
        currentPending = pending
        let text = (currentFinal + currentPending).trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { onUtterance?(currentID, text, false) }
        for id in translated {
            let vietnamese = ((translations[id] ?? "") + (pendingTranslation[id] ?? ""))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !vietnamese.isEmpty { onTranslation?(id, vietnamese) }
        }
    }

    /// The current stretch's last utterance has all its sentences translated (or, for one closed at a
    /// comma, a translated clause).
    private var stretchTranslated: Bool {
        guard let last = translating.last, translatingIndex == translating.count - 1 else { return translating.isEmpty }
        if Self.sentenceCount(translatedInStretch) >= max(1, Self.sentenceCount(last.text)) { return true }
        let spoken = last.text.trimmingCharacters(in: .whitespacesAndNewlines).last
        let translated = translatedInStretch.trimmingCharacters(in: .whitespacesAndNewlines).last
        return spoken.map { ",;:".contains($0) } == true && translated.map { ",;:".contains($0) } == true
    }

    /// The final words since the last translation are what Soniox is translating now.
    private func startTranslatingStretch() {
        stretchEnded = false
        // Utterances of earlier stretches get no more translation (an utterance still being spoken
        // can continue into the new stretch, so it keeps its text).
        let keep = Set(untranslated.map(\.id))
        translations = translations.filter { keep.contains($0.key) }
        translating = untranslated
        untranslated = []
        translatingIndex = 0
        translatedInStretch = ""
    }

    /// Sentences in a text: runs of . ? ! … followed by a space or the end ("3.5" inside a sentence
    /// does not count).
    private static func sentenceCount(_ text: String) -> Int {
        var count = 0
        var previous: Character?
        for character in text + " " {
            if let previous, ".?!…".contains(previous), character.isWhitespace || character == "\"" { count += 1 }
            previous = character
        }
        return count
    }

    private func finishUtterance() {
        let text = currentFinal.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { onUtterance?(currentID, text, true) }
        currentID = UUID()
        currentFinal = ""
        currentPending = ""
        atBoundary = false
    }

    /// A finished sentence of at least a few words, or a long run-on clause at a comma.
    private static func endsUtterance(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        let words = text.split(whereSeparator: \.isWhitespace).count
        if ".?!".contains(last) { return words >= 4 }
        if ",;".contains(last) { return words >= 15 }
        return false
    }

    // MARK: - Wire format (https://docs.soniox.com/api-reference/stt/websocket-api)

    private struct Config: Encodable {
        struct Translation: Encodable { let type, targetLanguage: String }
        struct Context: Encodable {
            struct Item: Encodable { let key, value: String }
            let general: [Item]
            let text: String
            let terms: [String]
        }
        let model = "stt-rt-v6"
        let audioFormat = "mulaw" // see send(_:on:)
        let sampleRate = 16_000
        let numChannels = 1
        let languageHints = ["en", "fr"]
        // Off: tokens' language is never used, and identifying it costs Soniox processing time.
        let enableLanguageIdentification = false
        let enableEndpointDetection = true
        // The most eager endpointing Soniox allows: an utterance ends at most 500 ms after speech
        // stops (default 2000 ms), so its answer can start sooner. Sensitivity stays at Soniox's
        // low-latency suggestion; higher splits sentences at short pauses.
        let endpointLatencyAdjustmentLevel = 3
        let endpointSensitivity = 0.3
        let maxEndpointDelayMs = 500
        /// Live Vietnamese for whatever is spoken (English or French), on the same stream.
        let translation = Translation(type: "one_way", targetLanguage: "vi")
        let context = Context(
            general: CulinaryTerms.general.map { Context.Item(key: $0.key, value: $0.value) },
            text: CulinaryTerms.background,
            terms: CulinaryTerms.terms)
    }

    private struct Response: Decodable {
        struct Token: Decodable {
            let text: String
            let isFinal: Bool
            /// "translation" for Vietnamese tokens; "original" or "none" for spoken ones.
            let translationStatus: String?
        }
        let tokens: [Token]?
        let finalAudioProcMs: Int?
        let totalAudioProcMs: Int?
        let finished: Bool?
        let errorCode: Int?
        let errorMessage: String?
    }

    private static let configJSON: String = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return String(decoding: try! encoder.encode(Config()), as: UTF8.self)
    }()

    private static func decode(_ message: URLSessionWebSocketTask.Message) throws -> Response {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let bytes): data = bytes
        @unknown default: data = Data("{}".utf8)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    nonisolated private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, output.frameLength > 0 else { return nil }
        return output
    }
}
