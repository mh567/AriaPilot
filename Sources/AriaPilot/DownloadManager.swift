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
    @Published private(set) var menuBarStatus: MenuBarStatus = .idle

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

    private var currentMenuBarStatus: MenuBarStatus {
        if !isConnected && error != nil {
            return .error
        }
        if stoppedDownloads.contains(where: { $0.isError }) {
            return .error
        }
        if activeDownloads.contains(where: { $0.isActive }) {
            return .downloading
        }
        if activeDownloads.contains(where: { $0.status == "paused" }) {
            return .paused
        }
        if activeDownloads.contains(where: { $0.status == "waiting" }) ||
            (globalStat?.waitingCount ?? 0) > 0 {
            return .waiting
        }
        return .idle
    }

    func startPolling(applySavedOptions: Bool = true) {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task {
            if hasSavedDownloadSettings && applySavedOptions {
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
            async let stat = c.getGlobalStat()

            activeDownloads = try await active + waiting
            let latestStat = try await stat
            let stopped = try await stoppedPage(total: latestStat.stoppedCount, loadedCount: loadedCount)
            stoppedDownloads = stopped
            hasMoreStopped = stopped.count < latestStat.stoppedCount
            globalStat = latestStat
            isConnected = true
            error = nil
            updateMenuBarStatus()
        } catch {
            isConnected = false
            self.error = error.localizedDescription
            updateMenuBarStatus()
        }
    }

    private func updateMenuBarStatus() {
        menuBarStatus = currentMenuBarStatus
    }

    func loadMoreStopped() async {
        guard !isLoadingMore, hasMoreStopped else { return }
        isLoadingMore = true
        do {
            let total = globalStat?.stoppedCount ?? stoppedDownloads.count
            let loadedCount = min(stoppedDownloads.count + pageSize, total)
            let page = try await stoppedPage(
                total: total,
                loadedCount: loadedCount
            )
            stoppedDownloads = page
            hasMoreStopped = stoppedDownloads.count < total
        } catch {
            self.error = error.localizedDescription
            updateMenuBarStatus()
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
            updateMenuBarStatus()
        }
    }

    func applyGlobalOptions() async {
        do {
            try await client.changeGlobalOption(globalOptions)
            error = nil
            await refresh()
        } catch {
            self.error = error.localizedDescription
            updateMenuBarStatus()
        }
    }

    func loadRemoteSettings(rpcURL: String, rpcSecret: String) async throws -> RemoteAria2Settings {
        let c = Aria2Client(rpcURL: rpcURL, secret: rpcSecret)
        async let options = c.getGlobalOption()
        async let active = c.tellActive()
        async let waiting = c.tellWaiting()
        let globalOptions = try await options
        let downloads = try await active + waiting

        let taskOptions = await firstTaskOptions(from: downloads, client: c)

        return RemoteAria2Settings(
            downloadDirectory: globalOptions.dir ?? "",
            maxConcurrentDownloads: positiveInt(
                globalOptions.maxConcurrentDownloads,
                fallback: maxConcurrentDownloads
            ),
            connectionsPerDownload: positiveInt(
                globalOptions.split ??
                    globalOptions.maxConnectionPerServer ??
                    taskOptions?.split ??
                    taskOptions?.maxConnectionPerServer,
                fallback: connectionsPerDownload
            ),
            downloadSpeedLimit: globalOptions.maxOverallDownloadLimit ?? "0",
            uploadSpeedLimit: globalOptions.maxOverallUploadLimit ?? "0"
        )
    }

    func pause(gid: String) async {
        do {
            try await client.pause(gid: gid)
            await refresh()
        } catch {
            self.error = error.localizedDescription
            updateMenuBarStatus()
        }
    }

    func unpause(gid: String) async {
        do {
            try await client.unpause(gid: gid)
            await refresh()
        } catch {
            self.error = error.localizedDescription
            updateMenuBarStatus()
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
                updateMenuBarStatus()
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
            updateMenuBarStatus()
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

    private func stoppedPage(total: Int, loadedCount: Int) async throws -> [Download] {
        guard total > 0 else { return [] }
        let count = min(loadedCount, total)
        return try await client.tellStopped(offset: -1, num: count)
    }

    private func positiveInt(_ value: String?, fallback: Int) -> Int {
        guard let value,
              let number = Int(value),
              number > 0 else {
            return fallback
        }
        return number
    }

    private func firstTaskOptions(
        from downloads: [Download],
        client: Aria2Client
    ) async -> Aria2Options? {
        for download in downloads {
            if let options = try? await client.getOption(gid: download.gid),
               options.split != nil || options.maxConnectionPerServer != nil {
                return options
            }
        }
        return nil
    }
}

enum MenuBarStatus: Hashable {
    case idle
    case downloading
    case waiting
    case paused
    case error
}

struct RemoteAria2Settings {
    let downloadDirectory: String
    let maxConcurrentDownloads: Int
    let connectionsPerDownload: Int
    let downloadSpeedLimit: String
    let uploadSpeedLimit: String
}
