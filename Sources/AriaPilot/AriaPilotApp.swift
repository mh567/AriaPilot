import AppKit
import SwiftUI

@main
struct AriaPilotApp: App {
    @StateObject private var manager: DownloadManager

    init() {
        let manager = DownloadManager()
        manager.startPolling()
        _manager = StateObject(wrappedValue: manager)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(manager)
        } label: {
            MenuBarStatusIcon(status: manager.menuBarStatus)
                .id(manager.menuBarStatus)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarStatusIcon: View {
    let status: MenuBarStatus

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.image(for: status))
            .renderingMode(.template)
            .frame(width: 20, height: 20)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch status {
        case .idle:
            return "AriaPilot 空闲"
        case .downloading:
            return "AriaPilot 下载中"
        case .waiting:
            return "AriaPilot 等待中"
        case .paused:
            return "AriaPilot 已暂停"
        case .error:
            return "AriaPilot 有错误"
        }
    }
}

enum MenuBarIconRenderer {
    static func image(for status: MenuBarStatus) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        drawSymbol(
            "arrow.down.circle",
            pointSize: 18,
            weight: .semibold,
            in: NSRect(x: 2, y: 2, width: 18, height: 18)
        )

        switch status {
        case .idle:
            break
        case .downloading:
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 15, y: 1, width: 7, height: 7)).fill()
        case .waiting:
            NSColor.black.setStroke()
            let badge = NSBezierPath(ovalIn: NSRect(x: 15, y: 1, width: 7, height: 7))
            badge.lineWidth = 1.7
            badge.stroke()
        case .paused:
            drawSymbol(
                "pause.circle.fill",
                pointSize: 10,
                weight: .bold,
                in: NSRect(x: 13, y: 0, width: 10, height: 10)
            )
        case .error:
            drawSymbol(
                "exclamationmark.circle.fill",
                pointSize: 10,
                weight: .bold,
                in: NSRect(x: 13, y: 12, width: 10, height: 10)
            )
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawSymbol(
        _ name: String,
        pointSize: CGFloat,
        weight: NSFont.Weight,
        in rect: NSRect
    ) {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        guard let symbol = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config) else {
            return
        }
        symbol.draw(in: rect)
    }
}
