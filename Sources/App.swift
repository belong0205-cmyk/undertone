import AppKit
import Carbon.HIToolbox
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var panel: OverlayPanel?
    private var hotKey: HotKey?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // no Dock icon, not in ⌘-Tab
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: OverlayView().environmentObject(state))
        host.sizingOptions = [] // the panel's own minSize governs; wrapped text would otherwise inflate it
        let panel = OverlayPanel(contentView: host)

        let frameName = "UndertoneOverlay"
        if !panel.setFrameUsingName(frameName), let screen = NSScreen.main {
            let area = screen.visibleFrame
            // Keep the whole default panel on screen: clamp the height, then anchor top-right.
            let height = min(panel.frame.height, area.height - 48)
            panel.setContentSize(NSSize(width: panel.frame.width, height: max(height, OverlayPanel.minimumSize.height)))
            panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 24, y: area.maxY - panel.frame.height - 24))
        }
        panel.setFrameAutosaveName(frameName)
        // state.opacity only fades the background blur and tint (see OverlayView); the window's own
        // alpha stays 1 so text and controls are never faded.
        panel.orderFrontRegardless()
        self.panel = panel
        // Cmd+Shift+Z shows or hides the panel from any app. Hiding only removes the window: listening continues.
        hotKey = HotKey(keyCode: kVK_ANSI_Z, modifiers: cmdKey | shiftKey) { [weak panel] in
            guard let panel else { return }
            if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        }

        Task { await state.startListening() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stopListening()
    }
}
