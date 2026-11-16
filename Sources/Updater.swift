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
        case .cannotWrite: "Không ghi được vào app hiện tại. Hãy tải bản mới thủ công."
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

    /// Download, unpack and rollback area: emptied before each download, removed by the helper after
    /// installing. Outside the app's folder, so nothing is created next to the app.
    static let stagingURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("local.undertone/Update")

    /// Streams the zip to `stagingURL` with a download task, reporting progress from 0 to 1.
    static func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try? FileManager.default.removeItem(at: stagingURL)
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        let zip = stagingURL.appendingPathComponent("Undertone.zip")
        let delegate = DownloadDelegate(destination: zip, progress: progress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil) // no copy in the HTTP cache
        defer { session.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delegate.continuation = continuation
            session.downloadTask(with: url).resume()
        }
        return zip
    }

    /// Callbacks arrive one at a time on the session's serial delegate queue.
    private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        let destination: URL
        let progress: @Sendable (Double) -> Void
        var continuation: CheckedContinuation<Void, Error>?
        private var failure: Error?

        init(destination: URL, progress: @escaping @Sendable (Double) -> Void) {
            self.destination = destination
            self.progress = progress
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            progress(min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1))
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else {
                failure = UpdateError.badResponse
                return
            }
            do { try FileManager.default.moveItem(at: location, to: destination) } catch { failure = error }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error ?? failure {
                continuation?.resume(throwing: error)
            } else {
                progress(1)
                continuation?.resume()
            }
            continuation = nil
        }
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

    /// The app's real location. A downloaded (quarantined) app that was not moved with Finder runs from
    /// a read-only App Translocation copy under /private/var/folders/.../AppTranslocation/, so writing
    /// next to Bundle.main fails ("Không ghi được…", seen on the user's Mac). Security.framework maps
    /// that copy back to the original path; the function is not in the public headers, so it is
    /// looked up at run time and the URL is returned unchanged if it is missing.
    static func originalURL(of url: URL) -> URL {
        guard url.path.contains("/AppTranslocation/"),
              let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(security, "SecTranslocateCreateOriginalPathForURL")
        else { return url }
        typealias Original = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        let original = unsafeBitCast(symbol, to: Original.self)
        return original(url as CFURL, nil)?.takeRetainedValue() as URL? ?? url
    }

    /// Where the update helper writes what it did (it runs after the app has quit).
    static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Undertone-update.log")

    /// Starts a helper that waits for `pid` to exit, copies the current bundle to a rollback copy in
    /// the staging folder, syncs the new bundle over the current one in place (restoring the copy if
    /// that fails), reopens the app and removes the staging folder. The caller quits right after.
    /// The bundle is only ever updated in place: nothing new is created or renamed next to the app.
    static func install(_ newApp: URL, replacing current: URL, afterExitOf pid: Int32) throws {
        guard FileManager.default.isWritableFile(atPath: current.path) else { throw UpdateError.cannotWrite }
        let staging = newApp.deletingLastPathComponent()
        let rollback = staging.appendingPathComponent("Rollback.app")
        let script = """
        exec >>"$5" 2>&1
        echo "$(date) update $2 from $3"
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$4"
        if /usr/bin/ditto "$2" "$4"; then
          if /usr/bin/rsync -a --delete "$3/" "$2/"; then echo "replaced"
          else echo "rsync failed with status $?, restoring"; /usr/bin/rsync -a --delete "$4/" "$2/" && echo "restored"; fi
        else echo "could not make a rollback copy, update skipped"; fi
        # The new bundle matched our signature; without quarantine, macOS runs it in place next time.
        /usr/bin/xattr -dr com.apple.quarantine "$2"
        open "$2"
        rm -rf "$6"
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", script, "undertone-update", String(pid), current.path, newApp.path,
                            rollback.path, logURL.path, staging.path]
        try helper.run()
    }

    /// Runs a tool and waits; on failure its status and stderr go to the debug log.
    @discardableResult
    private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        do { try process.run() } catch {
            DebugLog.log("updater: \(tool) did not start: \(error.localizedDescription)")
            return false
        }
        let output = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            DebugLog.log("updater: \(tool) exited \(process.terminationStatus): \(String(decoding: output, as: UTF8.self))")
        }
        return process.terminationStatus == 0
    }
}
