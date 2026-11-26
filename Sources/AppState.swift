import AppKit
import AVFoundation

/// Live audio level, kept apart from AppState so ~20 Hz updates don't re-render the conversation.
@MainActor
final class AudioMeter: ObservableObject {
    @Published var level: Float = 0
}

@MainActor
final class AppState: ObservableObject {
    enum ListenState { case idle, starting, listening }

    /// One utterance heard from the system audio, with its translation and a suggested answer.
    struct Row: Identifiable, Equatable {
        let id: UUID
        var english = ""
        var isFinal = false
        var vietnamese = ""
        var answerEnglish = ""
        var answerVietnamese = ""
        var isProcessing = false
        var startedAt = Date() // first words on screen
        var finishedAt: Date? // final
        var question = "" // what was sent to Claude for this row (pieces joined)
    }

    @Published var listenState: ListenState = .idle {
        didSet { log("state: \(listenState)") }
    }
    @Published var rows: [Row] = []
    @Published var hasSignal = false {
        didSet { if hasSignal { log("audio signal detected") } }
    }
    @Published var errorMessage: String? {
        didSet { if let errorMessage { log("error: \(errorMessage)") } }
    }
    @Published var showSettings = false
    @Published var update: UpdateState = .idle

    @Published var apiKey: String { didSet { defaults.set(apiKey, forKey: "apiKey") } }
    @Published var sonioxKey: String { didSet { defaults.set(sonioxKey, forKey: "sonioxKey") } }
    @Published var opacity: Double { didSet { defaults.set(opacity, forKey: "opacity") } }

    /// Saved to profiles.json on every change, so views can edit `$state.profiles[i]` directly.
    @Published var profiles: [UserProfile] {
        didSet {
            saveProfiles()
            let previous = oldValue.first { $0.id == activeProfileID }?.promptBlock
            if previous != activeProfile?.promptBlock { scheduleCacheRewarm() }
        }
    }
    @Published var activeProfileID: UUID? {
        didSet {
            defaults.set(activeProfileID?.uuidString, forKey: "activeProfileID")
            if oldValue != activeProfileID { scheduleCacheRewarm() }
        }
    }

