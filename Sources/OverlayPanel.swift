import AppKit

/// Floating, non-activating panel that is excluded from screenshots and screen sharing.
final class OverlayPanel: NSPanel {
    static let minimumSize = NSSize(width: 520, height: 380)
    /// First-launch size, used when no saved frame exists.
    static let defaultSize = NSSize(width: 680, height: 880)

    init(contentView: NSView) {
        // Not `.resizable`: the system resize edges show resize cursors, which screen sharing captures
        // over "nothing". Edge drags are handled in `sendEvent` instead. The title bar is invisible and
        // the SwiftUI content runs underneath it.
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
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
        // Screen sharing does capture the cursor, so it must never change shape over the panel.
        disableCursorRects()
    }

    // MARK: - Arrow-only cursor and edge resizing

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .cursorUpdate:
            // Text fields (I-beam), selectable text and the like ask for their cursor here; everything
            // gets the arrow.
            NSCursor.arrow.set()
        case .leftMouseDown where !resizeEdges(at: event.locationInWindow).isEmpty:
            trackResize(resizeEdges(at: event.locationInWindow))
        default:
            // Arrow before the views see the event too, so no frame ever shows another cursor.
            if event.type == .mouseMoved || event.type == .mouseEntered { NSCursor.arrow.set() }
            super.sendEvent(event)
            // The field editor of a focused text field sets the I-beam itself on mouse up, bypassing
            // cursorUpdate; put the arrow straight back.
            if NSCursor.current !== NSCursor.arrow { NSCursor.arrow.set() }
        }
    }

    private struct Edges: OptionSet {
        let rawValue: Int
        static let left = Edges(rawValue: 1)
        static let right = Edges(rawValue: 2)
        static let bottom = Edges(rawValue: 4)
        static let top = Edges(rawValue: 8)
    }

    /// Edges grabbed by a click this close to the border; near a corner the click grabs both edges.
    private func resizeEdges(at point: NSPoint) -> Edges {
        // The top bar's buttons sit 5pt below the top edge and 14pt in from the sides, so the top band
        // and the corner zones stay clear of them.
        let band: CGFloat = 4
        let topBand: CGFloat = 3
        let corner: CGFloat = 12
        let size = frame.size
        var edges: Edges = []
        if point.x < band { edges.insert(.left) } else if point.x > size.width - band { edges.insert(.right) }
        if point.y < band { edges.insert(.bottom) } else if point.y > size.height - topBand { edges.insert(.top) }
        guard !edges.isEmpty else { return [] }
        if point.x < corner { edges.insert(.left) } else if point.x > size.width - corner { edges.insert(.right) }
        if point.y < corner { edges.insert(.bottom) } else if point.y > size.height - topBand - 5 { edges.insert(.top) }
        return edges
    }

    /// Follows the drag until mouse up; the edges that were not grabbed stay where they are.
    private func trackResize(_ edges: Edges) {
        let start = frame
        let grab = NSEvent.mouseLocation
        while let event = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), event.type == .leftMouseDragged {
            let mouse = NSEvent.mouseLocation
            var size = start.size
            if edges.contains(.left) { size.width -= mouse.x - grab.x }
            if edges.contains(.right) { size.width += mouse.x - grab.x }
            if edges.contains(.bottom) { size.height -= mouse.y - grab.y }
            if edges.contains(.top) { size.height += mouse.y - grab.y }
            size = Self.atLeastMinimum(size)
            let x = edges.contains(.left) ? start.maxX - size.width : start.minX
            let y = edges.contains(.bottom) ? start.maxY - size.height : start.minY
            setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        }
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
