import SwiftUI

struct DownloadsWindowView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var tab: DownloadsTab = .downloading
    @State private var page: Page = .main

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if let error = manager.error {
                errorBanner(error)
                Divider()
            }
            if page == .add {
                AddDownloadView(page: $page)
                    .environmentObject(manager)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DownloadsListView(tab: $tab)
                    .environmentObject(manager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.08))
    }

    private var bottomBar: some View {
        HStack {
            Button {
                page = page == .add ? .main : .add
            } label: {
                Label(page == .add ? "返回" : "添加", systemImage: page == .add ? "chevron.left" : "plus")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button {
                SettingsWindowController.shared.open(manager: manager)
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
