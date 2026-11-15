import AppKit
import SwiftUI

/// The whole UI: one bar, then a newest-first timeline of utterances in two columns
/// (Vietnamese | English); settings hidden behind one icon.
struct OverlayView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            Conversation()
                .frame(maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            if let message = state.errorMessage {
                ErrorBar(message: message) { state.errorMessage = nil }
            }
        }
        .overlay {
            if state.showSettings {
                SettingsOverlay().transition(.opacity)
            }
        }
        .background {
            ZStack {
                VisualEffectBackground()
                Theme.tint.opacity(0.85)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline))
        .environment(\.colorScheme, .dark)
        .tint(Theme.accent)
        .animation(.easeOut(duration: 0.15), value: state.showSettings)
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        // Same geometry as the timeline rows, so each caption sits right above its column.
        HStack(spacing: 0) {
            Color.clear.frame(width: Theme.gutter)
            Columns(leading: Theme.afterGutter) {
                Caption(text: "Tiếng Việt")
            } right: {
                Caption(text: "English")
            }
        }
        .frame(height: 36)
        .overlay(alignment: .trailing) {
            HStack(spacing: 2) {
                ListenDot(meter: state.meter)
                SettingsButton()
            }
            .padding(.trailing, 6)
        }
        .background(WindowDragArea())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Green and breathing with the audio level while listening; a hollow ring when paused. Click to toggle.
private struct ListenDot: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var meter: AudioMeter

    var body: some View {
        Button { state.toggleListening() } label: {
            ZStack {
                switch state.listenState {
                case .listening:
                    Circle()
                        .fill(Theme.accent.opacity(0.28))
                        .frame(width: 8 + 12 * CGFloat(meter.level), height: 8 + 12 * CGFloat(meter.level))
                        .animation(.easeOut(duration: 0.12), value: meter.level)
                    Circle().fill(Theme.accent).frame(width: 7, height: 7)
                case .starting:
                    Circle().fill(Theme.warning).frame(width: 7, height: 7)
                case .idle:
                    Circle().strokeBorder(Theme.textSecondary, lineWidth: 1.5).frame(width: 8, height: 8)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.listenState == .idle ? "Bắt đầu nghe" : "Tạm dừng nghe")
    }
}

private struct SettingsButton: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        IconButton(systemName: "gearshape", label: "Cài đặt") { state.showSettings.toggle() }
            .overlay(alignment: .topTrailing) {
                if !state.hasAPIKey || !state.hasSonioxKey { // nudge: a required key is missing
                    Circle().fill(Theme.accent).frame(width: 6, height: 6).offset(x: -4, y: 4)
                }
            }
    }
}

private extension AppState {
    /// Without it nothing is heard at all (Soniox does the speech recognition).
    var hasSonioxKey: Bool { !sonioxKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Conversation (newest first)

private struct Conversation: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if state.rows.isEmpty {
            EmptyColumns()
        } else {
            // AppState appends; the view shows the newest utterance on top.
            let newestFirst = Array(state.rows.reversed())
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    Color.clear.frame(height: 0).id(Self.top)
                    LazyVStack(spacing: 0) {
                        ForEach(Array(newestFirst.enumerated()), id: \.element.id) { index, row in
                            TimelineRow(
                                row: row,
                                isNewest: index == 0,
                                isOldest: index == newestFirst.count - 1,
                                translating: state.hasAPIKey
                            )
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                }
                .onChange(of: state.rows.count) { _, _ in
                    // A new utterance lands on top: bring the top into view.
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.top, anchor: .top) }
                }
            }
        }
    }

    private static let top = "timeline-top"
}

/// One utterance: a dot on the timeline, then Vietnamese | English, then the suggested answer.
private struct TimelineRow: View {
    let row: AppState.Row
    let isNewest: Bool
    let isOldest: Bool
    let translating: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            TimelineGutter(isNewest: isNewest, isOldest: isOldest)
            VStack(alignment: .leading, spacing: 8) {
                Columns(leading: Theme.afterGutter) {
                    if !row.vietnamese.isEmpty {
                        Text(row.vietnamese).utterance(color: Theme.textPrimary)
                    } else if translating && (row.isProcessing || !row.isFinal) {
                        PendingDots()
                    }
                } right: {
                    Text(row.english).utterance(color: row.isFinal ? Theme.textSecondary : Theme.textTertiary)
                }
                if !row.answerEnglish.isEmpty {
                    Columns(leading: Theme.afterGutter) {
                        AnswerCard(label: "Đáp", text: row.answerVietnamese, highlighted: isNewest)
                    } right: {
                        AnswerCard(label: "Say", text: row.answerEnglish, highlighted: isNewest)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Thin vertical line with a dot level with the row's first line of text; the newest dot is green.
private struct TimelineGutter: View {
    let isNewest: Bool
    let isOldest: Bool

    var body: some View {
        VStack(spacing: 0) {
            line.opacity(isNewest ? 0 : 1).frame(height: 5)
            Circle()
                .fill(isNewest ? Theme.accent : Theme.dot)
                .frame(width: 7, height: 7)
            line.opacity(isOldest ? 0 : 1).frame(maxHeight: .infinity)
        }
        .frame(width: Theme.gutter)
    }

    private var line: some View {
        Rectangle().fill(Theme.timeline).frame(width: 1)
    }
}

/// The suggested answer, short by design: a quiet card with a mono label, like an IN/OUT block.
private struct AnswerCard: View {
    let label: String
    let text: String
    let highlighted: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(highlighted ? Theme.accent : Theme.textTertiary)
                .frame(width: 26, alignment: .leading)
            if text.isEmpty {
                // An invisible line of answer text gives the dots the label's baseline.
                ZStack(alignment: .leading) {
                    Text(" ").font(Theme.answer)
                    PendingDots()
                }
            } else {
                AnswerText(text: text)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.answerFill))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.answerStroke))
    }
}

