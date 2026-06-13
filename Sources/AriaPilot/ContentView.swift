import SwiftUI

enum Page {
    case main, add
}

struct ContentView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var page: Page = .main
    @State private var tab: DownloadsTab = .downloading

    var body: some View {
        VStack(spacing: 0) {
            switch page {
            case .main:
                mainView
            case .add:
                AddDownloadView(page: $page)
                    .environmentObject(manager)
            }
        }
        .frame(width: 420)
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if let error = manager.error {
                errorBanner(error)
                Divider()
            }
            DownloadsListView(tab: $tab)
                .environmentObject(manager)
                .frame(height: 320)
            Divider()
            bottomBar
        }
    }

    private var headerBar: some View {
        HStack {
            Circle()
                .fill(manager.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            if let stat = manager.globalStat {
                Image(systemName: "arrow.down")
                    .foregroundStyle(.secondary)
                    .font(.caption2)
                Text(Fmt.speed(stat.dlSpeed))
                    .font(.caption)
                    .monospacedDigit()
                Image(systemName: "arrow.up")
                    .foregroundStyle(.secondary)
                    .font(.caption2)
                Text(Fmt.speed(stat.ulSpeed))
                    .font(.caption)
                    .monospacedDigit()
            } else {
                Text("未连接")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer()
        }
        .font(.caption2)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.08))
    }

    private var bottomBar: some View {
        HStack {
            Button { page = .add } label: {
                Label("添加", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            Spacer()
            Button {
                let menuWindow = NSApp.keyWindow
                DownloadsWindowController.shared.open(manager: manager)
                menuWindow?.close()
            } label: {
                Label("打开窗口", systemImage: "macwindow")
            }
            .buttonStyle(.borderless)
            Button {
                let menuWindow = NSApp.keyWindow
                SettingsWindowController.shared.open(manager: manager)
                menuWindow?.close()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
