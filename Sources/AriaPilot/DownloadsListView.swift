import SwiftUI

enum DownloadsTab {
    case downloading, completed
}

struct DownloadsListView: View {
    @EnvironmentObject var manager: DownloadManager
    @Binding var tab: DownloadsTab

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("下载中", count: manager.activeDownloads.count, tab: .downloading)
            tabButton("已完成", count: completedCount, tab: .completed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func tabButton(_ title: String, count: Int, tab target: DownloadsTab) -> some View {
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
                Text("暂无下载任务")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
        }
    }

    private var completedList: some View {
        Group {
            if manager.stoppedDownloads.isEmpty {
                VStack(spacing: 4) {
                    Text("暂无已完成任务")
                    if manager.isConnected {
                        Text("aria2 当前未保留历史记录")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(manager.stoppedDownloads) { dl in
                                DownloadRowView(download: dl)
                                    .environmentObject(manager)
                                Divider().padding(.horizontal, 8)
                            }
                            if manager.hasMoreStopped {
                                loadMoreButton
                            }
                        }
                    }
                    Divider()
                    clearHistoryButton
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var completedCount: Int {
        manager.globalStat?.stoppedCount ?? manager.stoppedDownloads.count
    }

    private var clearHistoryButton: some View {
        Button(role: .destructive) {
            Task { await manager.clearHistory() }
        } label: {
            Text("清空全部")
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
                Text("加载更多")
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
        }
        .buttonStyle(.borderless)
    }
}
