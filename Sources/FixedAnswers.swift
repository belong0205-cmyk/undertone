import Foundation

/// Answers the user settled word for word (`Knowledge/fixed-answers.md`): a question that matches one
/// is answered with it at once, without calling Claude. The file is left out of the knowledge base.
enum FixedAnswers {
    static let fileName = "fixed-answers.md"

    struct Entry: Equatable {
        /// The question and its other wordings, as written in the file.
        var questions: [String] = []
        var answer = ""
        var vietnamese = ""
    }

    /// Words with a meaning of their own the utterance may have around the question ("Okay, next
    /// question: …", "…in a kitchen").
    static let extraWords = 4

    static let entries: [Entry] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Knowledge/\(fileName)"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return parse(text)
    }()

    /// Reads `## Q:` sections: `- ` lines are other wordings, `A:` the answer, `VI:` its translation
    /// (either may go on over several lines).
    static func parse(_ text: String) -> [Entry] {
        enum Field { case answer, vietnamese }
        var entries: [Entry] = []
        var entry: Entry?
        var field: Field?
        func close() {
            if var done = entry {
                done.answer = done.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                done.vietnamese = done.vietnamese.trimmingCharacters(in: .whitespacesAndNewlines)
                if !done.answer.isEmpty { entries.append(done) }
            }
            entry = nil
            field = nil
        }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                close()
                if line.hasPrefix("## Q:") {
                    entry = Entry(questions: [String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)])
                }
            } else if entry == nil || line.isEmpty {
                continue // the file's own notes, or a blank line
            } else if line.hasPrefix("A:") {
                field = .answer
                entry?.answer = String(line.dropFirst(2))
            } else if line.hasPrefix("VI:") {
                field = .vietnamese
                entry?.vietnamese = String(line.dropFirst(3))
            } else if field == .answer {
                entry?.answer += " " + line
            } else if field == .vietnamese {
                entry?.vietnamese += " " + line
            } else if line.hasPrefix("- ") {
                entry?.questions.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            }
        }
        close()
        return entries
    }

    /// The entry whose question (or another wording of it) the utterance asks, or nil. Strict, because a
    /// wrong fixed answer is worse than a normal one:
    /// - every content word of that wording must be heard (any form: "clean", "cleaning"); only small
    ///   words ("the", "a", "what's") may differ, so "…cleaning and disinfecting?" does not match;
    /// - between them, only the wording's own words or small words;
    /// - at most `extraWords` other words around them, none asking something more after it ("…and why…?");
    /// - any other sentence in the utterance asks nothing ("Okay, next question." is fine, "And why is it
    ///   important?" is not): then Claude answers the whole of it.
    static func match(_ utterance: String, in entries: [Entry] = entries) -> Entry? {
        let sentences = utterance.split { ".?!".contains($0) }.map(String.init)
            .filter { !words($0).isEmpty }
        let asksMore = utterance.split(separator: "?").count > 1 // a second question mark
        for (index, sentence) in sentences.enumerated() {
            let others = sentences.enumerated().filter { $0.offset != index }.map(\.element)
            guard !asksMore, others.allSatisfy({ words($0).allSatisfy { !askingWords.contains($0) } }) else { continue }
            for entry in entries where entry.questions.contains(where: { asks(sentence, $0) }) {
                return entry
            }
        }
        return nil
    }

    /// The sentence asks `question`, by the rules of `match`.
    private static func asks(_ sentence: String, _ question: String) -> Bool {
        let heard = words(sentence)
        let asked = words(question).map(stem)
        let required = Set(words(question).filter { !smallWords.contains($0) }.map(stem))
        let stems = heard.map(stem)
        guard !required.isEmpty, required.isSubset(of: Set(stems)),
              let first = stems.firstIndex(where: required.contains),
              let last = stems.lastIndex(where: required.contains)
        else { return false }
        let inside = heard[first...last].allSatisfy { asked.contains(stem($0)) || smallWords.contains($0) }
        let before = heard[..<first], after = heard[(last + 1)...]
        let extra = (before + after).filter { !asked.contains(stem($0)) && !smallWords.contains($0) }
        return inside && extra.count <= extraWords
            && before.allSatisfy { !["why", "how", "when", "where", "which", "who"].contains($0) }
            && after.allSatisfy { !askingWords.contains($0) }
    }

    /// Words that may differ or be misheard: they carry no meaning of their own here.
    private static let smallWords: Set<String> = [
        "the", "a", "an", "what", "is", "are", "was", "be", "between", "and", "or", "of", "to", "in", "on", "at",
        "for", "with", "me", "you", "your", "we", "us", "i", "can", "could", "would", "please", "okay", "ok", "so",
        "now", "then", "just", "tell", "explain", "it", "this", "that", "do", "does",
    ]

    /// Words that ask something: after the question, or in another sentence, they mean a further question.
    private static let askingWords: Set<String> = [
        "why", "how", "what", "when", "where", "which", "who", "whose", "explain", "describe", "list", "name",
        "give", "provide", "tell", "compare", "also", "example", "should",
    ]

    /// One form per word: "cleaning", "cleans", "clean" → "clean"; "sanitiser", "sanitise" → "sanitis".
    private static func stem(_ word: String) -> String {
        guard word.count > 4 else { return word }
        for suffix in ["ings", "ing", "ers", "er", "es", "ed", "s", "e"] where word.hasSuffix(suffix) {
            return String(word.dropLast(suffix.count))
        }
        return word
    }

    /// Lowercased words without punctuation, in one spelling: "What's" → "what is", "sanitizing" →
    /// "sanitising", "vs" → "versus" (Soniox writes either).
    static func words(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" }
            .flatMap { raw -> [String] in
                var word = raw.replacingOccurrences(of: "’", with: "'")
                if word.hasSuffix("'s"), ["what's", "that's", "it's", "there's", "how's", "who's"].contains(word) {
                    return [String(word.dropLast(2)), "is"]
                }
                word = word.replacingOccurrences(of: "'", with: "")
                if word == "vs" { return ["versus"] }
                for (american, british) in [("ization", "isation"), ("izing", "ising"), ("ized", "ised"),
                                            ("izer", "iser"), ("izes", "ises"), ("ize", "ise")]
                where word.hasSuffix(american) {
                    word = String(word.dropLast(american.count)) + british
                    break
                }
                return [word]
            }
    }
}
