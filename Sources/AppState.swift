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
    }

    /// `open --env UNDERTONE_DEBUG=1 Undertone.app` logs utterances and errors to stdout.
    private static let debug = ProcessInfo.processInfo.environment["UNDERTONE_DEBUG"] == "1"

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
    private let capture = SystemAudioCapture()
    private let transcriber = SonioxTranscriber()
    private var tasks: [UUID: Task<Void, Never>] = [:]
    /// Keeps the knowledge base and the active profile in Claude's prompt cache while listening.
    private var cacheWarmer: Task<Void, Never>?
    private var rewarmTask: Task<Void, Never>?

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
        transcriber.onFailure = { [weak self] message in
            self?.stopListening()
            self?.errorMessage = message
        }
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
        cacheWarmer?.cancel()
        cacheWarmer = nil
        rewarmTask?.cancel()
        rewarmTask = nil
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
        guard listenState == .listening, hasAPIKey else { return }
        rewarmTask?.cancel()
        rewarmTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.listenState == .listening else { return }
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
        } else {
            rows.append(Row(id: id, english: text, isFinal: isFinal))
        }
        if isFinal {
            log("heard: \(text)")
            process(id)
        }
    }

    private func log(_ message: String) {
        guard Self.debug else { return }
        print("[Undertone] \(message)")
        fflush(stdout)
    }

    private func process(_ id: UUID) {
        guard hasAPIKey, let index = rows.firstIndex(where: { $0.id == id }) else { return }
        let history = rows[..<index].filter(\.isFinal).suffix(10).map(\.english).joined(separator: "\n")
        let message = Prompt.user(history: history, utterance: rows[index].english)
        let profile = activeProfile?.promptBlock
        let client = ClaudeClient(apiKey: trimmedKey)
        rows[index].isProcessing = true

        tasks[id] = Task { [weak self] in
            var output = ""
            do {
                for try await chunk in client.stream(system: Self.systemPrompt, profile: profile, user: message) {
                    output += chunk
                    self?.apply(output, to: id)
                }
            } catch {
                if !Task.isCancelled { self?.errorMessage = error.localizedDescription }
            }
            self?.finish(id)
        }
    }

    private func apply(_ output: String, to id: UUID) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].vietnamese = Prompt.section("vi", in: output)
        rows[index].answerEnglish = Prompt.section("answer_en", in: output)
        rows[index].answerVietnamese = Prompt.section("answer_vi", in: output)
    }

    private func finish(_ id: UUID) {
        tasks[id] = nil
        if let index = rows.firstIndex(where: { $0.id == id }) {
            rows[index].isProcessing = false
            log("vi: \(rows[index].vietnamese) | answer: \(rows[index].answerEnglish.isEmpty ? "-" : rows[index].answerEnglish)")
        }
    }

    /// Tells Claude how French kitchen terms tend to be mis-heard so it can correct them.
    private static let systemPrompt = Prompt.system + "\n\n" + CulinaryTerms.transcriptNote
}
