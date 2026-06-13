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
    @AppStorage("downloadDirectory") var downloadDirectory = ""
    @AppStorage("maxConcurrentDownloads") var maxConcurrentDownloads = 5
    @AppStorage("connectionsPerDownload") var connectionsPerDownload = 5
    @AppStorage("downloadSpeedLimit") var downloadSpeedLimit = "0"
    @AppStorage("uploadSpeedLimit") var uploadSpeedLimit = "0"
    @AppStorage("hasSavedDownloadSettings") var hasSavedDownloadSettings = false

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
        Task {
            if hasSavedDownloadSettings {
                await applyGlobalOptions()
            } else {
                await refresh()
            }
        }
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
            try await client.addUri(url, options: defaultDownloadOptions)
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyGlobalOptions() async {
        do {
            try await client.changeGlobalOption(globalOptions)
            error = nil
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

    private var defaultDownloadOptions: [String: String] {
        var options: [String: String] = [
            "split": "\(connectionsPerDownload)",
            "max-connection-per-server": "\(connectionsPerDownload)"
        ]
        let dir = downloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dir.isEmpty {
            options["dir"] = dir
        }
        return options
    }

    private var globalOptions: [String: String] {
        [
            "max-concurrent-downloads": "\(maxConcurrentDownloads)",
            "max-overall-download-limit": normalizedSpeedLimit(downloadSpeedLimit),
            "max-overall-upload-limit": normalizedSpeedLimit(uploadSpeedLimit)
        ]
    }

    private func normalizedSpeedLimit(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "0" : trimmed
    }
}
