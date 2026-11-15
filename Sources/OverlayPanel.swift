import AppKit

/// Floating, non-activating panel that is excluded from screenshots and screen sharing.
final class OverlayPanel: NSPanel {
    static let minimumSize = NSSize(width: 520, height: 380)

    init(contentView: NSView) {
        // Titled (not borderless) so the window server gives it resize edges; the title bar
        // itself is made invisible and the SwiftUI content runs underneath it.
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 440),
            styleMask: [.titled, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        self.contentView = contentView
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        appearance = NSAppearance(named: .darkAqua)
        contentMinSize = Self.minimumSize

        // The privacy requirement: the window server leaves this window out of screenshots,
        // screen recordings and screen-sharing streams (Zoom, Google Meet, ...).
        sharingType = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // NSHostingView rewrites the window's min size to 0x0 after its first layout, so every write
    // is clamped to `minimumSize`; setFrame is clamped too because it ignores min sizes.
    override var minSize: NSSize {
        get { super.minSize }
        set { super.minSize = Self.atLeastMinimum(newValue) }
    }

    override var contentMinSize: NSSize {
        get { super.contentMinSize }
        set { super.contentMinSize = Self.atLeastMinimum(newValue) }
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        let size = Self.atLeastMinimum(frameRect.size)
        // Keep the top-left corner where it was asked to be.
        super.setFrame(NSRect(x: frameRect.minX, y: frameRect.maxY - size.height,
                              width: size.width, height: size.height), display: flag)
    }

    private static func atLeastMinimum(_ size: NSSize) -> NSSize {
        NSSize(width: max(size.width, minimumSize.width), height: max(size.height, minimumSize.height))
    }

    /// The app has no visible menu bar, so route the standard editing shortcuts ourselves.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let action = Self.editAction(for: event.charactersIgnoringModifiers),
           NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private static func editAction(for key: String?) -> Selector? {
        switch key {
        case "x": #selector(NSText.cut(_:))
        case "c": #selector(NSText.copy(_:))
        case "v": #selector(NSText.paste(_:))
        case "a": #selector(NSText.selectAll(_:))
        case "z": Selector(("undo:"))
        default: nil
        }
    }
}
