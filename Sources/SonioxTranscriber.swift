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
    var onFailure: ((String) -> Void)?

    private static let endpoint = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
    nonisolated private static let chunkBytes = 3_200 // 100 ms of 16 kHz mono PCM16

    private var apiKey = ""
    private var running = false
    private var currentID = UUID()
    private var currentFinal = "" // finalized tokens of the utterance in progress
    private var currentPending = "" // its non-final tokens; may still change
    private var discarding = false // skip the rest of a discarded utterance until its <end>
    private var connectedAt = Date()
    private var quickFailures = 0
    private var keepAliveTimer: Timer?

    // Shared with the audio thread, guarded by `lock`.
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var socket: URLSessionWebSocketTask?
    nonisolated(unsafe) private var converter: AVAudioConverter?
    nonisolated(unsafe) private var outgoing = Data()
    nonisolated(unsafe) private var lastSentAt = Date.distantPast
    nonisolated private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!

    func start(apiKey: String) throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw StartError.missingAPIKey }
        self.apiKey = key
        running = true
        quickFailures = 0
        connect()
        // Soniox closes a stream that receives neither audio nor keepalive for 20 seconds.
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sendKeepAliveIfIdle() }
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

    /// Drops the utterance in progress (used when the conversation is cleared).
    func discardCurrent() {
        discarding = !(currentFinal.isEmpty && currentPending.isEmpty)
        currentID = UUID()
        currentFinal = ""
        currentPending = ""
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
        lastSentAt = Date()
        socket.send(.data(chunk)) { _ in } // a broken socket surfaces in the receive loop
    }

    // MARK: - Connection

    private func connect() {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        connectedAt = Date()
        socket.resume()
        Task { await run(socket) }
    }

    private func run(_ socket: URLSessionWebSocketTask) async {
        var failure: String?
        var fatal = false
        do {
            try await socket.send(.string(Self.configJSON))
            if running { lock.withLock { self.socket = socket } } // audio flows from here on
            loop: while true {
                let response = try Self.decode(try await socket.receive())
                if let code = response.errorCode {
                    failure = "Soniox lỗi \(code): \(response.errorMessage ?? "không rõ")"
                    fatal = [400, 401, 402, 403].contains(code) // retrying won't fix these
                    break loop
                }
                apply(response.tokens ?? [])
                if response.finished == true { break loop }
            }
        } catch {
            failure = error.localizedDescription
        }
        lock.withLock { if self.socket === socket { self.socket = nil } }
        socket.cancel(with: .normalClosure, reason: nil)
        disconnected(failure: failure, fatal: fatal)
    }

    private func disconnected(failure: String?, fatal: Bool) {
        currentFinal += currentPending // never finalized on this connection: keep it as heard
        currentPending = ""
        discarding = false
        finishUtterance()
        guard running else { return } // stopped on purpose
        if let failure {
            quickFailures = Date().timeIntervalSince(connectedAt) < 5 ? quickFailures + 1 : 0
            if fatal || quickFailures >= 3 {
                stop()
                onFailure?(failure)
                return
            }
        }
        // Stream ended (300-minute limit) or a transient error: reconnect after a short pause.
        Task {
            try? await Task.sleep(for: .seconds(1))
            if running { connect() }
        }
    }

    private func sendKeepAliveIfIdle() {
        let socket = lock.withLock { Date().timeIntervalSince(lastSentAt) > 8 ? self.socket : nil }
        socket?.send(.string(#"{"type":"keepalive"}"#)) { _ in }
    }

    // MARK: - Utterances

    private func apply(_ tokens: [Response.Token]) {
        guard !tokens.isEmpty else { return }
        var pending = ""
        for token in tokens {
            if token.text == "<end>" { // endpoint: the speaker finished an utterance
                if discarding { discarding = false } else { finishUtterance() }
                pending = ""
            } else if token.text == "<fin>" || discarding {
                continue
            } else if token.isFinal {
                currentFinal += token.text
            } else {
                pending += token.text
            }
        }
        currentPending = pending
        let text = (currentFinal + currentPending).trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { onUtterance?(currentID, text, false) }
    }

    private func finishUtterance() {
        let text = currentFinal.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { onUtterance?(currentID, text, true) }
        currentID = UUID()
        currentFinal = ""
        currentPending = ""
    }

    // MARK: - Wire format (https://docs.soniox.com/api-reference/stt/websocket-api)

    private struct Config: Encodable {
        struct Context: Encodable {
            struct Item: Encodable { let key, value: String }
            let general: [Item]
            let text: String
            let terms: [String]
        }
        let model = "stt-rt-v6"
        let audioFormat = "pcm_s16le"
        let sampleRate = 16_000
        let numChannels = 1
        let languageHints = ["en", "fr"]
        let enableLanguageIdentification = true
        let enableEndpointDetection = true
        let context = Context(
            general: CulinaryTerms.general.map { Context.Item(key: $0.key, value: $0.value) },
            text: CulinaryTerms.background,
            terms: CulinaryTerms.terms)
    }

    private struct Response: Decodable {
        struct Token: Decodable {
            let text: String
            let isFinal: Bool
        }
        let tokens: [Token]?
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
