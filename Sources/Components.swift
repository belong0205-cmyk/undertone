import AppKit
import SwiftUI

/// Design tokens. The panel is always dark so it reads the same over any app.
enum Theme {
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.36)
    static let hairline = Color.white.opacity(0.08)
    static let field = Color.black.opacity(0.28)
    static let tint = Color(red: 0.12, green: 0.12, blue: 0.11)   // neutral dark, laid over the blur
    static let card = Color(red: 0.17, green: 0.17, blue: 0.16)   // settings card
    static let accent = Color(red: 0.30, green: 0.78, blue: 0.47) // #4DC778, the one signal colour: live / newest
    static let danger = Color(red: 1.00, green: 0.42, blue: 0.40)
    static let warning = Color(red: 1.00, green: 0.72, blue: 0.35)

    // Timeline and answer cards
    static let timeline = Color.white.opacity(0.12)
    static let dot = Color.white.opacity(0.30)
    static let answerFill = Color.black.opacity(0.22)
    static let answerStroke = Color.white.opacity(0.08)

    static let radius: CGFloat = 16      // matches the system window corner radius
    static let pad: CGFloat = 14
    static let gutter: CGFloat = 28      // timeline column at the left edge
    static let afterGutter: CGFloat = 6  // gap between the timeline and the Vietnamese column

    static let bodySize: CGFloat = 13
    static let answerSize: CGFloat = 13.5
    static let body = Font.system(size: bodySize)
    static let answer = Font.system(size: answerSize)
    static let label = Font.system(size: 10, weight: .semibold)

    /// UserDefaults key and range of the "Cỡ chữ" setting (conversation text only).
    static let textScaleKey = "textScale"
    static let textScaleRange: ClosedRange<Double> = 0.8...1.6

    /// "Độ đậm nền": alpha of both the blur and the dark tint over it. 0 = see-through, 1 = solid dark.
    /// Text and controls are never faded.
    static let backgroundRange: ClosedRange<Double> = 0...1
    /// Smallest tint alpha actually drawn: fully clear pixels let clicks fall through the panel,
    /// so it could no longer be dragged or scrolled at 0%. Invisible at this level.
    static let minTint = 0.04
    /// Below this tint, text gets a soft shadow to stay readable over bright content behind the panel.
    static let shadowBelow = 0.6
}

private struct TextScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1
}

extension EnvironmentValues {
    /// Multiplier for conversation text (utterance, translation, suggested answer); chrome ignores it.
    var textScale: Double {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

/// Small uppercase label used for column titles and answer captions.
struct Caption: View {
    let text: String
    var color: Color = Theme.textTertiary

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label)
            .tracking(0.9)
            .foregroundStyle(color)
    }
}

/// Two equal columns whose cells stretch to the taller one, so rows line up across languages.
struct Columns<Left: View, Right: View>: View {
    private let leading: CGFloat
    private let left: Left
    private let right: Right

    init(leading: CGFloat = Theme.pad, @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.leading = leading
        self.left = left()
        self.right = right()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            left
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, leading)
                .padding(.trailing, Theme.pad)
            right
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, Theme.pad)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Three softly pulsing dots: "text is on its way".
struct PendingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.textSecondary)
                        .frame(width: 4, height: 4)
                        .opacity(0.25 + 0.75 * max(0, sin(t * 5 - Double(i) * 0.9)))
                }
            }
            .frame(height: 17)
        }
        .accessibilityLabel("Đang xử lý")
    }
}

struct IconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(hovering ? Theme.textPrimary : Theme.textSecondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(hovering ? Color.white.opacity(0.08) : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
    }
}

extension View {
    /// Dark inset field look for text inputs. TextEditor already insets its text by ~5pt,
    /// so pass a smaller `horizontal` there to line its text up with single-line fields.
    func fieldChrome(horizontal: CGFloat = 9) -> some View {
        padding(.horizontal, horizontal)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline))
    }
}

/// Renders an answer: inline markdown (bold, italic, code) and "- " bullets with a hanging indent.
struct AnswerText: View {
    let text: String
    @Environment(\.textScale) private var textScale

    private struct Line {
        let isBullet: Bool
        let content: AttributedString
    }

    private var lines: [Line] {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return text.components(separatedBy: "\n").compactMap { raw in
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            let marker = line.range(of: #"^[-*•]\s+"#, options: .regularExpression)
            if let marker { line.removeSubrange(marker) }
            let content = (try? AttributedString(markdown: line, options: options)) ?? AttributedString(line)
            return Line(isBullet: marker != nil, content: content)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.isBullet {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("•").foregroundStyle(Theme.accent)
                        Text(line.content)
                    }
                } else {
                    Text(line.content)
                }
            }
        }
        .font(.system(size: Theme.answerSize * textScale))
        .foregroundStyle(Theme.textPrimary)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }
}

// MARK: - AppKit bridges

struct VisualEffectBackground: NSViewRepresentable {
    /// Strength of the blur: 0 shows the backdrop sharp, 1 is the full frosted material.
    var opacity: Double = 1

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = opacity
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.alphaValue = opacity
    }
}

/// Lets the borderless panel be dragged from the top bar.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Hand-off from the app delegate (a double-clicked profile file) to the SwiftUI pages: the delegate
/// posts a notice, the panel opens the Hồ sơ page and shows it.
@MainActor
final class ProfileInbox: ObservableObject {
    static let shared = ProfileInbox()
    /// Bumped on every post, so the same text twice still triggers `onChange`.
    @Published private(set) var postCount = 0
    var notice: ImportResult?

    func post(_ notice: ImportResult) {
        self.notice = notice
        postCount += 1
    }
}
