import Foundation

/// What one person using the app has told it about themselves. When a question in the conversation
/// is about "me", Claude answers from the active profile.
struct UserProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var age = ""
    var address = ""
    /// Workplace and role.
    var work = ""
    /// Signature dishes.
    var specialties = ""
    var menu = ""
    var recipes = ""
    /// Other context for the AI.
    var notes = ""

    var isEmpty: Bool { labeledFields.isEmpty }

    var displayName: String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Người dùng" : name
    }

    /// System-prompt block describing the user, or nil when nothing is filled in.
    var promptBlock: String? {
        let fields = labeledFields
        guard !fields.isEmpty else { return nil }
        let lines = fields.map { label, value in
            value.contains("\n") ? "\(label):\n\(value)" : "\(label): \(value)"
        }
        return """
            <user_profile>
            Facts the user entered about themselves. Use them only as described in the instructions.

            \(lines.joined(separator: "\n\n"))
            </user_profile>
            """
    }

    /// Non-empty fields with English labels for the prompt, in a fixed order.
    private var labeledFields: [(String, String)] {
        [
            ("Name", name), ("Age", age), ("Address", address), ("Work (workplace and role)", work),
            ("Signature dishes", specialties), ("Menu", menu), ("Recipes", recipes), ("Other notes", notes),
        ]
        .map { ($0.0, $0.1.trimmingCharacters(in: .whitespacesAndNewlines)) }
        .filter { !$0.1.isEmpty }
    }
}

extension UserProfile {
    /// Missing keys decode as empty, so profiles saved by an older version still load after fields are added.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) throws -> String {
            try container.decodeIfPresent(String.self, forKey: key) ?? ""
        }
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try text(.name)
        age = try text(.age)
        address = try text(.address)
        work = try text(.work)
        specialties = try text(.specialties)
        menu = try text(.menu)
        recipes = try text(.recipes)
        notes = try text(.notes)
    }
}

/// Saves profiles as JSON in ~/Library/Application Support/Undertone/profiles.json.
enum ProfileStore {
    static let defaultURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Undertone/profiles.json")

    /// nil when the file does not exist yet (first run), so callers can migrate older settings.
    /// An unreadable file is moved aside instead of being overwritten by the next save.
    static func load(from url: URL) -> [UserProfile]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode([UserProfile].self, from: data)
        } catch {
            let aside = url.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.moveItem(at: url, to: aside)
            return []
        }
    }

    static func save(_ profiles: [UserProfile], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: url, options: .atomic)
    }
}
