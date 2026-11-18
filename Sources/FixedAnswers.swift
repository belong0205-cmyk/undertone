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

    /// Similarity needed to match: 1 is word for word; 0.8 allows about one misheard word in five.
    static let threshold = 0.8
    /// Words the utterance may have around the question ("Okay, next question: …").
    static let extraWords = 5

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

    /// The entry whose question (or another wording of it) the utterance asks, allowing a few misheard
    /// words and a few words around it, or nil.
    static func match(_ utterance: String, in entries: [Entry] = entries) -> Entry? {
        let heard = words(utterance)
        guard !heard.isEmpty else { return nil }
        var best: (entry: Entry, score: Double)?
        for entry in entries {
            for question in entry.questions {
                let asked = words(question)
                guard !asked.isEmpty, heard.count <= asked.count + extraWords else { continue }
                let score = 1 - Double(distance(asked, within: heard)) / Double(asked.count)
                if score >= threshold, score > best?.score ?? 0 { best = (entry, score) }
            }
        }
        return best?.entry
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

    /// Fewest word edits that turn `question` into some run of words inside `utterance` (words before
    /// and after that run are free). `utterance` is not empty.
    private static func distance(_ question: [String], within utterance: [String]) -> Int {
        var previous = [Int](repeating: 0, count: utterance.count + 1) // the run may start anywhere
        for i in 1...question.count {
            var row = [Int](repeating: i, count: utterance.count + 1)
            for j in 1...utterance.count {
                let substitution = previous[j - 1] + (question[i - 1] == utterance[j - 1] ? 0 : 1)
                row[j] = min(substitution, previous[j] + 1, row[j - 1] + 1)
            }
            previous = row
        }
        return previous.min() ?? question.count // and end anywhere
    }
}
