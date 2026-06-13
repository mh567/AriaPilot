import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: DownloadManager
    var onClose: () -> Void
    @StateObject private var updateManager = UpdateManager()
    @State private var rpcURL = ""
    @State private var rpcSecret = ""
    @State private var downloadDirectory = ""
    @State private var maxConcurrentDownloads = 5
    @State private var connectionsPerDownload = 5
    @State private var downloadSpeedLimit = ""
    @State private var uploadSpeedLimit = ""
    @State private var launchAtLogin = false
    @State private var validationError: String?
    @State private var connectionStatus: String?
    @State private var isLoadingRemoteSettings = false

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    connectionSection
                    downloadSection
                    speedSection
                    startupSection
                    updateSection
                }
            }

            if let validationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(validationError)
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.red)
            }

            HStack {
                Button("取消") { onClose() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 500)
        .onAppear {
            rpcURL = manager.rpcURL
            rpcSecret = manager.rpcSecret
            downloadDirectory = manager.downloadDirectory
            maxConcurrentDownloads = manager.maxConcurrentDownloads
            connectionsPerDownload = manager.connectionsPerDownload
            downloadSpeedLimit = manager.downloadSpeedLimit
            uploadSpeedLimit = manager.uploadSpeedLimit
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("连接")

            fieldLabel("RPC URL")
            TextField("http://localhost:6800/jsonrpc", text: $rpcURL)
                .textFieldStyle(.roundedBorder)

            fieldLabel("密钥")
            SecureField("可选", text: $rpcSecret)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(remoteSettingsButtonTitle) {
                    Task { await loadRemoteSettings() }
                }
                .disabled(isLoadingRemoteSettings)

                if let connectionStatus {
                    Text(connectionStatus)
                        .font(.caption2)
                        .foregroundStyle(connectionStatusColor)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
    }

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("下载")

            fieldLabel("服务端下载路径")
            TextField("使用 aria2 默认位置，例如 /downloads 或 D:\\Downloads", text: $downloadDirectory)
                .textFieldStyle(.roundedBorder)
            helperText("填写 aria2 服务所在机器能访问的路径。远程 aria2 请使用服务端路径，留空则使用 aria2 默认位置。")

            Stepper(
                "同时下载任务：\(maxConcurrentDownloads)",
                value: $maxConcurrentDownloads,
                in: 1...100
            )
            .font(.caption)

            Stepper(
                "单任务连接数：\(connectionsPerDownload)",
                value: $connectionsPerDownload,
                in: 1...64
            )
            .font(.caption)
        }
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("速度限制")

            fieldLabel("全局下载限速")
            TextField("0, 500K, 2M", text: $downloadSpeedLimit)
                .textFieldStyle(.roundedBorder)

            fieldLabel("全局上传限速")
            TextField("0, 500K, 2M", text: $uploadSpeedLimit)
                .textFieldStyle(.roundedBorder)

            helperText("0 表示不限速。例如：500K、2M。")
        }
    }

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("启动")

            Toggle("登录时启动", isOn: $launchAtLogin)
                .font(.caption)
                .onChange(of: launchAtLogin, perform: setLaunchAtLogin)
        }
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("更新")

            HStack {
                Text("当前版本：\(updateManager.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let status = updateStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(updateStatusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(updateButtonTitle) {
                    Task { await updateManager.checkForUpdates() }
                }
                .disabled(isUpdateBusy)

                if case .available(let release) = updateManager.state {
                    Button("立即更新") {
                        Task { await updateManager.installUpdate(release) }
                    }
                    .disabled(isUpdateBusy)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var updateButtonTitle: String {
        switch updateManager.state {
        case .checking:
            return "检查中..."
        case .downloading:
            return "更新中..."
        default:
            return "检查更新"
        }
    }

    private var updateStatus: String? {
        switch updateManager.state {
        case .idle:
            return nil
        case .checking:
            return "正在检查 GitHub 最新版本。"
        case .available(let release):
            return "发现新版本 \(release.version)。"
        case .upToDate:
            return "当前已是最新版本。"
        case .downloading:
            return "正在下载并准备更新。"
        case .readyToRestart:
            return "正在重启以完成更新。"
        case .failed(let message):
            return message
        }
    }

    private var updateStatusColor: Color {
        if case .failed = updateManager.state {
            return .red
        }
        return .secondary
    }

    private var remoteSettingsButtonTitle: String {
        isLoadingRemoteSettings ? "检测中..." : "检测并读取配置"
    }

    private var connectionStatusColor: Color {
        guard let connectionStatus else { return .secondary }
        return connectionStatus.hasPrefix("连接失败") ? .red : .secondary
    }

    private var isUpdateBusy: Bool {
        switch updateManager.state {
        case .checking, .downloading, .readyToRestart:
            return true
        default:
            return false
        }
    }

    private func loadRemoteSettings(silent: Bool = false) async {
        let url = rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            connectionStatus = "请先填写 RPC URL。"
            return
        }

        isLoadingRemoteSettings = true
        if !silent {
            connectionStatus = "正在连接 aria2..."
        }
        defer { isLoadingRemoteSettings = false }

        do {
            let remote = try await manager.loadRemoteSettings(
                rpcURL: url,
                rpcSecret: rpcSecret
            )
            downloadDirectory = remote.downloadDirectory
            maxConcurrentDownloads = remote.maxConcurrentDownloads
            connectionsPerDownload = remote.connectionsPerDownload
            downloadSpeedLimit = remote.downloadSpeedLimit
            uploadSpeedLimit = remote.uploadSpeedLimit
            connectionStatus = "已连接，并已读取 aria2 配置。"
        } catch {
            if !silent {
                connectionStatus = "连接失败：\(error.localizedDescription)"
            }
        }
    }

    private func save() {
        validationError = nil
        guard isValidSpeedLimit(downloadSpeedLimit),
              isValidSpeedLimit(uploadSpeedLimit) else {
            validationError = "速度限制必须是 0，或类似 500K、2M 的数值。"
            return
        }

        manager.rpcURL = rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.rpcSecret = rpcSecret
        manager.downloadDirectory = downloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.maxConcurrentDownloads = maxConcurrentDownloads
        manager.connectionsPerDownload = connectionsPerDownload
        manager.downloadSpeedLimit = downloadSpeedLimit.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.uploadSpeedLimit = uploadSpeedLimit.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.hasSavedDownloadSettings = true
        manager.startPolling(applySavedOptions: false)
        Task {
            await manager.applyGlobalOptions()
            onClose()
        }
    }

    private func isValidSpeedLimit(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let unit = trimmed.last?.uppercased()
        let numberPart: Substring
        if unit == "K" || unit == "M" {
            numberPart = trimmed.dropLast()
        } else {
            numberPart = Substring(trimmed)
        }
        return Int(numberPart).map { $0 >= 0 } ?? false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
