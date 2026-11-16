import AppKit

enum ProfileImportError: LocalizedError {
    case noAPIKey
    case unreadableFile
    case emptyText
    case badReply

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "Hãy nhập Claude API key trong phần cài đặt để nhập hồ sơ từ file."
        case .unreadableFile: "Không đọc được file này. Hãy chọn file Word (.docx, .doc), .rtf hoặc .txt."
        case .emptyText: "File không có chữ nào để nhập."
        case .badReply: "AI trả về dữ liệu không đọc được. Hãy thử lại."
        }
    }
}

/// Fills profile fields from a document the user uploads (usually a CV), via Claude.
enum ProfileImport {
    /// Plain text of a .docx, .doc, .rtf or .txt file (anything NSAttributedString can read).
    static func text(of url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let raw: String
        if url.pathExtension.lowercased() == "txt" {
            guard let data = try? Data(contentsOf: url), let decoded = decodePlainText(data) else {
                throw ProfileImportError.unreadableFile
            }
            raw = decoded
        } else {
            var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]
            switch url.pathExtension.lowercased() {
            case "docx": options[.documentType] = NSAttributedString.DocumentType.officeOpenXML
            case "doc": options[.documentType] = NSAttributedString.DocumentType.docFormat
            case "rtf": options[.documentType] = NSAttributedString.DocumentType.rtf
            default: break
            }
            guard let document = try? NSAttributedString(url: url, options: options, documentAttributes: nil) else {
                throw ProfileImportError.unreadableFile
            }
            raw = document.string
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ProfileImportError.emptyText }
        return text
    }

    /// A .txt file in whatever encoding it was saved in: UTF-8, UTF-16 (with a byte-order mark), or a
    /// Windows code page (Vietnamese 1258 first, then Western 1252), as Notepad saves "ANSI" files.
    static func decodePlainText(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) { return text }
        let windowsVietnamese = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.windowsVietnamese.rawValue)))
        for encoding in [windowsVietnamese, .windowsCP1252] {
            // 1258 spells tones as combining marks; compose them ("ễ", not "ê" + tilde).
            if let text = String(data: data, encoding: encoding) { return text.precomposedStringWithCanonicalMapping }
        }
        return nil
    }

    static let system = """
    You fill in a person's profile from a document they uploaded about themselves, usually a CV or résumé. \
    Return one JSON value per profile field.

    Rules:
    - Copy or condense text from the document only. Never invent, guess or add anything the document does not say.
    - Write every value in the document's own language.
    - Use an empty string for a field the document does not cover.
    - For a list (jobs, courses, skills, certificates, dishes), put one item per line. Keep dates, places and \
    names exactly as written.
    - Information about the person that fits no other field goes to "notes". Leave out headings, page \
    decoration and anything that is not about the person.
    """

    /// What each field should hold, for Claude.
    private static let hints: [String: String] = [
        "name": "The person's full name.",
        "dateOfBirth": "Date of birth exactly as written (or the age, if only that is given).",
        "phone": "Phone number(s).",
        "email": "Email address(es).",
        "address": "Home address or city.",
        "work": "Current (or latest) workplace and role, one line.",
        "workplaceAddress": "Address of the current workplace.",
        "yearsOfExperience": "Total years of work experience, as stated.",
        "shifts": "Shifts the person works (e.g. breakfast, lunch, dinner, split shift) and days.",
        "workHours": "Time the person starts and finishes work, as start–finish (e.g. 14:00–23:00).",
        "openingHours": "Time the restaurant or workplace opens and closes, as open–close (e.g. 11:00–22:00).",
        "kitchenStaff": "How many people work in the kitchen.",
        "kitchenTeam": "Kitchen brigade: how many head chefs, sous chefs, chefs de partie, commis, kitchen hands.",
        "responsibilities": "Main responsibilities in the current job, one per line.",
        "dailyRoutine": "What a normal working day looks like, step by step, one step per line.",
        "objective": "Career objective or personal summary.",
        "experience": "Work history: role, workplace, dates and main duties, one job per line.",
        "education": "Schools, degrees, courses and training, one per line.",
        "skills": "Skills, one per line.",
        "certificates": "Certificates and licences, one per line.",
        "languages": "Languages spoken and their level.",
        "specialties": "Signature dishes or cooking specialties.",
        "menu": "A menu the person cooks or has written.",
        "recipes": "Recipes written in the document.",
        "hobbies": "Hobbies and interests.",
        "notes": "Anything else about the person (e.g. references, availability, visa status).",
    ]

    /// JSON schema with one required string per profile field.
    static var schema: [String: Any] {
        var properties: [String: Any] = [:]
        for field in UserProfile.fields {
            properties[field.key] = [
                "type": "string",
                "description": "\(field.promptLabel). \(hints[field.key] ?? "")",
            ]
        }
        return [
            "type": "object",
            "properties": properties,
            "required": UserProfile.fields.map(\.key),
            "additionalProperties": false,
        ]
    }

    static func userMessage(documentText: String) -> String {
        "<document>\n\(documentText)\n</document>"
    }

    /// Field key -> trimmed non-empty value from Claude's JSON reply.
    static func values(fromReply reply: String) throws -> [String: String] {
        guard let data = reply.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ProfileImportError.badReply }
        var values: [String: String] = [:]
        for field in UserProfile.fields {
            let value = (object[field.key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { values[field.key] = value }
        }
        return values
    }
}
