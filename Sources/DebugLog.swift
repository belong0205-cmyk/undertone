import Foundation

/// `open --env UNDERTONE_DEBUG=1 Undertone.app` prints pipeline events to stdout with millisecond
/// timestamps, so latencies can be read from the log. Safe to call from any thread.
enum DebugLog {
    static let enabled = ProcessInfo.processInfo.environment["UNDERTONE_DEBUG"] == "1"

    private static let lock = NSLock()
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let text = message()
        lock.withLock {
            print("\(formatter.string(from: Date())) [Undertone] \(text)")
            fflush(stdout)
        }
    }

    /// Short id for log lines.
    static func tag(_ id: UUID) -> String { String(id.uuidString.prefix(4)) }
}
