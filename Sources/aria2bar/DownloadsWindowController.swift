import AppKit
import SwiftUI

@MainActor
final class DownloadsWindowController: NSObject, NSWindowDelegate {
    static let shared = DownloadsWindowController()

    private var window: NSWindow?

    func open(manager: DownloadManager) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = DownloadsWindowView()
            .environmentObject(manager)
            .frame(minWidth: 520, minHeight: 360)

        let downloadsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        downloadsWindow.title = "aria2bar 下载任务"
        downloadsWindow.contentViewController = NSHostingController(rootView: view)
        downloadsWindow.delegate = self
        downloadsWindow.isReleasedWhenClosed = false
        downloadsWindow.minSize = NSSize(width: 520, height: 360)
        position(downloadsWindow)

        self.window = downloadsWindow
        downloadsWindow.makeKeyAndOrderFront(nil)
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
