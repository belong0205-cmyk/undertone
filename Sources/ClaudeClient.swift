import Foundation

enum ClaudeError: LocalizedError {
    case http(status: Int, message: String)
    case refusal
    case stream(String)

    var errorDescription: String? {
        switch self {
        case let .http(status, message) where status == 402 || message.lowercased().contains("credit balance"):
            "Hết credit Claude API — nạp thêm trong Console (console.anthropic.com)."
        case let .http(status, message):
            switch status {
            case 401: "API key không hợp lệ. Kiểm tra lại trong Cài đặt."
            case 403: "API key này không được phép dùng model Claude này."
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
    /// The per-utterance answer, and its cache warmer (caches are per model, so both must match):
    /// many calls, so the fast low-cost Haiku. Haiku 5.5 has no server-side fallback.
    static let liveModel = "claude-haiku-5-5"
    /// Rare one-off jobs such as the Word profile import.
    static let model = "claude-opus-5-5"
    let apiKey: String

    /// Yields answer text as it streams in. `profile` is the active user profile block, if any.
    func stream(system: String, profile: String?, user: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(
                        system: system, profile: profile, user: user, maxTokens: 1024, stream: true)
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

    /// Opens (or keeps open) the HTTPS connection to the API with a free request, so the answer
    /// request that follows skips the TCP and TLS handshakes. URLSession.shared reuses the connection.
    func preconnect() {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1")!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        URLSession.shared.dataTask(with: request).resume()
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

    /// One non-streaming request whose reply is JSON matching `schema` (structured outputs).
    /// Returns the reply text, a JSON document. Used for one-off jobs such as the Word profile import,
    /// so it carries no knowledge base or profile.
    func json(system: String, user: String, schema: [String: Any]) async throws -> String {
        var request = try makeRequest(body: Self.jsonRequestBody(system: system, user: user, schema: schema))
        request.timeoutInterval = 180
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard status == 200, let json else {
            throw ClaudeError.http(status: status, message: Self.errorMessage(in: json))
        }
        switch json["stop_reason"] as? String {
        case "refusal": throw ClaudeError.refusal
        case "max_tokens": throw ClaudeError.stream("câu trả lời bị cắt vì quá dài")
        default: break
        }
        let blocks = json["content"] as? [[String: Any]] ?? []
        return blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
    }

    private func makeRequest(
        system: String, profile: String?, user: String, maxTokens: Int, stream: Bool
    ) throws -> URLRequest {
        try makeRequest(
            body: Self.requestBody(system: system, profile: profile, user: user, maxTokens: maxTokens, stream: stream))
    }

    /// Internal so an offline check can inspect the headers.
    func makeRequest(body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // If a safety classifier declines, the API retries on a fallback model (requests with `fallbacks`).
        if body["fallbacks"] != nil {
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Body for `json`: Opus with server-side fallback (internal so an offline check can inspect it).
    static func jsonRequestBody(system: String, user: String, schema: [String: Any]) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 16000,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": ["effort": "medium", "format": ["type": "json_schema", "schema": schema]],
            "fallbacks": "default",
        ]
    }

    /// The JSON body of a Messages request (internal so a debug harness can inspect it).
    static func requestBody(
        system: String, profile: String?, user: String, maxTokens: Int, stream: Bool
    ) -> [String: Any] {
        [
            "model": liveModel,
            "max_tokens": maxTokens,
            "stream": stream,
            "system": systemBlocks(system, profile: profile),
            "messages": [["role": "user", "content": user]],
            // The answer must start within a second, so no thinking (Haiku 5.5 accepts `disabled`
            // at effort high or below). No `fallbacks`: Haiku 5.5 has none, refusals surface as `.refusal`.
            "thinking": ["type": "disabled"],
            "output_config": ["effort": "low"],
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
    You help a Vietnamese speaker take part in a live English conversation (an interview, meeting or call, \
    often in a professional kitchen). You get the recent conversation, each line marked with how many seconds ago \
    it ended, and the newest utterance, transcribed from the audio playing on their computer (mostly the other \
    participants). Transcripts can contain recognition errors; infer the intended words. The user already sees a \
    Vietnamese translation, so never translate.

    Speakers pause and hesitate, so one question can arrive in several pieces. The newest utterance may already \
    join such pieces; if the last lines of the recent conversation ended only a few seconds before it and are \
    unfinished parts of the same question, read them together with it and answer the whole question, not only its \
    last piece.

    When the newest utterance asks the user something or expects them to respond, reply in exactly this format \
    and nothing else. That includes instructions and exam or teacher prompts with no question mark ("Define \
    ganache.", "Explain…", "Describe…", "List…", "Provide…", "Name…", "Tell me…", "Give me…", "Walk me \
    through…", "What are the steps…"): they ask the user to answer.
    <answer_en>The exact words the user says aloud, as the user, in the first person ("I", "my", and "we" for their \
    team or restaurant): 1 or 2 short sentences, at most 25 words in total. A technical question that asks for \
    facts (a definition, ratios, temperatures, times, quantities or steps) may take up to 3 short sentences, at \
    most 45 words: answer every part it asks for, with the concrete numbers (e.g. "Ganache is chocolate melted \
    with hot cream. I use 1 to 1 for dark chocolate, and 2 to 1 or 3 to 1 for milk and white chocolate."). Never advice about what to say (no "You \
    could say…", no "Tell them…"), never about the user in the third person, no quotation marks. The user's English \
    is CEFR B1, so use only common B1-level (or easier) words and simple grammar; no idioms, no rare or formal words. \
    Keep a technical cooking term only when the answer needs it (e.g. "brunoise"). No bullet points, no headings.</answer_en>
    <answer_vi>The same answer in Vietnamese, also in the first person ("tôi").</answer_vi>

    Otherwise reply with exactly: -

    Answer a general question in general terms: what usually or always happens. When the knowledge base or \
    profile lists details by day, date or shift (a menu, a prep list, a schedule), do not pick one of them on \
    your own; give the details for a particular day only when the question names that day (e.g. "today", \
    "on Friday", "this weekend").

    A <user_profile> block, when present, holds facts the user entered about themselves. When the newest \
    utterance asks about the user (their name, age or birthday, where they live, their work, workplace, shifts \
    and hours, kitchen team, daily routine, responsibilities or experience, their dishes, recipes or menu), write \
    the answer from that profile (work out an age from the date of birth and <today>), still following the \
    answer_en rules. If there is no profile, or it does not contain what was asked, still give the answer the user \
    can say, with a placeholder in square brackets for each missing personal fact (e.g. "My name is [your name]. I \
    work at [your workplace]."), and the same placeholders in answer_vi. Never invent personal facts such as a name, \
    age, address, workplace or dish, and never ask the user for them.
    """

    /// Acknowledgements and fillers ("Okay.", "Yes, chef.", "Uh-huh.", "D'accord.") need no answer,
    /// so they are shown without calling Claude.
    static func isFiller(_ utterance: String) -> Bool {
        // A question ("You?", "Right?", "Chef?") expects an answer, so it is never a filler.
        if utterance.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") { return false }
        let words = utterance.lowercased().split { !$0.isLetter }
        return !words.isEmpty && words.count <= 4 && words.allSatisfy { fillerWords.contains(String($0)) }
    }

    private static let fillerWords: Set<String> = [
        "yeah", "yes", "yep", "yup", "ok", "okay", "right", "alright", "all", "sure", "chef",
        "uh", "huh", "um", "mm", "mmm", "mhm", "hmm", "oh", "ah", "thanks", "thank", "you",
        "oui", "ouais", "d", "accord", "merci", "bon", "voilà", "voila",
    ]

    /// One utterance as heard: its text, when its first words appeared and when it was final.
    struct Heard {
        let text: String
        let start: Date
        let end: Date
    }

    /// Pieces closer than this (final of one to first words of the next) can be one question cut by a
    /// pause. Measured with real Soniox: a 2.2 s hesitation shows as 3.4 s here (the next words appear
    /// about 1 s after they are spoken); separate questions 4.5 s apart showed as 5.6 s.
    static let pieceGap: TimeInterval = 4
    static let maxPieces = 4

    /// Index of the first piece of the question that ends with the last utterance in `heard`. An earlier
    /// utterance joins it when it ended less than `pieceGap` before the next one began and either was left
    /// unfinished (Soniox ends a piece cut by a pause with "—", a comma or no punctuation) or the next one
    /// carries it on: it starts with a preposition ("Do you usually cook?" + "At your restaurant?") or a
    /// joining word ("Define ganache." + "And provide common ratios…"). Up to `maxPieces` pieces;
    /// fillers ("Okay.", "Um.") are never pieces.
    static func questionStart(_ heard: [Heard]) -> Int {
        var first = heard.count - 1
        while first > 0, heard.count - first < maxPieces {
            let previous = heard[first - 1].text.trimmingCharacters(in: .whitespacesAndNewlines)
            let next = heard[first].text.lowercased().split { !$0.isLetter }.first.map(String.init) ?? ""
            let unfinished = previous.last.map { !".?!".contains($0) } ?? false
            guard heard[first].start.timeIntervalSince(heard[first - 1].end) < pieceGap,
                  unfinished || continuationWords.contains(next), !isFiller(previous)
            else { break }
            first -= 1
        }
        return first
    }

    /// First words that carry on the previous piece rather than start a new question.
    private static let continuationWords: Set<String> = [
        "at", "to", "in", "on", "for", "with", "from", "about", "of", "by", "into", "during", "than", "like",
        "and", "or", "also", "plus", "then", "including", "especially",
    ]

    /// `history`: earlier utterances, oldest first; each line says how long ago it ended, so the model
    /// can tell pieces of one question from separate turns.
    static func user(history: [Heard], utterance: String, now: Date = Date()) -> String {
        var message = "<today>\(now.formatted(.iso8601.year().month().day()))</today>\n\n"
        if !history.isEmpty {
            let lines = history.map { "[\(max(0, Int(now.timeIntervalSince($0.end).rounded()))) s ago] \($0.text)" }
            message += "<recent_conversation>\n\(lines.joined(separator: "\n"))\n</recent_conversation>\n\n"
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
