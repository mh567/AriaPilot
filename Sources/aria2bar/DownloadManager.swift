import Foundation
import SwiftUI

@MainActor
class DownloadManager: ObservableObject {
    @Published var activeDownloads: [Download] = []
    @Published var stoppedDownloads: [Download] = []
    @Published var globalStat: GlobalStat?
    @Published var isConnected = false
    @Published var error: String?
    @Published var hasMoreStopped = false
    @Published var isLoadingMore = false

    @AppStorage("rpcURL") var rpcURL = "http://localhost:6800/jsonrpc"
    @AppStorage("rpcSecret") var rpcSecret = ""

    private var timer: Timer?
    private let pageSize = 10

    var client: Aria2Client {
        Aria2Client(rpcURL: rpcURL, secret: rpcSecret)
    }

    func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task { await refresh() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        do {
            let c = client
            let loadedCount = max(stoppedDownloads.count, pageSize)
            async let active = c.tellActive()
            async let waiting = c.tellWaiting()
            async let stopped = c.tellStopped(offset: 0, num: loadedCount)
            async let stat = c.getGlobalStat()

            activeDownloads = try await active + waiting
            let page = try await stopped
            stoppedDownloads = page
            hasMoreStopped = page.count >= loadedCount
            globalStat = try await stat
            isConnected = true
            error = nil
        } catch {
            isConnected = false
            self.error = error.localizedDescription
        }
    }

    func loadMoreStopped() async {
        guard !isLoadingMore, hasMoreStopped else { return }
        isLoadingMore = true
        do {
            let page = try await client.tellStopped(
                offset: stoppedDownloads.count,
                num: pageSize
            )
            stoppedDownloads.append(contentsOf: page)
            hasMoreStopped = page.count >= pageSize
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMore = false
    }

    // MARK: - Actions

    func addDownload(url: String) async {
        do {
            try await client.addUri(url)
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func pause(gid: String) async {
        do {
            try await client.pause(gid: gid)
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unpause(gid: String) async {
        do {
            try await client.unpause(gid: gid)
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func remove(gid: String) async {
        do {
            try await client.remove(gid: gid)
            await refresh()
        } catch {
            do {
                try await client.removeResult(gid: gid)
                await refresh()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func clearHistory() async {
        do {
            try await client.purgeDownloadResult()
            stoppedDownloads = []
            hasMoreStopped = false
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}