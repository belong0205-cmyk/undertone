import Foundation

/// What one person using the app has told it about themselves. When a question in the conversation
/// is about "me", Claude answers from the active profile.
struct UserProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var age = ""
    var phone = ""
    var email = ""
    var address = ""
    /// Workplace and role.
    var work = ""
    /// Career objective.
    var objective = ""
    var experience = ""
    /// Education and courses.
    var education = ""
    var skills = ""
    var certificates = ""
    var languages = ""
    /// Signature dishes.
    var specialties = ""
    var menu = ""
    var recipes = ""
    var hobbies = ""
    /// Other context for the AI.
    var notes = ""

    /// Every editable text field in display and prompt order. The UI, the prompt block and the
    /// Word import all loop over this list.
    static let fields: [ProfileField] = [
        ProfileField(key: "name", keyPath: \.name, label: "Tên", promptLabel: "Name"),
        ProfileField(key: "age", keyPath: \.age, label: "Tuổi", promptLabel: "Age"),
        ProfileField(key: "phone", keyPath: \.phone, label: "Số điện thoại", promptLabel: "Phone"),
        ProfileField(key: "email", keyPath: \.email, label: "Email", promptLabel: "Email"),
        ProfileField(key: "address", keyPath: \.address, label: "Địa chỉ", promptLabel: "Address"),
        ProfileField(key: "work", keyPath: \.work, label: "Nơi làm việc / vị trí",
                     promptLabel: "Work (workplace and role)"),
        ProfileField(key: "objective", keyPath: \.objective, label: "Mục tiêu nghề nghiệp",
                     promptLabel: "Career objective", multiline: true),
        ProfileField(key: "experience", keyPath: \.experience, label: "Kinh nghiệm làm việc",
                     promptLabel: "Work experience", multiline: true),
        ProfileField(key: "education", keyPath: \.education, label: "Học vấn / khóa học",
                     promptLabel: "Education and courses", multiline: true),
        ProfileField(key: "skills", keyPath: \.skills, label: "Kỹ năng", promptLabel: "Skills", multiline: true),
        ProfileField(key: "certificates", keyPath: \.certificates, label: "Chứng chỉ",
                     promptLabel: "Certificates", multiline: true),
        ProfileField(key: "languages", keyPath: \.languages, label: "Ngoại ngữ", promptLabel: "Languages"),
        ProfileField(key: "specialties", keyPath: \.specialties, label: "Món sở trường",
                     promptLabel: "Signature dishes", multiline: true),
        ProfileField(key: "menu", keyPath: \.menu, label: "Menu", promptLabel: "Menu", multiline: true),
        ProfileField(key: "recipes", keyPath: \.recipes, label: "Công thức", promptLabel: "Recipes", multiline: true),
        ProfileField(key: "hobbies", keyPath: \.hobbies, label: "Sở thích", promptLabel: "Hobbies"),
        ProfileField(key: "notes", keyPath: \.notes, label: "Ghi chú cho AI", promptLabel: "Other notes",
                     multiline: true),
    ]

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

    /// Non-empty fields with English labels for the prompt, in `fields` order.
    private var labeledFields: [(String, String)] {
        Self.fields
            .map { ($0.promptLabel, self[keyPath: $0.keyPath].trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.1.isEmpty }
    }
}

/// One text field of `UserProfile`.
struct ProfileField: Identifiable, @unchecked Sendable {
    /// Stored property name: the JSON key in profiles.json and in the Word import.
    let key: String
    let keyPath: WritableKeyPath<UserProfile, String>
    /// Vietnamese label for the UI.
    let label: String
    /// English label for Claude's prompt.
    let promptLabel: String
    /// Long text (a text box) rather than one line.
    var multiline = false

    var id: String { key }
}

extension UserProfile {
    /// Missing keys decode as empty, so profiles saved by an older version still load after fields are added.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        for field in Self.fields {
            guard let key = CodingKeys(stringValue: field.key) else { continue }
            self[keyPath: field.keyPath] = try container.decodeIfPresent(String.self, forKey: key) ?? ""
        }
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
