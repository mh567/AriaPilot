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
    @AppStorage("connectionMode") var connectionMode = ConnectionMode.remote.rawValue
    @AppStorage("remoteRPCURL") var remoteRPCURL = ""
    @AppStorage("remoteRPCSecret") var remoteRPCSecret = ""
    @AppStorage("remoteDownloadDirectory") var remoteDownloadDirectory = ""

    private var timer: Timer?
    private let pageSize = 10
    private var persistedStoppedDownloads: [Download] = []

    init() {
        persistedStoppedDownloads = Self.loadDownloadHistory()
        stoppedDownloads = persistedStoppedDownloads
    }

    var client: Aria2Client {
        Aria2Client(rpcURL: rpcURL, secret: rpcSecret)
    }

    var savedRemoteRPCURL: String {
        if !remoteRPCURL.isEmpty {
            return remoteRPCURL
        }
        return Self.isLocalRPCURL(rpcURL) ? "" : rpcURL
    }

    var savedRemoteRPCSecret: String {
        remoteRPCSecret.isEmpty && !Self.isLocalRPCURL(rpcURL) ? rpcSecret : remoteRPCSecret
    }

    var savedRemoteDownloadDirectory: String {
        remoteDownloadDirectory.isEmpty && !Self.isLocalRPCURL(rpcURL) ? downloadDirectory : remoteDownloadDirectory
    }

    func saveRemoteConnection(rpcURL: String, rpcSecret: String, downloadDirectory: String) {
        remoteRPCURL = rpcURL
        remoteRPCSecret = rpcSecret
        remoteDownloadDirectory = downloadDirectory
        self.rpcURL = rpcURL
        self.rpcSecret = rpcSecret
        self.downloadDirectory = downloadDirectory
        connectionMode = ConnectionMode.remote.rawValue
    }

    func migrateLegacyRemoteConnectionIfNeeded() {
        guard remoteRPCURL.isEmpty, !Self.isLocalRPCURL(rpcURL) else { return }
        remoteRPCURL = rpcURL
        remoteRPCSecret = rpcSecret
        remoteDownloadDirectory = downloadDirectory
    }

    func preserveRemoteConnectionIfNeeded(
        rpcURL: String,
        rpcSecret: String,
        downloadDirectory: String
    ) {
        let trimmedURL = rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !Self.isLocalRPCURL(trimmedURL) else { return }
        remoteRPCURL = trimmedURL
        remoteRPCSecret = rpcSecret
        remoteDownloadDirectory = downloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isLocalRPCURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
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
            mergeStoppedDownloads(stopped)
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
            mergeStoppedDownloads(page)
            hasMoreStopped = page.count < total
        } catch {
            self.error = error.localizedDescription
            updateMenuBarStatus()
        }
        isLoadingMore = false
    }

    // MARK: - Actions

    @discardableResult
    func addDownload(url: String) async -> Bool {
        do {
            try await prepareConnectionForUserAction()
            try await client.addUri(url, options: defaultDownloadOptions)
            await refresh()
            updateMenuBarStatus()
            return isConnected && error == nil
        } catch {
            self.error = error.localizedDescription
            updateMenuBarStatus()
            return false
        }
    }

    private func prepareConnectionForUserAction() async throws {
        guard ConnectionMode(rawValue: connectionMode) == .local else { return }
        let localService = LocalAria2ServiceManager()
        rpcURL = localService.rpcURL
        rpcSecret = localService.savedSecret
        if downloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            downloadDirectory = localService.savedDownloadDirectory
        }
        if isConnected { return }
        await localService.start()
        if case .running = localService.status {
            return
        }
        throw LocalAria2ServiceError(localService.message ?? "本机下载服务尚未就绪，请先在设置中安装或启动服务。")
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

    func remove(download: Download, deleteFiles: Bool) async {
        do {
            try await removeTaskIfPresent(download.gid)
            if deleteFiles {
                try deleteDownloadedFiles(for: download)
            }
            removeFromHistory(gid: download.gid)
            await refresh()
        } catch {
            self.error = error.localizedDescription
            updateMenuBarStatus()
        }
    }

    func clearHistory() async {
        try? await client.purgeDownloadResult()
        persistedStoppedDownloads = []
        saveDownloadHistory()
        stoppedDownloads = []
        hasMoreStopped = false
        await refresh()
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

    private func mergeStoppedDownloads(_ downloads: [Download]) {
        let durable = downloads.filter { $0.isComplete || $0.isError }
        var byID = Dictionary(uniqueKeysWithValues: persistedStoppedDownloads.map { ($0.gid, $0) })
        for download in durable {
            byID[download.gid] = download
        }
        persistedStoppedDownloads = Array(byID.values)
            .sorted { $0.gid > $1.gid }
        saveDownloadHistory()
        stoppedDownloads = mergedStoppedDownloads(live: downloads, history: persistedStoppedDownloads)
    }

    private func mergedStoppedDownloads(live: [Download], history: [Download]) -> [Download] {
        var seen = Set<String>()
        var result: [Download] = []
        for download in live + history where seen.insert(download.gid).inserted {
            result.append(download)
        }
        return result
    }

    private func removeTask(_ gid: String) async throws {
        do {
            try await client.remove(gid: gid)
        } catch {
            try await client.removeResult(gid: gid)
        }
    }

    private func removeTaskIfPresent(_ gid: String) async throws {
        do {
            try await removeTask(gid)
        } catch {
            if isMissingTaskError(error) {
                return
            }
            throw error
        }
    }

    private func deleteDownloadedFiles(for download: Download) throws {
        let paths = Set(
            (download.files ?? [])
                .compactMap { $0.localPath }
                .filter { !$0.isEmpty }
        )
        guard !paths.isEmpty else { return }

        var failures: [String] = []
        for path in paths.sorted() {
            let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            } catch {
                failures.append("\((url.path as NSString).lastPathComponent)：\(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            throw LocalAria2ServiceError("任务已删除，但部分文件删除失败：\(failures.joined(separator: "；"))")
        }
    }

    private func removeFromHistory(gid: String) {
        persistedStoppedDownloads.removeAll { $0.gid == gid }
        stoppedDownloads.removeAll { $0.gid == gid }
        saveDownloadHistory()
    }

    private func isMissingTaskError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("not found") ||
            message.contains("notfound") ||
            message.contains("no such") ||
            message.contains("unknown")
    }

    private func saveDownloadHistory() {
        do {
            let url = Self.downloadHistoryURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(persistedStoppedDownloads)
            try data.write(to: url, options: .atomic)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func loadDownloadHistory() -> [Download] {
        do {
            let data = try Data(contentsOf: downloadHistoryURL)
            return try JSONDecoder().decode([Download].self, from: data)
        } catch {
            return []
        }
    }

    private static var downloadHistoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AriaPilot", isDirectory: true)
            .appendingPathComponent("download-history.json")
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

enum DeleteActionPreference: String, CaseIterable, Identifiable {
    case ask
    case taskOnly
    case taskAndFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask:
            return "每次询问"
        case .taskOnly:
            return "只删除任务"
        case .taskAndFiles:
            return "同时删除文件"
        }
    }
}

struct RemoteAria2Settings {
    let downloadDirectory: String
    let maxConcurrentDownloads: Int
    let connectionsPerDownload: Int
    let downloadSpeedLimit: String
    let uploadSpeedLimit: String
}
