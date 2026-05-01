import SwiftUI

enum Page {
    case main, add, settings
}

enum Tab {
    case downloading, completed
}

struct ContentView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var page: Page = .main
    @State private var tab: Tab = .downloading

    var body: some View {
        VStack(spacing: 0) {
            switch page {
            case .main:
                mainView
            case .add:
                AddDownloadView(page: $page)
                    .environmentObject(manager)
            case .settings:
                SettingsView(page: $page)
                    .environmentObject(manager)
            }
        }
        .frame(width: 360)
        .onAppear { manager.startPolling() }
        .onDisappear { manager.stopPolling() }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            tabBar
            Divider()
            tabContent
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
                Text("Disconnected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Downloading", count: manager.activeDownloads.count, tab: .downloading)
            tabButton("Completed", count: manager.stoppedDownloads.count, tab: .completed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func tabButton(_ title: String, count: Int, tab target: Tab) -> some View {
        Button {
            tab = target
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Text("\(count)")
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .font(.caption)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(tab == target ? Color.accentColor.opacity(0.15) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
    }

    private var tabContent: some View {
        Group {
            switch tab {
            case .downloading:
                downloadingList
            case .completed:
                completedList
            }
        }
    }

    private var downloadingList: some View {
        Group {
            if manager.activeDownloads.isEmpty {
                Text("No active downloads")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(manager.activeDownloads) { dl in
                            DownloadRowView(download: dl)
                                .environmentObject(manager)
                            Divider().padding(.horizontal, 8)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private var completedList: some View {
        Group {
            if manager.stoppedDownloads.isEmpty {
                Text("No completed downloads")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(sortedStopped) { dl in
                                DownloadRowView(download: dl)
                                    .environmentObject(manager)
                                Divider().padding(.horizontal, 8)
                            }
                            if manager.hasMoreStopped {
                                loadMoreButton
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    Divider()
                    clearHistoryButton
                }
            }
        }
    }

    private var sortedStopped: [Download] {
        manager.stoppedDownloads.sorted { lhs, rhs in lhs.gid > rhs.gid }
    }

    private var clearHistoryButton: some View {
        Button(role: .destructive) {
            Task { await manager.clearHistory() }
        } label: {
            Text("Clear All")
                .font(.caption)
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderless)
    }

    private var loadMoreButton: some View {
        Button {
            Task { await manager.loadMoreStopped() }
        } label: {
            if manager.isLoadingMore {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 30)
            } else {
                Text("Load More")
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
        }
        .buttonStyle(.borderless)
    }

    private var bottomBar: some View {
        HStack {
            Button { page = .add } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            Spacer()
            if let err = manager.error {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            Button { page = .settings } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
