// Design tool: renders the overlay in its key states (and the app icon) to PNG files,
// without needing screen-recording permission. Usage: ./design.sh <output-dir>
import AppKit
import SwiftUI

let outputDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "design-out")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
_ = NSApplication.shared

@MainActor
func snapshot<V: View>(_ view: V, size: CGSize, name: String) {
    let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
    host.frame = NSRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = host
    window.appearance = NSAppearance(named: .darkAqua)
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: outputDir.appendingPathComponent("\(name).png"))
    print("wrote \(name).png")
}

/// Bright, busy content (like a web page) to check text contrast at low background settings.
struct BusyBackdrop: View {
    private let colors: [Color] = [.yellow, .orange, .cyan, .pink, .green]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<18, id: \.self) { i in
                    HStack(spacing: 10) {
                        Rectangle().fill(colors[i % colors.count]).frame(width: 90, height: 20)
                        Text("Food safety audit, section \(i + 1): temperatures, labels and storage rules")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
            }
            .padding(18)
        }
    }
}

/// The overlay over a desktop-like backdrop, the way it sits on screen.
@MainActor
func renderOverlay(_ name: String, size: CGSize = CGSize(width: 680, height: 440), textScale: Double = 1,
                   showingProfiles: Bool = false, busyBackdrop: Bool = false, configure: (AppState) -> Void) {
    let suite = "local.undertone.design"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    // A throwaway profiles file, never the user's real one.
    let profilesURL = FileManager.default.temporaryDirectory.appendingPathComponent("undertone-design-profiles.json")
    try? FileManager.default.removeItem(at: profilesURL)
    defer { try? FileManager.default.removeItem(at: profilesURL) }
    let state = AppState(defaults: defaults, profilesURL: profilesURL)
    configure(state)
    // OverlayView reads the text size with @AppStorage, i.e. from the standard defaults.
    UserDefaults.standard.set(textScale, forKey: Theme.textScaleKey)
    defer { UserDefaults.standard.removeObject(forKey: Theme.textScaleKey) }
    let backdrop = LinearGradient(
        colors: [Color(red: 0.20, green: 0.24, blue: 0.33), Color(red: 0.36, green: 0.31, blue: 0.40)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    let view = ZStack {
        if busyBackdrop { BusyBackdrop() } else { backdrop }
        OverlayView(showingProfiles: showingProfiles).environmentObject(state).frame(width: size.width, height: size.height)
    }
    snapshot(view, size: CGSize(width: size.width + 48, height: size.height + 48), name: name)
    defaults.removePersistentDomain(forName: suite)
}

MainActor.assumeIsolated {
    func row(_ en: String, _ vi: String = "", final: Bool = true, answerEN: String = "", answerVI: String = "", processing: Bool = false) -> AppState.Row {
        AppState.Row(id: UUID(), english: en, isFinal: final, vietnamese: vi, answerEnglish: answerEN, answerVietnamese: answerVI, isProcessing: processing)
    }
    // Chronological, as AppState stores them; the UI shows them newest first.
    let intro = row(
        "Okay, welcome to the practical assessment. Today you'll prepare a classic French omelette.",
        "Được rồi, chào mừng bạn đến bài đánh giá thực hành. Hôm nay bạn sẽ làm món trứng tráng kiểu Pháp."
    )
    let question = row(
        "What temperature should you keep hot food at during service?",
        "Trong lúc phục vụ, bạn phải giữ đồ ăn nóng ở nhiệt độ bao nhiêu?",
        answerEN: "I keep hot food at 60 degrees or above. I check it with a probe thermometer.",
        answerVI: "Tôi giữ đồ ăn nóng ở 60 độ trở lên. Tôi kiểm tra bằng nhiệt kế que."
    )
    let crossContamination = row(
        "How do you stop cross-contamination between raw chicken and the salad?",
        "Bạn làm thế nào để tránh lây nhiễm chéo giữa gà sống và món salad?",
        answerEN: "I use a red board for raw meat and a green board for salad. I wash my hands between tasks.",
        answerVI: "Tôi dùng thớt đỏ cho thịt sống và thớt xanh cho salad. Tôi rửa tay giữa các việc."
    )

    renderOverlay("1-empty-no-key") { state in
        state.listenState = .listening
    }
    for (name, scale) in [("2-conversation", 1.0), ("2b-conversation-text-160", 1.6)] {
        renderOverlay(name, textScale: scale) { state in
            state.apiKey = "design-preview"
            state.sonioxKey = "design-preview"
            state.listenState = .listening
            state.hasSignal = true
            state.meter.level = 0.6
            state.rows = [
                intro,
                question,
                crossContamination,
                row("And how would you make a beurre blanc for the", final: false),
            ]
        }
    }
    renderOverlay("3-answer-streaming") { state in
        state.apiKey = "design-preview"
        state.sonioxKey = "design-preview"
        state.listenState = .listening
        state.hasSignal = true
        state.rows = [
            intro,
            row(
                "Can you explain what mise en place means in a busy kitchen?",
                "Bạn có thể giải thích mise en place nghĩa là gì trong một căn bếp bận rộn không?",
                answerEN: "Mise en place means I prepare and set up everything",
                processing: true
            ),
        ]
    }
    let chef = UserProfile(
        name: "Trung Huy",
        age: "29",
        phone: "0412 345 678",
        email: "chef@example.com",
        address: "Footscray, Melbourne",
        work: "Commis chef, The Grand Hotel",
        experience: "2023–nay: Commis chef, The Grand Hotel\n2021–2023: Kitchen hand, Saigon Corner",
        skills: "Knife skills, sauces, HACCP, mise en place",
        languages: "Tiếng Việt, English (IELTS 6.5)",
        specialties: "Phở bò, bánh xèo, beurre blanc",
        menu: "Entrée: prawn cocktail\nMain: pan-fried barramundi, beurre blanc\nDessert: crème brûlée",
        recipes: "Beurre blanc: reduce white wine, vinegar and shallot; whisk in cold butter off the heat.",
        notes: "Đang học Cert III in Commercial Cookery (SIT30821)."
    )
    let second = UserProfile(name: "Lan", work: "Pastry cook")

    renderOverlay("4-settings") { state in
        state.listenState = .listening
        state.hasSignal = true
        state.rows = [intro, question]
        state.profiles = [chef]
        state.activeProfileID = chef.id
        state.showSettings = true
    }
    // "Độ đậm nền" over bright, busy content: text must stay crisp at every setting.
    for percent in [0, 40, 70, 100] {
        renderOverlay("9-background-\(percent)", busyBackdrop: true) { state in
            state.apiKey = "design-preview"
            state.sonioxKey = "design-preview"
            state.listenState = .listening
            state.hasSignal = true
            state.opacity = Double(percent) / 100
            state.rows = [intro, question, crossContamination]
        }
    }
    renderOverlay("7-profiles-empty", showingProfiles: true) { state in
        state.showSettings = true
    }
    renderOverlay("8-profiles-filled", showingProfiles: true) { state in
        state.profiles = [chef, second]
        state.activeProfileID = chef.id
        state.showSettings = true
    }
    // Tall enough to show every field of UserProfile.fields without scrolling.
    renderOverlay("8c-profiles-all-fields", size: CGSize(width: 680, height: 1560), showingProfiles: true) { state in
        state.profiles = [chef, second]
        state.activeProfileID = chef.id
        state.showSettings = true
    }
    renderOverlay("8b-profiles-min-size", size: CGSize(width: 520, height: 380), showingProfiles: true) { state in
        state.profiles = [chef, second]
        state.activeProfileID = chef.id
        state.showSettings = true
    }
    // In-app updates: one snapshot per state of the "Phiên bản" row.
    let updateStates: [(String, UpdateState)] = [
        ("idle", .idle), ("checking", .checking), ("uptodate", .upToDate),
        ("available", .available(version: "0.4.0", notes: "Nhập hồ sơ từ Word, panel trong suốt theo ý bạn, sửa lỗi con trỏ.")),
        ("downloading", .downloading(progress: 0.42)), ("installing", .installing),
        ("failed", .failed("Không kết nối được máy chủ cập nhật.")),
    ]
    for (name, update) in updateStates {
        renderOverlay("10-update-\(name)") { state in
            state.apiKey = "design-preview"
            state.sonioxKey = "design-preview"
            state.listenState = .listening
            state.rows = [intro]
            state.showSettings = true
            state.update = update
        }
    }
    renderOverlay("10b-update-min-size", size: CGSize(width: 520, height: 380)) { state in
        state.apiKey = "design-preview"
        state.sonioxKey = "design-preview"
        state.rows = [intro]
        state.showSettings = true
        state.update = .available(version: "0.4.0", notes: "Nhập hồ sơ từ Word, panel trong suốt theo ý bạn, sửa lỗi con trỏ.")
    }
    renderOverlay("4b-settings-min-size", size: CGSize(width: 520, height: 380)) { state in
        state.listenState = .listening
        state.rows = [intro]
        state.showSettings = true
    }
    renderOverlay("6-no-soniox-key") { state in
        state.apiKey = "design-preview"
        state.listenState = .idle
    }
    renderOverlay("5-paused-error") { state in
        state.apiKey = "design-preview"
        state.sonioxKey = "design-preview"
        state.listenState = .idle
        state.errorMessage = "API key không hợp lệ. Kiểm tra lại trong Cài đặt."
    }

    snapshot(AppIconArtwork(), size: CGSize(width: 1024, height: 1024), name: "AppIcon-1024")
}
