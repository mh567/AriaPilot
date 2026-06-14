import AppKit
import Foundation

enum ConnectionMode: String, CaseIterable, Identifiable {
    case local
    case remote

    var id: String { rawValue }
}

enum LocalAria2ServiceStatus {
    case missingBinary
    case externalService(String)
    case notInstalled
    case stopped
    case running
    case unhealthy(String)
    case failed(String)

    var title: String {
        switch self {
        case .missingBinary:
            return "内置 aria2 缺失"
        case .externalService:
            return "已有本机服务"
        case .notInstalled:
            return "未安装"
        case .stopped:
            return "已停止"
        case .running:
            return "运行中"
        case .unhealthy:
            return "异常"
        case .failed:
            return "异常"
        }
    }
}

enum LocalAria2ServiceAction {
    case idle
    case checking
    case installing
    case starting
    case restarting
    case stopping
    case uninstalling

    var statusTitle: String? {
        switch self {
        case .idle:
            return nil
        case .checking:
            return "正在检测"
        case .installing:
            return "正在安装"
        case .starting:
            return "正在启动"
        case .restarting:
            return "正在重启"
        case .stopping:
            return "正在停止"
        case .uninstalling:
            return "正在卸载"
        }
    }
}

@MainActor
final class LocalAria2ServiceManager: ObservableObject {
    @Published private(set) var status: LocalAria2ServiceStatus = .notInstalled
    @Published private(set) var version = ""
    @Published private(set) var message: String?
    @Published private(set) var action: LocalAria2ServiceAction = .idle

    let rpcURL = "http://localhost:6800/jsonrpc"
    let defaultPort = 6800

    private let label = "com.ariapilot.aria2"
    private let userDefaults = UserDefaults.standard
    private var cachedBundledVersion: String?

    var defaultDownloadDirectory: String {
        downloadsDirectory.appendingPathComponent("AriaPilot", isDirectory: true).path
    }

    var savedSecret: String {
        let key = "localAria2RPCSecret"
        if let secret = userDefaults.string(forKey: key), !secret.isEmpty {
            return secret
        }
        let secret = Self.makeSecret()
        userDefaults.set(secret, forKey: key)
        return secret
    }

    var savedDownloadDirectory: String {
        let key = "localAria2DownloadDirectory"
        if let path = userDefaults.string(forKey: key), !path.isEmpty {
            return path
        }
        let path = defaultDownloadDirectory
        userDefaults.set(path, forKey: key)
        return path
    }

    func setDownloadDirectory(_ path: String) {
        userDefaults.set(path, forKey: "localAria2DownloadDirectory")
    }

    func refresh() async {
        await perform(.checking) {
            await self.refreshStatus()
        }
    }

    func installAndStart(downloadDirectory: String) async {
        await perform(.installing) {
            let secret = self.savedSecret
            let hasLaunchAgent = FileManager.default.fileExists(atPath: self.launchAgentURL.path)
            let isLoaded = await self.isLaunchdLoaded()
            if hasLaunchAgent || isLoaded {
                await self.refreshStatus()
                self.message = "本机下载服务已安装。需要应用新配置时请使用“重启”。"
                return
            }
            try await self.ensurePortAvailableForManagedService(secret: secret)
            try self.prepareFiles(downloadDirectory: downloadDirectory, secret: secret)
            try await self.bootstrapAndKickstart()
            await self.waitForRPCReady(secret: secret)
            await self.refreshStatus()
        }
    }

    func start() async {
        await perform(.starting) {
            let secret = self.savedSecret
            guard FileManager.default.fileExists(atPath: self.launchAgentURL.path) else {
                self.status = .notInstalled
                self.message = "本机下载服务尚未安装。"
                return
            }
            try await self.ensurePortAvailableForManagedService(secret: secret)
            let launchdStatus = await self.launchdStatus()
            if !launchdStatus.loaded {
                try await self.requireLaunchctlSuccess(["bootstrap", self.guiDomain, self.launchAgentURL.path])
                try await self.waitForLaunchdLoaded()
            }
            try await self.requireLaunchctlSuccess(["kickstart", "-k", self.serviceTarget])
            await self.waitForRPCReady(secret: secret)
            await self.refreshStatus()
        }
    }

