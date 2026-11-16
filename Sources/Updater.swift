import Foundation
import Security

/// What the settings UI shows about app updates.
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, notes: String)
    case downloading(progress: Double)
    case installing
    case failed(String)
}

enum UpdateError: LocalizedError {
    case badResponse
    case noAsset
    case unpackFailed
    case notTrusted
    case cannotWrite

    var errorDescription: String? {
        switch self {
        case .badResponse: "Không đọc được thông tin bản mới từ GitHub."
        case .noAsset: "Bản mới chưa có file Undertone.zip."
        case .unpackFailed: "Không giải nén được bản mới."
        case .notTrusted: "Bản mới không cùng chữ ký với app đang chạy nên không cài."
        case .cannotWrite: "Không ghi được vào thư mục chứa app. Hãy tải bản mới thủ công."
        }
    }
}

/// Self-update from the latest GitHub release (no Sparkle): download Undertone.zip, check that it is
/// signed like the running app (so the system-audio permission carries over), then a small shell
/// helper swaps the bundle once this app has quit and opens the new one.
enum Updater {
    struct Release {
        let version: String
        let notes: String
        let zipURL: URL
    }

    static let latestURL = URL(string: "https://api.github.com/repos/belong0205-cmyk/undertone/releases/latest")!

    static func latest() async throws -> Release {
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else { throw UpdateError.badResponse }
        let assets = json["assets"] as? [[String: Any]] ?? []
        guard let link = assets.first(where: { $0["name"] as? String == "Undertone.zip" })?["browser_download_url"] as? String,
              let zipURL = URL(string: link)
        else { throw UpdateError.noAsset }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Release(version: version, notes: json["body"] as? String ?? "", zipURL: zipURL)
    }

    /// Numeric semver comparison: "0.10.0" is newer than "0.9.1"; missing parts count as 0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ v: String) -> [Int] { v.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Downloads the zip to a new temporary folder, reporting progress from 0 to 1.
    static func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
        let total = max(response.expectedContentLength, 1)
        var data = Data()
        data.reserveCapacity(Int(total))
        for try await byte in bytes {
            data.append(byte)
            if data.count % 65_536 == 0 { progress(min(Double(data.count) / Double(total), 1)) }
        }
        progress(1)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("UndertoneUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let zip = folder.appendingPathComponent("Undertone.zip")
        try data.write(to: zip)
        return zip
    }

    /// Unzips next to the zip and returns the new app once its signature matches `current`'s
    /// designated requirement (same bundle id and signing certificate).
    static func unpack(_ zip: URL, matching current: URL) throws -> URL {
        let folder = zip.deletingLastPathComponent()
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path]) else { throw UpdateError.unpackFailed }
        let app = folder.appendingPathComponent("Undertone.app")
        guard FileManager.default.fileExists(atPath: app.path) else { throw UpdateError.unpackFailed }
        guard isSignedLike(current, app) else { throw UpdateError.notTrusted }
        return app
    }

    static func isSignedLike(_ current: URL, _ candidate: URL) -> Bool {
        var currentCode: SecStaticCode?, candidateCode: SecStaticCode?, requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(current as CFURL, [], &currentCode) == errSecSuccess, let currentCode,
              SecCodeCopyDesignatedRequirement(currentCode, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(candidate as CFURL, [], &candidateCode) == errSecSuccess, let candidateCode
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(candidateCode, flags, requirement) == errSecSuccess
            && Bundle(url: candidate)?.bundleIdentifier == Bundle(url: current)?.bundleIdentifier
    }

    /// Copies the new app beside the current one (so a failure leaves the current app untouched),
    /// then starts a helper that waits for `pid` to exit, swaps the bundles and opens the new app.
    /// The caller quits right after.
    static func install(_ newApp: URL, replacing current: URL, afterExitOf pid: Int32) throws {
        let staged = current.deletingLastPathComponent().appendingPathComponent(".Undertone-update.app")
        try? FileManager.default.removeItem(at: staged)
        guard run("/usr/bin/ditto", [newApp.path, staged.path]) else { throw UpdateError.cannotWrite }
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2" && mv "$3" "$2" && open "$2"
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", script, "undertone-update", String(pid), current.path, staged.path]
        try helper.run()
    }

    @discardableResult
    private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
