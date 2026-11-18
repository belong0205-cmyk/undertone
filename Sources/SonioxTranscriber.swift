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
    #if DEBUG
    /// Test only: a spoken token became final (latency harness).
    var onDebugFinalToken: (() -> Void)?
    #endif

    private static let endpoint = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
    /// Audio is sent every 100 ms. (20 ms chunks showed words ~120 ms sooner, but Soniox then dropped
    /// words: "and briefly describe their" came back as "And. | Their" in 9 of 9 test readings.)
    nonisolated private static let chunkMs = 100
    nonisolated private static let chunkBytes = chunkMs * 32 // 16 kHz mono PCM16: 32 bytes per ms
    /// Silent chunks sent after speech before audio pauses (2 s; endpoints arrive within that).
    nonisolated private static let pauseAfterSilentChunks = 2_000 / chunkMs
    /// Audio sent ahead of the first sound when resuming after a pause (400 ms).
    nonisolated private static let preRollBytes = 400 * 32
    /// When Soniox falls this far behind the audio sent, start a fresh stream and replay to it the
    /// audio after the last final word (see `history`), so nothing said is lost.
    /// Only for a stream that really stopped: a busy Soniox swings 0.5-3 s behind and recovers on its
    /// own, while a reconnect replays seconds of audio and leaves the new stream 3.5-5 s behind for 20 s
    /// (measured; text then came in blocks after 2-3 sentences). Silent streams are caught by `stallSeconds`.
    private static let maxLagMs = 10_000
    /// Audio kept for a replay: the last 30 s sent on the stream, and at most 30 s captured while
    /// reconnecting.
    nonisolated private static let replayCapBytes = 30 * 32_000
    /// Soniox works through audio at about real time, so a lag (after a replay, or on a slow patch)
    /// only shrinks when it gets less audio than is spoken: while this far behind, every live silence
    /// is cut to 600 ms (still long enough for an endpoint) and the lag drops at each pause.
    private static let catchUpLagMs = 1_500
    nonisolated private static let catchUpSilentChunks = 600 / chunkMs
    /// While audio is being sent, no reply for this long means the stream stalled (measured: Soniox
    /// went silent for 18-20 s with our audio stuck unsent, then closed with 408); start a fresh one.
    /// Soniox replies several times a second while it gets audio, but a busy server went 3 s without one
    /// and the reconnect cost more than the wait; 5 s of nothing is a stall.
    private static let stallSeconds = 5.0

    private var apiKey = ""
    private var running = false
    private var generation = 0 // bumped by every start; streams of older starts are ignored
    private var currentID = UUID()
    private var currentFinal = "" // finalized tokens of the utterance in progress
    private var currentPending = "" // its non-final tokens; may still change
    private var discarding = false // skip the rest of a discarded utterance until its <end>
    /// The last final token closed a question (or a very long sentence); the utterance ends at the next word.
    private var atBoundary = false
    /// An utterance ends only when the speaker has really stopped. Soniox's endpoint (<end>) comes at
    /// every short pause, so a slow speaker's sentence was cut into up to 8 pieces ("List 3 types. |
    /// Of fish. | And 3 types of shellfish. | ..."). Now <end> ends it at once only after a question
    /// mark; otherwise, after an <end>, it ends once the audio has been quiet this long: shorter after
    /// a full stop, longer after a clause. Speech after the <end> continues the utterance.
    private static let silenceAfterSentenceMs = 1_200
    private static let silenceAfterClauseMs = 1_500
    /// An <end> came and no word since: the utterance waits for silence to end it.
    private var awaitingSilence = false
    /// Where the last spoken word ends in the stream's audio. When background music or noise keeps the
    /// audio level (`lastVoiceMs`) from ever going quiet, silence is measured from here instead, less
    /// `wordDelayMs`: how far behind the processed audio Soniox shows words (1-2 s, varies with load).
    private var lastSpokenEndMs = 0
    private var wordDelayMs = 1_000
    /// Words after a full stop start a new utterance when this much silence (by Soniox's word timing)
    /// came before them and the sentence has at least `pauseSplitWords` words: a slow speaker's
    /// fragments ("List 3 types. | Of fish.") stay together, consecutive sentences do not.
    private static let pauseSplitMs = 800
    private static let pauseSplitWords = 8
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
    private var lastKeepAliveAt = Date.distantPast
    private var lastMessageAt = Date()
    /// End of the last final word on the current stream (stream ms); the replay starts here.
    /// (final_audio_proc_ms ran seconds behind the words already shown, so replays repeated them.)
    private var lastFinalEndMs = 0
    /// Lowest lag seen on this stream. A replay starts a stream already behind by the replayed audio,
    /// which Soniox works through at about real time; only lag beyond this floor means a new stall.
    private var lagFloorMs = 0
    /// The first word of a new stream joins the utterance kept open across the reconnect.
    private var needsSpace = false

    // Shared with the audio thread, guarded by `lock`.
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var socket: URLSessionWebSocketTask?
    nonisolated(unsafe) private var converter: AVAudioConverter?
    nonisolated(unsafe) private var outgoing = Data()
    nonisolated(unsafe) private var lastSentAt = Date.distantPast
    nonisolated(unsafe) private var sentBytes = 0 // on the current stream
    /// End of the last chunk sent with audible sound (stream ms), for `awaitingSilence`.
    nonisolated(unsafe) private var lastVoiceMs = 0
    /// Ends of recent chunks sent without sound (stream ms, last 30 s): was a pause really quiet?
    nonisolated(unsafe) private var quietChunkEnds: [Int] = []
    nonisolated private let writtenLock = NSLock()
    nonisolated(unsafe) private var writtenBytes = 0 // of `sentBytes`, handed to the network (writtenLock)
    nonisolated(unsafe) private var silentChunks = 0 // consecutive digitally silent chunks
    nonisolated(unsafe) private var paused = false // not sending audio during a long silence
    nonisolated(unsafe) private var resumedAt = Date.distantPast // last resume after a silence pause
    nonisolated(unsafe) private var leadIn = Data() // last 400 ms of silence, sent first when sound returns
    /// PCM16 sent on the current stream, its first byte being byte `historyStart` of the stream.
    nonisolated(unsafe) private var history = Data()
    nonisolated(unsafe) private var historyStart = 0
    /// While reconnecting: audio captured meanwhile (`backlog`), sent after `replay` on the new stream.
    nonisolated(unsafe) private var reconnecting = false
    nonisolated(unsafe) private var backlog = Data()
    nonisolated(unsafe) private var replay = Data()
    nonisolated(unsafe) private var catchingUp = false // see catchUpLagMs
    #if DEBUG
    /// Test only: socket writes held back until this time, as in a network stall.
    nonisolated(unsafe) private var holdUntil: Date?
    nonisolated(unsafe) private var held: [Data] = []
    /// Test only: this many next streams fail before they open.
    nonisolated(unsafe) private var failingConnects = 0
    #endif
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
        // Checked every second, so a stall is caught within a second of `stallSeconds`.
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
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
            defer {
                self.socket = nil
                outgoing.removeAll()
                reconnecting = false
                backlog = Data()
                replay = Data()
                history = Data()
                catchingUp = false
            }
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
        guard socket != nil || reconnecting else { return }
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
        guard let socket else { // reconnecting: keep it for the new stream
            backlog.append(chunk)
            if backlog.count > Self.replayCapBytes { backlog.removeFirst(backlog.count - Self.replayCapBytes) }
            return
        }

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
                if silentChunks % (1_000 / Self.chunkMs) == 0 { send(Self.dithered(count: 100 * 32), on: socket) }
                leadIn.append(chunk)
                if leadIn.count > Self.preRollBytes { leadIn.removeFirst(leadIn.count - Self.preRollBytes) }
                return
            }
            if catchingUp, silentChunks > Self.catchUpSilentChunks { return }
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
        if Self.isVoiced(chunk) {
            lastVoiceMs = sentBytes / 32
        } else {
            quietChunkEnds.append(sentBytes / 32)
            if let first = quietChunkEnds.first, first < sentBytes / 32 - 30_000 { quietChunkEnds.removeFirst() }
        }
        history.append(chunk)
        if history.count > Self.replayCapBytes {
            let excess = history.count - Self.replayCapBytes
            history.removeFirst(excess)
            historyStart += excess
        }
        let count = chunk.count
        let frame = Self.muLaw(chunk)
        #if DEBUG
        if let until = holdUntil {
            if Date() < until { held.append(frame); return }
            holdUntil = nil
            for data in held { socket.send(.data(data)) { _ in } }
            held = []
        }
        #endif
        socket.send(.data(frame)) { [weak self] _ in // a broken socket surfaces in the receive loop
            guard let self, DebugLog.enabled else { return }
            self.writtenLock.withLock { self.writtenBytes += count } // not `lock`: send may call back at once
        }
    }

    /// `count` bytes of inaudible noise (+-24 LSB, about -63 dBFS): never digital zeros, which Soniox
    /// falls behind on. Smaller values would round to zero in mu-law.
    nonisolated private static func dithered(count: Int) -> Data {
        var out = Data(count: count)
        out.withUnsafeMutableBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in samples.indices { samples[i] = Bool.random() ? 24 : -24 }
        }
        return out
    }

    /// A replay with every silence cut to at most 300 ms: Soniox works through audio at about real
    /// time, so the shorter the replay, the sooner the stream is live again.
    nonisolated private static func shortenedSilences(_ audio: Data) -> Data {
        var out = Data()
        var silentRun = 0
        var offset = 0
        while offset < audio.count {
            let end = min(offset + chunkBytes, audio.count)
            let chunk = audio.subdata(in: offset..<end)
            silentRun = isSilent(chunk) ? silentRun + 1 : 0
            if silentRun * chunkMs <= 300 { out.append(chunk) }
            offset = end
        }
        return out
    }

    /// The replay played 1.25x faster at the same pitch: Soniox works through audio at only about
    /// 1.1x real time, so the stream catches up with live speech in seconds instead of a minute.
    /// Returns the audio unchanged if rendering fails.
    nonisolated private static func faster(_ pcm: Data, rate: Float = 1.25) -> Data {
        let frames = pcm.count / 2
        guard frames > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1),
              let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_600)
        else { return pcm }
        input.frameLength = AVAudioFrameCount(frames)
        pcm.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in 0..<frames { input.floatChannelData![0][i] = Float(samples[i]) / 32_768 }
        }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = rate
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1_600)
            try engine.start()
        } catch { return pcm }
        defer { engine.stop() }
        player.scheduleBuffer(input)
        player.play()
        let total = Int(Float(frames) / rate) + 1_600 // + 100 ms: the time-pitch unit's delay, so the last word is whole
        var out = Data(capacity: total * 2)
        while out.count / 2 < total {
            let count = AVAudioFrameCount(min(1_600, total - out.count / 2))
            guard (try? engine.renderOffline(count, to: output)) == .success else { return pcm }
            let channel = output.floatChannelData![0]
            for i in 0..<Int(output.frameLength) {
                var sample = Int16(max(-32_768, min(32_767, channel[i] * 32_768)))
                withUnsafeBytes(of: &sample) { out.append(contentsOf: $0) }
            }
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

    /// Sound above about -42 dBFS RMS: speech, not the quiet between words or a faint noise floor.
    nonisolated private static func isVoiced(_ chunk: Data) -> Bool {
        chunk.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            guard !samples.isEmpty else { return false }
            var sum = 0.0
            for sample in samples { sum += Double(sample) * Double(sample) }
            return (sum / Double(samples.count)).squareRoot() > 260
        }
    }

    /// Digital silence (what the tap delivers while nothing plays), allowing for rounding noise.
    nonisolated private static func isSilent(_ chunk: Data) -> Bool {
        chunk.withUnsafeBytes { bytes in
            stride(from: 0, to: bytes.count - 1, by: 2).allSatisfy { i in
                abs(Int32(Int16(bitPattern: UInt16(bytes[i]) | UInt16(bytes[i + 1]) << 8))) <= 2
            }
        }
    }

    #if DEBUG
    /// Test only: hold back every socket write for `seconds`, as in a network stall.
    nonisolated func simulateStall(seconds: Double) {
        lock.withLock { holdUntil = Date().addingTimeInterval(seconds) }
    }

    /// Test only: the next `count` streams fail before they open.
    nonisolated func simulateFailedConnects(_ count: Int) {
        lock.withLock { failingConnects = count }
    }
    #endif

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
        var opened = false // audio went to this stream, so the next replay comes from its history
        do {
            #if DEBUG
            let fail = lock.withLock { () -> Bool in
                defer { failingConnects = max(0, failingConnects - 1) }
                return failingConnects > 0
            }
            if fail { throw URLError(.networkConnectionLost) }
            #endif
            try await socket.send(.string(Self.configJSON))
            if running, generation == self.generation { // audio flows from here on
                opened = true
                // After a reconnect: first the audio the old stream never finalized, then what was
                // captured while connecting (sped up outside the lock, so the audio thread is not held),
                // then live audio.
                let pending = lock.withLock { () -> Data in
                    defer { replay = Data(); backlog = Data() }
                    return replay + backlog
                }
                let sped = Self.faster(Self.shortenedSilences(pending))
                let replayed = lock.withLock { () -> Int in
                    self.socket = socket
                    sentBytes = 0
                    lastVoiceMs = 0
                    quietChunkEnds = []
                    history = Data()
                    historyStart = 0
                    writtenLock.withLock { writtenBytes = 0 }
                    silentChunks = 0
                    paused = false
                    catchingUp = false
                    #if DEBUG
                    holdUntil = nil
                    held = []
                    #endif
                    let catchUp = sped + backlog // backlog: captured while speeding up
                    backlog = Data()
                    reconnecting = false
                    var offset = 0
                    while offset < catchUp.count {
                        let end = min(offset + Self.chunkBytes, catchUp.count)
                        send(catchUp.subdata(in: offset..<end), on: socket)
                        offset = end
                    }
                    return catchUp.count
                }
                lastFinalEndMs = 0
                lastSpokenEndMs = 0
                lagFloorMs = replayed / 32
                if replayed > 0 { DebugLog.log("soniox replayed \(replayed / 32) ms") }
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
                if let processed = response.totalAudioProcMs,
                   let newest = response.tokens?.filter({ $0.translationStatus != "translation" && !$0.text.hasPrefix("<") })
                       .compactMap(\.endMs).max(), newest > lastSpokenEndMs {
                    wordDelayMs = (4 * wordDelayMs + max(0, processed - newest)) / 5 // a new word: how late it came
                }
                apply(response.tokens ?? [])
                if let processed = response.totalAudioProcMs { finishIfSilent(processedMs: processed) }
                if response.finished == true { break loop }
                if let processed = response.totalAudioProcMs {
                    let lag = lock.withLock { () -> Int in
                        let lag = sentBytes / 32 - processed
                        catchingUp = lag > Self.catchUpLagMs
                        return lag
                    }
                    lagFloorMs = min(lagFloorMs, max(0, lag))
                    if lag - lagFloorMs > Self.maxLagMs {
                        fellBehind = true
                        break loop
                    }
                }
            }
        } catch {
            failure = error.localizedDescription
        }
        lock.withLock { if self.socket === socket { self.socket = nil } }
        socket.cancel(with: .normalClosure, reason: nil)
        DebugLog.log(String(format: "soniox closed after %.0f s: %@", Date().timeIntervalSince(connectedAt),
                            failure ?? (fellBehind ? "fell more than \(Self.maxLagMs / 1000) s behind" : "finished")))
        // A stream of an earlier start must not reconnect (a second stream) or touch the new text.
        guard generation == self.generation else { return }
        disconnected(failure: failure, fatal: fatal, immediately: fellBehind, opened: opened)
    }

    private func disconnected(failure: String?, fatal: Bool, immediately: Bool, opened: Bool) {
        // A closed stream sends no more translations; the utterance kept open keeps what it has, and
        // the next stream's translation of it is added after.
        let openTranslation = translations[currentID]
        resetTranslation()
        if running, let openTranslation { translations[currentID] = openTranslation }
        discarding = false
        guard running else { // stopped on purpose: keep the words not yet final as heard
            currentFinal += currentPending
            currentPending = ""
            finishUtterance()
            return
        }
        // The next stream gets the audio after the last final word again, so words not final yet
        // come back from it; the utterance stays open and continues with them.
        currentPending = ""
        needsSpace = !currentFinal.isEmpty
        let finalBytes = lastFinalEndMs * 32
        lock.withLock {
            // A stream that failed before opening got no audio: `replay` and `backlog` still hold
            // everything after the last final word, so they wait for the next stream as they are.
            if opened {
                let offset = max(0, finalBytes - historyStart)
                // dropFirst counts from startIndex, which removeFirst (the 30 s cap) moves off zero, so
                // subdata(in:) with plain offsets would read older audio and repeat words already shown.
                replay = Data(history.dropFirst(offset))
                DebugLog.log("soniox replay from \(finalBytes / 32) ms; stream audio \(historyStart / 32)-\((historyStart + history.count) / 32) ms")
            } else {
                DebugLog.log("soniox stream failed before opening; keeping \(replay.count / 32) ms replay and \(backlog.count / 32) ms backlog")
            }
            history = Data()
            reconnecting = true
        }
        if let failure {
            quickFailures = Date().timeIntervalSince(connectedAt) < 5 ? quickFailures + 1 : 0
            if fatal || quickFailures >= 3 {
                stop()
                finishUtterance()
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
        guard let socket, Date().timeIntervalSince(lastKeepAliveAt) > 8 else { return }
        lastKeepAliveAt = Date()
        DebugLog.log("soniox keepalive")
        socket.send(.string(#"{"type":"keepalive"}"#)) { _ in }
    }

    // MARK: - Utterances

    private func apply(_ tokens: [Response.Token]) {
        guard !tokens.isEmpty else { return }
        var pending = ""
        var pendingTranslation: [UUID: String] = [:]
        var translated: [UUID] = [] // in order, to report
        var spaced = false
        for var token in tokens {
            // A sentence (full stop) followed by a pause under background music or noise, which keeps the
            // audio level from going quiet: the gap between the words decides (see `pauseSplitMs`). In
            // quiet audio the silence timer decides, as Soniox puts full stops after a slow speaker's fragments.
            let afterPause = token.startMs.map { start in
                start - lastFinalEndMs >= Self.pauseSplitMs && Self.endsSentence(currentFinal)
                    && !hadQuietAudio(from: lastFinalEndMs, to: start)
            } == true
            if token.translationStatus != "translation", !token.text.hasPrefix("<") {
                awaitingSilence = false // more speech: the utterance goes on
                if let end = token.endMs { lastSpokenEndMs = max(lastSpokenEndMs, end) }
            }
            if token.isFinal, token.translationStatus != "translation", let end = token.endMs {
                lastFinalEndMs = max(lastFinalEndMs, end)
                #if DEBUG
                if !token.text.hasPrefix("<") { onDebugFinalToken?() }
                #endif
            }
            // A new stream's first word has no leading space; it continues the utterance kept open.
            if needsSpace, !spaced, token.translationStatus != "translation", !token.text.hasPrefix("<") {
                spaced = true
                if token.text.first?.isWhitespace != true { token = Response.Token(text: " " + token.text, isFinal: token.isFinal, translationStatus: token.translationStatus, startMs: token.startMs, endMs: token.endMs) }
                if token.isFinal { needsSpace = false }
            }
            if token.text == "<end>" || token.text == "<fin>" { // endpoint, or our finalize at a pause
                DebugLog.log("soniox \(token.text)")
                if discarding {
                    discarding = false
                } else if token.text == "<fin>" || currentFinal.trimmingCharacters(in: .whitespaces).hasSuffix("?") {
                    finishUtterance() // our finalize at a long pause, or a finished question
                } else {
                    awaitingSilence = true
                }
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
                if atBoundary || afterPause, token.text.first?.isWhitespace == true { finishUtterance() }
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
                if atBoundary || afterPause, pending.isEmpty, token.text.first?.isWhitespace == true { finishUtterance() }
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

    /// Ends the utterance once the speaker has been silent long enough (see `silenceAfterSentenceMs`).
    private func finishIfSilent(processedMs: Int) {
        let text = currentFinal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard awaitingSilence, !text.isEmpty, currentPending.isEmpty, let last = text.last else { return }
        let needed = ".!?".contains(last) ? Self.silenceAfterSentenceMs : Self.silenceAfterClauseMs
        let (voiceMs, noisy) = lock.withLock { () -> (Int, Bool) in
            // No quiet audio for 5 s, pauses included: music or noise underneath, so the level can't tell.
            (lastVoiceMs, (quietChunkEnds.last ?? 0) < sentBytes / 32 - 5_000)
        }
        let quiet = processedMs - voiceMs
        // The first word after a pause shows up later than `wordDelayMs` (Soniox needs ~1 s of it), hence the margin.
        let wordless = processedMs - lastSpokenEndMs - wordDelayMs - 800
        if quiet >= needed || (noisy && wordless >= needed) {
            DebugLog.log("soniox utterance ends: quiet \(quiet) ms, no words \(processedMs - lastSpokenEndMs) ms, word delay \(wordDelayMs) ms")
            finishUtterance()
        }
    }

    private func hadQuietAudio(from: Int, to: Int) -> Bool {
        lock.withLock { quietChunkEnds.contains { $0 > from && $0 <= to + 100 } }
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last, ".!?".contains(last) else { return false }
        return text.split(whereSeparator: \.isWhitespace).count >= pauseSplitWords
    }

    private func finishUtterance() {
        let text = currentFinal.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { onUtterance?(currentID, text, true) }
        currentID = UUID()
        currentFinal = ""
        currentPending = ""
        atBoundary = false
        awaitingSilence = false
    }

    /// Someone talking on without a pause: a question of a few words, or a very long sentence, closes
    /// at its end so it can be answered and translated. A full stop alone does not: Soniox puts one
    /// after fragments of a slowly spoken sentence. Commas never close an utterance.
    private static func endsUtterance(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        let words = text.split(whereSeparator: \.isWhitespace).count
        if last == "?" { return words >= 4 }
        if ".!".contains(last) { return words >= 30 }
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
            /// Where a spoken token ends in the stream's audio; translations have none.
            let startMs: Int?
            let endMs: Int?
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
