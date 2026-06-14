import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func open(manager: DownloadManager) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        var settingsWindow: NSWindow!
        let view = SettingsView {
            settingsWindow.close()
        }
        .environmentObject(manager)
        .frame(minWidth: 560, minHeight: 520)

        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "AriaPilot 设置"
        settingsWindow.minSize = NSSize(width: 560, height: 520)
        settingsWindow.contentViewController = NSHostingController(rootView: view)
        settingsWindow.delegate = self
        settingsWindow.isReleasedWhenClosed = false
        position(settingsWindow)

        self.window = settingsWindow
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func position(_ window: NSWindow) {
        let screen = currentScreen()
        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        frame.origin = NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.midY - frame.height / 2
        )
        window.setFrame(window.constrainFrameRect(frame, to: screen), display: false)
    }

    private func currentScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first!
    }
}
