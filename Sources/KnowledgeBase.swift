import Foundation

/// Reference notes for SIT30821 Certificate III in Commercial Cookery, bundled as
/// `Contents/Resources/Knowledge/*.md`. They are sent as the first system block with a cache
/// breakpoint, so Claude processes them once and every later answer reads them from the cache.
enum KnowledgeBase {
    /// All notes as one system-prompt block, or an empty string if none are bundled.
    static let promptBlock: String = {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent("Knowledge"),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: nil)
        else { return "" }

        let notes = files
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n\n")
        guard !notes.isEmpty else { return "" }

        return """
            <knowledge_base>
            \(notes)
            </knowledge_base>

            The knowledge base above holds reference notes for the Australian qualification SIT30821 \
            Certificate III in Commercial Cookery (cookery techniques, food safety, WHS, costing, stock \
            control, special diets, kitchen operations). When the question is about these topics, base \
            the answer on these notes: use their Australian standards, temperatures, times, formulas and \
            terminology rather than figures from other countries. For anything the notes do not cover, \
            answer from general knowledge.
            """
    }()
}
