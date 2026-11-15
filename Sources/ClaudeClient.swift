import Foundation

enum ClaudeError: LocalizedError {
    case http(status: Int, message: String)
    case refusal
    case stream(String)

    var errorDescription: String? {
        switch self {
        case let .http(status, message):
            switch status {
            case 401: "API key không hợp lệ. Kiểm tra lại trong Cài đặt."
            case 403: "API key này không được phép dùng model \(ClaudeClient.model)."
            case 429: "Đang vượt giới hạn tần suất của API. Thử lại sau vài giây."
            case 500...599: "Máy chủ AI đang bận (\(status)). Thử lại sau giây lát."
            default: "Lỗi API (\(status)): \(message)"
            }
        case .refusal: "AI từ chối trả lời đoạn hội thoại này."
        case let .stream(message): "Lỗi khi nhận câu trả lời: \(message)"
        }
    }
}

/// Streaming client for the Claude Messages API over raw HTTP (there is no official Swift SDK).
struct ClaudeClient {
    static let model = "claude-opus-5-5"
    let apiKey: String

    /// Yields answer text as it streams in. `profile` is the active user profile block, if any.
    func stream(system: String, profile: String?, user: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(
                        system: system, profile: profile, user: user, maxTokens: 16000, stream: true)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
                        throw ClaudeError.http(status: status, message: Self.errorMessage(in: json))
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = Data(line.dropFirst(5).trimmingCharacters(in: .whitespaces).utf8)
                        guard let event = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { continue }
                        let delta = event["delta"] as? [String: Any]
                        switch event["type"] as? String {
                        case "content_block_delta":
                            // Only text deltas; thinking and fallback blocks are skipped.
                            if delta?["type"] as? String == "text_delta", let text = delta?["text"] as? String {
                                continuation.yield(text)
                            }
                        case "message_delta":
                            if delta?["stop_reason"] as? String == "refusal" { throw ClaudeError.refusal }
                        case "error":
                            throw ClaudeError.stream(Self.errorMessage(in: event))
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Writes (or refreshes) the cached knowledge-base and profile prefix without generating output,
    /// so the next real request skips re-processing it. Model and settings must match `stream`.
    func warmCache(system: String, profile: String?) async throws {
        let request = try makeRequest(system: system, profile: profile, user: "Warm-up.", maxTokens: 0, stream: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw ClaudeError.http(status: status, message: Self.errorMessage(in: json))
        }
    }

    /// Keeps the knowledge base and profile in the prompt cache (entries expire after 5 idle minutes)
    /// until cancelled. Best effort: if a warm-up fails, the next real request simply writes the cache.
    func keepCacheWarm(system: String, profile: String?) -> Task<Void, Never> {
        Task {
            guard !KnowledgeBase.promptBlock.isEmpty || profile != nil else { return }
            while !Task.isCancelled {
                try? await warmCache(system: system, profile: profile)
                try? await Task.sleep(for: .seconds(240))
            }
        }
    }

    private func makeRequest(
        system: String, profile: String?, user: String, maxTokens: Int, stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // If a safety classifier declines, the API retries on a fallback model inside the same stream.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body = Self.requestBody(system: system, profile: profile, user: user, maxTokens: maxTokens, stream: stream)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// The JSON body of a Messages request (internal so a debug harness can inspect it).
    static func requestBody(
        system: String, profile: String?, user: String, maxTokens: Int, stream: Bool
    ) -> [String: Any] {
        [
            "model": model,
            "max_tokens": maxTokens,
            "stream": stream,
            "system": systemBlocks(system, profile: profile),
            "messages": [["role": "user", "content": user]],
            // The answer is needed within seconds, so keep thinking shallow.
            "output_config": ["effort": "low"],
            "fallbacks": "default",
        ]
    }

    /// Order: the large knowledge base, then the user's profile (each with its own cache
    /// breakpoint, so long menus and recipes are read from the cache), then the instructions.
    /// No profile means no profile block.
    private static func systemBlocks(_ system: String, profile: String?) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        if !KnowledgeBase.promptBlock.isEmpty {
            blocks.append([
                "type": "text",
                "text": KnowledgeBase.promptBlock,
                "cache_control": ["type": "ephemeral"],
            ])
        }
        if let profile, !profile.isEmpty {
            blocks.append(["type": "text", "text": profile, "cache_control": ["type": "ephemeral"]])
        }
        blocks.append(["type": "text", "text": system])
        return blocks
    }

    private static func errorMessage(in json: [String: Any]?) -> String {
        (json?["error"] as? [String: Any])?["message"] as? String ?? "không rõ"
    }
}

enum Prompt {
    static let system = """
    You help a Vietnamese speaker follow and take part in a live English conversation (an interview, meeting or call). \
    You get the recent conversation and the newest utterance, transcribed from the audio playing on their computer \
    (mostly the other participants). Transcripts can contain recognition errors; infer the intended words.

    Reply in exactly this format and nothing else:
    <vi>A natural Vietnamese translation of the newest utterance only.</vi>

    Only when the newest utterance asks the user something or expects them to respond, continue with:
    <answer_en>What the user can say aloud: 1 or 2 short sentences, at most 25 words in total. The user's English \
    is CEFR B1, so use only common B1-level (or easier) words and simple grammar; no idioms, no rare or formal words. \
    Keep a technical cooking term only when the answer needs it (e.g. "brunoise"). No bullet points, no headings.</answer_en>
    <answer_vi>The same answer in Vietnamese.</answer_vi>

    A <user_profile> block, when present, holds facts the user entered about themselves. When the newest \
    utterance asks about the user (their name, age, where they live, their work or experience, their dishes, \
    recipes or menu), write the answer from that profile in the first person, still following the answer_en \
    rules. If there is no profile, or it does not contain what was asked, answer as you otherwise would, and \
    never invent personal facts such as a name, age, address, workplace or dish.
    """

    static func user(history: String, utterance: String) -> String {
        var message = ""
        if !history.isEmpty {
            message += "<recent_conversation>\n\(history)\n</recent_conversation>\n\n"
        }
        message += "<newest_utterance>\n\(utterance)\n</newest_utterance>"
        return message
    }

    /// Text inside `<tag>…</tag>`. While streaming, returns what has arrived so far after `<tag>`,
    /// minus a half-written closing tag.
    static func section(_ tag: String, in output: String) -> String {
        guard let open = output.range(of: "<\(tag)>") else { return "" }
        let rest = output[open.upperBound...]
        var text = rest.range(of: "</\(tag)>").map { String(rest[..<$0.lowerBound]) } ?? String(rest)
        if let lt = text.lastIndex(of: "<"), !text[lt...].contains(">") {
            text = String(text[..<lt])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