    func restart(downloadDirectory: String) async {
        await perform(.restarting) {
            let secret = self.savedSecret
            guard FileManager.default.fileExists(atPath: self.launchAgentURL.path) else {
                self.status = .notInstalled
                self.message = "本机下载服务尚未安装。请先安装服务。"
                return
            }
            if await self.isLaunchdLoaded() {
                try await self.unloadManagedService()
            }
            try await self.ensurePortAvailableForManagedService(secret: secret)
            try self.prepareFiles(downloadDirectory: downloadDirectory, secret: secret)
            try await self.bootstrapAndKickstart()
            await self.waitForRPCReady(secret: secret)
            await self.refreshStatus()
        }
    }

    func stop() async {
        await perform(.stopping) {
            if await self.isLaunchdLoaded() {
                try await self.unloadManagedService()
            }
            try self.rewriteLaunchAgentIfInstalled()
            await self.refreshStatus()
        }
    }

    func uninstall() async {
        await perform(.uninstalling) {
            if await self.isLaunchdLoaded() {
                try await self.unloadManagedService()
            }
            if FileManager.default.fileExists(atPath: self.launchAgentURL.path) {
                try FileManager.default.removeItem(at: self.launchAgentURL)
            }
            if await self.isLaunchdLoaded() {
                throw LocalAria2ServiceError("卸载后 launchd 任务仍在运行，请稍后重试或手动检查 LaunchAgent。")
            }
            await self.refreshStatus()
        }
    }

    private func refreshStatus() async {
        guard bundledBinaryURL != nil else {
            status = .missingBinary
            version = ""
            message = "当前应用包没有包含 aria2c。请先通过更新 workflow 或发布包补齐内置后端。"
            return
        }

        version = await readBundledVersion()
        let hasLaunchAgent = FileManager.default.fileExists(atPath: launchAgentURL.path)
        let launchdStatus = await launchdStatus()
        let localProbe = await probeLocalRPC(secret: savedSecret)
        if !hasLaunchAgent {
            if launchdStatus.loaded {
                status = .unhealthy("本机服务仍在运行，但 LaunchAgent 文件已缺失。请尝试卸载服务后重新安装。")
                message = "本机服务仍在运行，但 LaunchAgent 文件已缺失。请尝试卸载服务后重新安装。"
                return
            }
            if localProbe.isAria2 {
                let text = "检测到已有 aria2 正在使用本机 6800 端口。可以在远程模式里填写 localhost 地址使用现有服务；安装内置服务前需要先停止现有服务。"
                status = .externalService(text)
                message = text
                return
            }
            status = .notInstalled
            message = nil
            return
        }

        guard launchdStatus.loaded && launchdStatus.running else {
            if localProbe.isAria2 {
                status = .unhealthy("AriaPilot 服务已安装但未运行，且本机 6800 端口已被已有 aria2 服务占用。请先停止现有服务，再启动内置服务。")
                message = "AriaPilot 服务已安装但未运行，且本机 6800 端口已被已有 aria2 服务占用。"
                return
            }
            status = .stopped
            message = nil
            return
        }
        if localProbe.isHealthy {
            status = .running
            message = nil
        } else if localProbe.isAria2 {
            let text = localProbe.isUnauthorized ?
                "AriaPilot 服务已启动，但 RPC 密钥校验失败。请重启本机服务以重新写入托管配置。" :
                "AriaPilot 服务已启动，但 RPC 返回异常：\(localProbe.healthError ?? "未知错误")"
            status = .unhealthy(text)
            message = text
        } else {
            let text = "AriaPilot 服务已启动，但本机 RPC 暂不可用：\(localProbe.healthError ?? "无响应")"
            status = .unhealthy(text)
            message = text
        }
    }

    private func perform(
        _ action: LocalAria2ServiceAction,
        _ work: @escaping () async throws -> Void
    ) async {
        self.action = action
        defer { self.action = .idle }
        do {
            try await work()
        } catch {
            status = .failed(error.localizedDescription)
            message = error.localizedDescription
        }
    }