private extension Text {
    func utterance(color: Color) -> some View {
        font(Theme.body)
            .foregroundStyle(color)
            .lineSpacing(3)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct EmptyColumns: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear.frame(width: Theme.gutter, height: 1)
            Columns(leading: Theme.afterGutter) {
                EmptyNote(title: vietnamese.title, detail: vietnamese.detail)
            } right: {
                EmptyNote(title: english, detail: nil)
            }
        }
        .padding(.top, 14)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var vietnamese: (title: String, detail: String) {
        switch state.listenState {
        case .idle:
            if !state.hasSonioxKey { return ("Chưa thể nghe", "Thêm Soniox key trong ⚙, rồi bấm vào chấm tròn ở góc trên để bắt đầu.") }
            return ("Đã tạm dừng", "Bấm vào chấm tròn ở góc trên để nghe tiếp.")
        case .starting:
            return ("Đang khởi động…", "")
        case .listening:
            if !state.hasAPIKey { return ("Đang nghe…", "Thêm API key trong ⚙ để bật dịch và gợi ý trả lời.") }
            if !state.hasSignal { return ("Đang nghe…", "Chưa có âm thanh. Nếu máy đang phát tiếng mà nơi này vẫn trống, hãy cấp quyền Ghi âm thanh hệ thống cho Undertone.") }
            return ("Đang nghe…", "Bản dịch và gợi ý trả lời sẽ hiện ở đây.")
        }
    }

    private var english: String {
        switch state.listenState {
        case .idle: "Paused"
        case .starting: "Starting…"
        case .listening: "Listening…"
        }
    }
}

private struct EmptyNote: View {
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textSecondary)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ErrorBar: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.warning)
                .padding(.top, 1)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Đóng thông báo")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(red: 0.17, green: 0.13, blue: 0.08))
        .overlay(alignment: .top) { Rectangle().fill(Theme.warning.opacity(0.3)).frame(height: 1) }
    }
}

// MARK: - Settings (only visible after clicking the gear)

private struct SettingsOverlay: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.4)
                .contentShape(Rectangle())
                .onTapGesture { state.showSettings = false }
            SettingsCard()
                .padding(.top, 40)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
        }
    }
}

private struct SettingsCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        // Scroll only when the panel is too short to show the whole card.
        ViewThatFits(in: .vertical) {
            fields
            ScrollView(showsIndicators: false) { fields }
        }
        .frame(width: 290)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .onExitCommand { state.showSettings = false }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 13) {
            SettingsField("API keys", hint: "Claude dịch và gợi ý trả lời; Soniox nhận dạng giọng nói Anh–Pháp. Chỉ lưu trên máy này.") {
                VStack(spacing: 6) {
                    KeyField(label: "Claude", prompt: "sk-ant-…", text: $state.apiKey)
                    KeyField(label: "Soniox", prompt: "Soniox key", text: $state.sonioxKey)
                }
            }
            SettingsField("Bối cảnh cho AI", hint: "Vai trò của bạn, chủ đề buổi nói chuyện, muốn trả lời ra sao.") {
                TextEditor(text: $state.notes)
                    .font(.system(size: 12.5))
                    .scrollContentBackground(.hidden)
                    .frame(height: 52)
                    .fieldChrome()
            }
            SettingsField("Độ hiện cửa sổ", hint: nil) {
                HStack(spacing: 10) {
                    Slider(value: $state.opacity, in: 0.4...1)
                    Text("\(Int((state.opacity * 100).rounded()))%")
                        .font(.system(size: 11.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
            Hairline()
            HStack {
                TextAction(title: "Xoá hội thoại", color: Theme.textSecondary) {
                    state.clearConversation()
                    state.showSettings = false
                }
                Spacer()
                TextAction(title: "Thoát", color: Theme.danger) { NSApp.terminate(nil) }
            }
        }
        .padding(14)
    }
}

/// One secret per row, its name inside the field so both keys share one compact group.
private struct KeyField: View {
    let label: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, alignment: .leading)
            SecureField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, design: .monospaced))
        }
        .fieldChrome()
    }
}

private struct SettingsField<Content: View>: View {
    let title: String
    let hint: String?
    let content: Content

    init(_ title: String, hint: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            content
            if let hint {
                Text(hint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TextAction: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}
