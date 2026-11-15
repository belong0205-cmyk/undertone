import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var panel: OverlayPanel?

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
            panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 24, y: area.maxY - panel.frame.height - 24))
        }
        panel.setFrameAutosaveName(frameName)
        // state.opacity only fades the background blur and tint (see OverlayView); the window's own
        // alpha stays 1 so text and controls are never faded.
        panel.orderFrontRegardless()
        self.panel = panel

        Task { await state.startListening() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stopListening()
    }
}