    private func waitForRPCReady(secret: String) async {
        for _ in 0..<8 {
            if await checkRPCHealth(secret: secret) == nil {
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func checkRPCHealth(secret: String) async -> String? {
        await probeLocalRPC(secret: secret).healthError
    }

    private func probeLocalRPC(secret: String) async -> LocalRPCProbe {
        guard let url = URL(string: rpcURL) else {
            return LocalRPCProbe(isAria2: false, healthError: "本机 RPC URL 无效。", errorCode: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = RPCRequest(
            method: "aria2.getVersion",
            params: secret.isEmpty ? [] : [.string("token:\(secret)")]
        )
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(RPCResponse<Aria2Version>.self, from: data)
            if let error = response.error {
                return LocalRPCProbe(isAria2: true, healthError: error.message, errorCode: error.code)
            }
            return LocalRPCProbe(
                isAria2: response.result != nil,
                healthError: response.result == nil ? "本机 aria2 RPC 无响应。" : nil,
                errorCode: nil
            )
        } catch {
            return LocalRPCProbe(isAria2: false, healthError: error.localizedDescription, errorCode: nil)
        }
    }

    private func ensurePortAvailableForManagedService(secret: String) async throws {
        guard !(await launchdStatus()).running else { return }
        let localProbe = await probeLocalRPC(secret: secret)
        guard localProbe.isAria2 else { return }
        let text = "检测到已有 aria2 正在使用本机 6800 端口。为避免和 Homebrew 或其他方式安装的 aria2 冲突，已停止安装内置服务。可以切到远程模式并填写 localhost 地址使用现有服务。"
        status = .externalService(text)
        message = text
        throw LocalAria2ServiceError(text)
    }

    private func bootstrapAndKickstart() async throws {
        guard bundledBinaryURL != nil else {
            status = .missingBinary
            message = "当前应用包没有包含 aria2c，无法安装本机下载服务。"
            return
        }
        try await requireLaunchctlSuccess(["bootstrap", guiDomain, launchAgentURL.path])
        try await waitForLaunchdLoaded()
        try await requireLaunchctlSuccess(["kickstart", "-k", serviceTarget])
    }

    private func unloadManagedService() async throws {
        try await requireLaunchctlSuccess(["bootout", serviceTarget])
        try await waitForLaunchdUnloaded()
    }

    private func prepareFiles(downloadDirectory: String, secret: String) throws {
        guard let binaryURL = bundledBinaryURL else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: downloadsURL(from: downloadDirectory), withIntermediateDirectories: true)
        try fm.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: sessionURL.path) {
            fm.createFile(atPath: sessionURL.path, contents: Data())
        }
        try setExecutable(binaryURL)
        try config(downloadDirectory: downloadDirectory, secret: secret).write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
        try writeLaunchAgent(binaryURL: binaryURL)
    }

    private func rewriteLaunchAgentIfInstalled() throws {
        guard FileManager.default.fileExists(atPath: launchAgentURL.path),
              let binaryURL = bundledBinaryURL else {
            return
        }
        try writeLaunchAgent(binaryURL: binaryURL)
    }

    private func writeLaunchAgent(binaryURL: URL) throws {
        try launchAgent(binaryURL: binaryURL).write(
            to: launchAgentURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private func config(downloadDirectory: String, secret: String) -> String {
        let dir = downloadsURL(from: downloadDirectory).path
        return """
        enable-rpc=true
        rpc-listen-all=false
        rpc-listen-port=\(defaultPort)
        rpc-secret=\(secret)
        dir=\(dir)
        continue=true
        save-session=\(sessionURL.path)
        input-file=\(sessionURL.path)
        save-session-interval=60
        max-concurrent-downloads=5
        max-connection-per-server=5
        split=5
        file-allocation=none
        log=\(logURL.path)
        log-level=warn
        """
    }

    private func launchAgent(binaryURL: URL) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(xmlEscaped(binaryURL.path))</string>
                <string>--conf-path=\(xmlEscaped(configURL.path))</string>
            </array>
            <key>RunAtLoad</key>
            <false/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(xmlEscaped(stdoutURL.path))</string>
            <key>StandardErrorPath</key>
            <string>\(xmlEscaped(stderrURL.path))</string>
        </dict>
        </plist>
        """
    }

    private func readBundledVersion() async -> String {
        if let cachedBundledVersion {
            return cachedBundledVersion
        }
        guard let binaryURL = bundledBinaryURL else { return "" }
        let result = await run(binaryURL.path, ["--version"])
        let version = result.output
            .split(separator: "\n")
            .first
            .map(String.init) ?? ""
        cachedBundledVersion = version
        return version
    }

    private func isLaunchdLoaded() async -> Bool {
        (await launchdStatus()).loaded
    }

    private func launchdStatus() async -> LaunchdStatus {
        let result = await run("/bin/launchctl", ["print", serviceTarget])
        guard result.exitCode == 0 else {
            return LaunchdStatus(loaded: false, running: false)
        }
        let output = result.output.lowercased()
        let running = output.contains("state = running") ||
            output.range(of: #"pid = [1-9][0-9]*"#, options: .regularExpression) != nil
        return LaunchdStatus(loaded: true, running: running)
    }

    private func waitForLaunchdLoaded() async throws {
        for _ in 0..<10 {
            if await isLaunchdLoaded() {
                return
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        throw LocalAria2ServiceError("launchd 已执行加载，但服务状态迟迟没有变为已加载。")
    }

    private func waitForLaunchdUnloaded() async throws {
        for _ in 0..<10 {
            if !(await isLaunchdLoaded()) {
                return
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        throw LocalAria2ServiceError("launchd 已执行停止，但服务仍然处于已加载状态。")
    }

    private func runLaunchctl(_ arguments: [String]) async -> ProcessResult {
        await run("/bin/launchctl", arguments)
    }

    private func requireLaunchctlSuccess(_ arguments: [String]) async throws {
        let result = await runLaunchctl(arguments)
        guard result.exitCode == 0 else {
            throw LocalAria2ServiceError("launchctl \(arguments.joined(separator: " ")) 失败：\(result.summary)")
        }
    }

    private func run(_ launchPath: String, _ arguments: [String]) async -> ProcessResult {
        await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return ProcessResult(
                    exitCode: process.terminationStatus,
                    output: String(data: data, encoding: .utf8) ?? ""
                )
            } catch {
                return ProcessResult(exitCode: -1, output: error.localizedDescription)
            }
        }.value
    }

    private func setExecutable(_ url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }

    private func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func downloadsURL(from path: String) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return URL(fileURLWithPath: defaultDownloadDirectory)
        }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath)
    }

    private var bundledBinaryURL: URL? {
        if let url = Bundle.main.url(
            forResource: "aria2c",
            withExtension: nil,
            subdirectory: "aria2"
        ) {
            return url
        }
        let devURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("vendor/aria2/darwin-arm64/aria2c")
        return FileManager.default.fileExists(atPath: devURL.path) ? devURL : nil
    }

    private var appSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AriaPilot/aria2", isDirectory: true)
    }

    private var downloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private var configURL: URL { appSupportURL.appendingPathComponent("aria2.conf") }
    private var sessionURL: URL { appSupportURL.appendingPathComponent("aria2.session") }
    private var logURL: URL { appSupportURL.appendingPathComponent("aria2.log") }
    private var stdoutURL: URL { appSupportURL.appendingPathComponent("aria2.out.log") }
    private var stderrURL: URL { appSupportURL.appendingPathComponent("aria2.err.log") }

    private var guiDomain: String {
        "gui/\(getuid())"
    }

    private var serviceTarget: String {
        "\(guiDomain)/\(label)"
    }

    private static func makeSecret() -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<32).map { _ in letters[Int.random(in: 0..<letters.count)] })
    }
}

struct ProcessResult {
    let exitCode: Int32
    let output: String

    var summary: String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "退出码 \(exitCode)" : trimmed
    }
}

struct LocalRPCProbe {
    let isAria2: Bool
    let healthError: String?
    let errorCode: Int?

    var isHealthy: Bool {
        isAria2 && healthError == nil
    }

    var isUnauthorized: Bool {
        errorCode == 1 || healthError?.localizedCaseInsensitiveContains("unauthorized") == true
    }
}

struct LaunchdStatus {
    let loaded: Bool
    let running: Bool
}

struct LocalAria2ServiceError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