    /// Default Soniox key shipped inside the app (Resources/Secrets.plist, gitignored), used when
    /// the user has not saved one, so a fresh Mac can listen without typing a key.
    private static let bundledSonioxKey: String = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let secrets = NSDictionary(contentsOf: url),
              let key = secrets["SonioxKey"] as? String
        else { return "" }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    let meter = AudioMeter()
    private let defaults: UserDefaults
    private let profilesURL: URL
    // Internal (not private) so the latency harness can stop the tap and feed recorded speech instead.
    let capture = SystemAudioCapture()
    let transcriber = SonioxTranscriber()
    private var tasks: [UUID: Task<Void, Never>] = [:]
    /// Last request to the Claude API, to know whether its connection may have gone idle.
    private var lastAPIUse = Date.distantPast
    /// Keeps the knowledge base and the active profile in Claude's prompt cache: from app launch and
    /// after each wake in the real app, and from the start of listening anywhere.
    private var cacheWarmer: Task<Void, Never>?
    /// Only the real app warms the cache on its own; harnesses and tests are not bundles.
    private static let isApp = Bundle.main.bundleURL.pathExtension == "app"
    private var rewarmTask: Task<Void, Never>?
    /// Debug only: reports when the main thread falls behind (it also runs the transcriber).
    private var stallProbe: Task<Void, Never>?
    /// The release behind `.available`, kept for installUpdate().
    private var pendingRelease: Updater.Release?
    private var updateChecker: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, profilesURL: URL = ProfileStore.defaultURL) {
        self.defaults = defaults
        self.profilesURL = profilesURL
        apiKey = defaults.string(forKey: "apiKey") ?? ""
        let savedSonioxKey = defaults.string(forKey: "sonioxKey") ?? ""
        sonioxKey = savedSonioxKey.isEmpty ? Self.bundledSonioxKey : savedSonioxKey
        opacity = defaults.object(forKey: "opacity") as? Double ?? 1

        // First run with profiles: carry the old single "notes" setting over into a profile.
        let saved = ProfileStore.load(from: profilesURL)
        var profiles = saved ?? []
        let oldNotes = (defaults.string(forKey: "notes") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if saved == nil, !oldNotes.isEmpty {
            profiles.append(UserProfile(notes: oldNotes))
        }
        self.profiles = profiles
        let savedID = defaults.string(forKey: "activeProfileID").flatMap(UUID.init(uuidString:))
        activeProfileID = profiles.contains { $0.id == savedID } ? savedID : profiles.first?.id
        defaults.set(activeProfileID?.uuidString, forKey: "activeProfileID")
        if saved == nil, !profiles.isEmpty { saveProfiles() }

        transcriber.onUtterance = { [weak self] id, text, isFinal in
            self?.receive(id, text: text, isFinal: isFinal)
        }
        transcriber.onTranslation = { [weak self] id, vietnamese in
            guard let self, let index = rows.firstIndex(where: { $0.id == id }) else { return }
            rows[index].vietnamese = vietnamese
        }
        transcriber.onFailure = { [weak self] message in
            self?.stopListening()
            self?.errorMessage = message
        }

        if Self.isApp {
            if hasAPIKey { startCacheWarmer() }
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.hasAPIKey else { return }
                    self.log("wake: re-warming the prompt cache")
                    self.startCacheWarmer()
                }
            }
        }

        // Only the real app checks; harnesses and design snapshots are not bundles.
        if Self.isApp {
            updateChecker = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.checkForUpdates(silent: true)
                    // Test hook: `open --env UNDERTONE_INSTALL_UPDATE=1 Undertone.app` installs an
                    // available update without the settings UI (the panel is hidden from screenshots).
                    if ProcessInfo.processInfo.environment["UNDERTONE_INSTALL_UPDATE"] == "1",
                       case .available = self?.update {
                        await self?.installUpdate()
                    }
                    try? await Task.sleep(for: .seconds(6 * 3600))
                }
            }
        }
    }

    // MARK: - Updates

    var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    /// Asks GitHub for the latest release. Silent checks only ever surface `.available` and leave
    /// any update already in progress alone.
    func checkForUpdates(silent: Bool) async {
        switch update {
        case .checking, .downloading, .installing: return
        case .available where silent: return
        default: break
        }
        if !silent { update = .checking }
        do {
            let release = try await Updater.latest()
            if Updater.isNewer(release.version, than: appVersion) {
                pendingRelease = release
                update = .available(version: release.version, notes: release.notes)
            } else if !silent {
                update = .upToDate
            }
        } catch {
            if !silent { update = .failed(Self.updateMessage(error)) }
        }
        log("update check: \(update)")
    }

    /// Downloads and verifies the pending release, then quits; a helper swaps the app and reopens it.
    func installUpdate() async {
        guard let release = pendingRelease else { return }
        switch update {
        case .downloading, .installing: return
        default: break
        }
        update = .downloading(progress: 0)
        do {
            let zip = try await Updater.download(release.zipURL) { [weak self] progress in
                Task { @MainActor in
                    if case .downloading = self?.update { self?.update = .downloading(progress: progress) }
                }
            }
            update = .installing
            let current = Updater.originalURL(of: Bundle.main.bundleURL)
            log("update: installing over \(current.path)")
            let newApp = try await Task.detached { try Updater.unpack(zip, matching: current) }.value
            try Updater.install(newApp, replacing: current, afterExitOf: ProcessInfo.processInfo.processIdentifier)
            NSApp.terminate(nil)
        } catch {
            update = .failed(Self.updateMessage(error))
        }
    }

    private static func updateMessage(_ error: Error) -> String {
        if let error = error as? UpdateError { return error.errorDescription ?? "Cập nhật thất bại." }
        if error is URLError { return "Không kết nối được GitHub để cập nhật. Kiểm tra mạng rồi thử lại." }
        return "Cập nhật thất bại: \(error.localizedDescription)"
    }

    // MARK: - Profiles

    var activeProfile: UserProfile? { profiles.first { $0.id == activeProfileID } }

    /// Adds an empty profile and makes it active.
    @discardableResult
    func addProfile() -> UUID {
        let profile = UserProfile()
        profiles.append(profile)
        activeProfileID = profile.id
        return profile.id
    }

    func deleteProfile(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfile == nil { activeProfileID = profiles.first?.id }
    }

    /// Writes one profile to a ".undertone-profile" file (ProfileFile format) to move it to another Mac.
    func exportProfile(_ id: UUID, to url: URL) throws {
        guard let profile = profiles.first(where: { $0.id == id }) else { throw ProfileFileError.notFound }
        let data = try ProfileFile.data(for: profile)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ProfileFileError.unwritable(error.localizedDescription)
        }
    }

    /// Adds the profile in an exported file (.undertone-profile or .json) as a new profile, never
    /// overwriting one: it gets a new id, and " (nhập)" (" (nhập 2)"…) when its name is taken. It becomes
    /// the active profile; returns its id.
    @discardableResult
    func importProfile(fromFile url: URL) throws -> UUID {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProfileFileError.unreadable(error.localizedDescription)
        }
        var profile = try ProfileFile.profile(from: data)
        profile.id = UUID()
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        func taken(_ candidate: String) -> Bool {
            profiles.contains {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(candidate) == .orderedSame
            }
        }
        if !name.isEmpty, taken(name) {
            // "X (nhập)", then "X (nhập 2)", "X (nhập 3)"… when the same file is imported again.
            var candidate = name + " (nhập)"
            var number = 2
            while taken(candidate) {
                candidate = "\(name) (nhập \(number))"
                number += 1
            }
            profile.name = candidate
        }
        profiles.append(profile) // saved to profiles.json by didSet
        activeProfileID = profile.id
        return profile.id
    }

    /// Reads a Word/RTF/text file (usually a CV), has Claude match its text to the profile fields and
    /// overwrites those fields of the active profile (a new profile when there is none); fields the
    /// document does not cover keep their values. Returns how many fields were filled.
    /// Throws errors with Vietnamese messages.
    func importProfile(from url: URL) async throws -> Int {
        guard hasAPIKey else { throw ProfileImportError.noAPIKey }
        // Reading a large Word file can take a while; keep it off the main thread.
        let text = try await Task.detached { try ProfileImport.text(of: url) }.value
        let targetID = activeProfileID
        let reply = try await ClaudeClient(apiKey: trimmedKey).json(
            system: ProfileImport.system,
            user: ProfileImport.userMessage(documentText: text),
            schema: ProfileImport.schema)
        let values = try ProfileImport.values(fromReply: reply)
        guard !values.isEmpty else { return 0 }

        // A new profile only now that the import worked (none was active, or it was deleted meanwhile).
        let index = profiles.firstIndex { $0.id == targetID } ?? {
            let profile = UserProfile()
            profiles.append(profile)
            activeProfileID = profile.id
            return profiles.count - 1
        }()
        var profile = profiles[index]
        for field in UserProfile.fields {
            if let value = values[field.key] { profile[keyPath: field.keyPath] = value }
        }
        profiles[index] = profile
        return values.count
    }

    /// The active profile's notes, kept for the older single "Bối cảnh cho AI" field.
    var notes: String {
        get { activeProfile?.notes ?? "" }
        set {
            if let index = profiles.firstIndex(where: { $0.id == activeProfileID }) {
                profiles[index].notes = newValue
            } else if !newValue.isEmpty {
                let profile = UserProfile(notes: newValue)
                profiles.append(profile)
                activeProfileID = profile.id
            }
        }
    }

    private func saveProfiles() {
        do {
            try ProfileStore.save(profiles, to: profilesURL)
        } catch {
            errorMessage = "Không lưu được hồ sơ: \(error.localizedDescription)"
        }
    }

    var hasAPIKey: Bool { !trimmedKey.isEmpty }
    private var trimmedKey: String { apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - Listening

    func toggleListening() {
        if listenState == .idle {
            Task { await startListening() }
        } else {
            stopListening()
        }
    }

    func startListening() async {
        guard listenState == .idle else { return }
        errorMessage = nil
        hasSignal = false
        listenState = .starting
        let sonioxKey = sonioxKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sonioxKey.isEmpty else {
            listenState = .idle
            showSettings = true
            errorMessage = "Hãy nhập Soniox API key trong phần cài đặt."
            return
        }
        do {
            try transcriber.start(apiKey: sonioxKey)
            let transcriber = self.transcriber
            let sampler = LevelSampler()
            try capture.start { [weak self] buffer in
                transcriber.append(buffer)
                if let level = sampler.throttledLevel(sampler.rms(buffer)) {
                    Task { @MainActor in self?.showLevel(level) }
                }
            }
            listenState = .listening
            if hasAPIKey { startCacheWarmer() }
            if DebugLog.enabled { stallProbe = Self.probeMainThread() }
        } catch {
            transcriber.stop()
            capture.stop()
            listenState = .idle
            errorMessage = "Không thể bắt đầu nghe: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        capture.stop()
        transcriber.stop()
        if !Self.isApp { // the real app keeps its cache warm while open
            cacheWarmer?.cancel()
            cacheWarmer = nil
            rewarmTask?.cancel()
            rewarmTask = nil
        }
        stallProbe?.cancel()
        stallProbe = nil
        listenState = .idle
        meter.level = 0
    }

    private func startCacheWarmer() {
        cacheWarmer?.cancel()
        cacheWarmer = ClaudeClient(apiKey: trimmedKey)
            .keepCacheWarm(system: Self.systemPrompt, profile: activeProfile?.promptBlock)
    }

    /// The prompt changed (profile edited or switched): re-warm once typing has paused.
    private func scheduleCacheRewarm() {
        guard Self.isApp || listenState == .listening, hasAPIKey else { return }
        rewarmTask?.cancel()
        rewarmTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, Self.isApp || self.listenState == .listening else { return }
            self.startCacheWarmer()
        }
    }

    private func showLevel(_ level: Float) {
        guard listenState == .listening else { return }
        meter.level = level
        if level > 0.1, !hasSignal { hasSignal = true }
    }

    func clearConversation() {
        transcriber.discardCurrent()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        rows.removeAll()
    }

    // MARK: - Translation and answers

    private func receive(_ id: UUID, text: String, isFinal: Bool) {
        if let index = rows.firstIndex(where: { $0.id == id }) {
            rows[index].english = text
            rows[index].isFinal = isFinal
            if isFinal { rows[index].finishedAt = Date() }
        } else {
            rows.append(Row(id: id, english: text, isFinal: isFinal, finishedAt: isFinal ? Date() : nil))
            log("partial #\(DebugLog.tag(id))")
            // Someone started talking: have the API connection ready before their sentence ends.
            if hasAPIKey, Date().timeIntervalSince(lastAPIUse) > 20 {
                lastAPIUse = Date()
                ClaudeClient(apiKey: trimmedKey).preconnect()
            }
        }
        // No early answer from partials: Soniox updates partials in bursts more than 300 ms apart while
        // the speaker is still talking, so every early request measured hit half a sentence and had to be
        // redone, while the final itself arrives 0.2-0.8 s after speech ends.
        if isFinal {
            log("heard #\(DebugLog.tag(id)): \(text)")
            process(id)
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        DebugLog.log(message())
    }

    private static func probeMainThread() -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                let due = Date().addingTimeInterval(0.25)
                try? await Task.sleep(for: .milliseconds(250), tolerance: .milliseconds(10))
                let late = Date().timeIntervalSince(due)
                if late > 0.15 { DebugLog.log(String(format: "main thread late %.0f ms", late * 1000)) }
            }
        }
    }

    private func process(_ id: UUID) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        if Prompt.isFiller(rows[index].english) {
            log("filler #\(DebugLog.tag(id)), no Claude call")
            return
        }
        // A question cut by pauses arrives as several rows: answer them together on the newest row, and
        // drop the answers given to the earlier pieces (a complete question never waits for more).
        let heard = rows[...index].filter(\.isFinal).suffix(40) // a long question can come in many pieces
        let pieces = Array(heard).map { Prompt.Heard(text: $0.english, start: $0.startedAt, end: $0.finishedAt ?? $0.startedAt) }
        let first = Prompt.questionStart(pieces)
        for row in heard.dropFirst(first).dropLast() {
            tasks[row.id]?.cancel()
            tasks[row.id] = nil
            guard let i = rows.firstIndex(where: { $0.id == row.id }) else { continue }
            rows[i].answerEnglish = ""
            rows[i].answerVietnamese = ""
            rows[i].isProcessing = false
            log("claude #\(DebugLog.tag(row.id)) replaced: joins #\(DebugLog.tag(id))")
        }
        let question = pieces[first...].map(\.text).joined(separator: " ")
        // "Tell me more", "Why?"… right after an answer: send that exchange and allow a longer answer.
        let firstRowID = heard.dropFirst(first).first?.id ?? id
        let earlier = rows.prefix { $0.id != firstRowID }
        let answered = earlier.filter { !$0.answerEnglish.isEmpty && !$0.question.isEmpty }.suffix(1)
            .map { (exchange: Prompt.Exchange(question: $0.question, answer: $0.answerEnglish), end: $0.finishedAt ?? $0.startedAt) }
        let previous = Prompt.previousExchange(for: question, startedAt: pieces[first].start, answered: Array(answered))
        rows[index].question = question
        // A question the user settled an answer for: that answer, word for word, at once and without Claude.
        // (A follow-up to it still goes to Claude, with it as the previous exchange.)
        if previous == nil, let fixed = FixedAnswers.match(question) {
            rows[index].answerEnglish = fixed.answer
            rows[index].answerVietnamese = fixed.vietnamese
            log("fixed answer #\(DebugLog.tag(id)), no Claude call")
            return
        }
        guard hasAPIKey else { return } // fixed answers above need no key
        let message = Prompt.user(history: Array(pieces[..<first].suffix(10)), utterance: question, previous: previous)
        let profile = activeProfile?.promptBlock
        let client = ClaudeClient(apiKey: trimmedKey)
        lastAPIUse = Date()
        rows[index].isProcessing = true
        let tag = DebugLog.tag(id)
        log("claude #\(tag) start\(previous == nil ? "" : " (follow-up)"), \(tasks.count + 1) in flight, "
            + "\(pieces.count - first) piece(s): \(question)")

        tasks[id] = Task { [weak self] in
            let started = Date()
            var output = ""
            var answerLogged = false
            var answerDone = false
            do {
                for try await chunk in client.stream(system: Self.systemPrompt, profile: profile, user: message,
                                                     maxTokens: 2048, tag: tag) {
                    if Task.isCancelled { // replaced: a chunk already received must not bring it back
                        DebugLog.log(String(format: "claude #%@ cancelled after %.2f s", tag, Date().timeIntervalSince(started)))
                        break
                    }
                    if output.isEmpty {
                        DebugLog.log(String(format: "claude #%@ first token %.2f s", tag, Date().timeIntervalSince(started)))
                    }
                    output += chunk
                    if !answerLogged, !Prompt.section("answer_en", in: output).isEmpty {
                        answerLogged = true
                        DebugLog.log(String(format: "claude #%@ answer on screen %.2f s", tag, Date().timeIntervalSince(started)))
                    }
                    if !answerDone, output.contains("</answer_en>") {
                        answerDone = true
                        DebugLog.log(String(format: "claude #%@ answer_en complete %.2f s", tag, Date().timeIntervalSince(started)))
                    }
                    self?.apply(output, to: id)
                }
            } catch {
                DebugLog.log("claude #\(tag) error: \(error.localizedDescription)")
                if !Task.isCancelled { self?.errorMessage = error.localizedDescription }
            }
            DebugLog.log(String(format: "claude #%@ done %.2f s", tag, Date().timeIntervalSince(started)))
            self?.finish(id)
        }
    }

    private func apply(_ output: String, to id: UUID) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].answerEnglish = Prompt.section("answer_en", in: output)
        rows[index].answerVietnamese = Prompt.section("answer_vi", in: output)
    }

    private func finish(_ id: UUID) {
        tasks[id] = nil
        if let index = rows.firstIndex(where: { $0.id == id }) {
            rows[index].isProcessing = false
            log("vi #\(DebugLog.tag(id)): \(rows[index].vietnamese) | answer: \(rows[index].answerEnglish.isEmpty ? "-" : rows[index].answerEnglish)")
        }
    }

    /// Tells Claude how French kitchen terms tend to be mis-heard so it can correct them.
    private static let systemPrompt = Prompt.system + "\n\n" + CulinaryTerms.transcriptNote
}
