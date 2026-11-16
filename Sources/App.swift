import AppKit
import Carbon.HIToolbox
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var panel: OverlayPanel?
    private var hotKey: HotKey?
    /// Files opened before the panel exists (a cold launch by double-click).
    private var pendingFiles: [URL] = []

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

        openProfileFiles(pendingFiles)
        pendingFiles = []
        Task { await state.startListening() }
    }

    /// Double-clicking a .undertone-profile (or .json) file imports it and shows it on the Hồ sơ page.
    func application(_ application: NSApplication, open urls: [URL]) {
        if panel == nil { pendingFiles += urls } else { openProfileFiles(urls) }
    }

    private func openProfileFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            do {
                let id = try state.importProfile(fromFile: url)
                state.activeProfileID = id
                let name = state.profiles.first { $0.id == id }?.displayName ?? ""
                ProfileInbox.shared.post(.info("Đã nhập hồ sơ \(name)"))
            } catch {
                ProfileInbox.shared.post(.failed(error.localizedDescription))
            }
        }
        panel?.orderFrontRegardless()
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stopListening()
    }
}
