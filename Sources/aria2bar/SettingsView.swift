import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: DownloadManager
    @Binding var page: Page
    @StateObject private var updateManager = UpdateManager()
    @State private var rpcURL = ""
    @State private var rpcSecret = ""
    @State private var downloadDirectory = ""
    @State private var maxConcurrentDownloads = 5
    @State private var connectionsPerDownload = 5
    @State private var downloadSpeedLimit = ""
    @State private var uploadSpeedLimit = ""
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(.headline)

            ScrollView {
                VStack(spacing: 12) {
                    connectionSection
                    Divider()
                    downloadSection
                    Divider()
                    speedSection
                    Divider()
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .font(.caption)
                        .onChange(of: launchAtLogin, perform: setLaunchAtLogin)
                    Divider()
                    updateSection
                }
            }
            .frame(maxHeight: 420)

            HStack {
                Button("Cancel") { page = .main }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
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
            fieldLabel("RPC URL")
            TextField("http://localhost:6800/jsonrpc", text: $rpcURL)
                .textFieldStyle(.roundedBorder)

            fieldLabel("Secret Token")
            SecureField("Optional", text: $rpcSecret)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Download Location")
            HStack(spacing: 6) {
                TextField("Use aria2 default", text: $downloadDirectory)
                    .textFieldStyle(.roundedBorder)
                Button("Choose") {
                    chooseDownloadDirectory()
                }
            }

            Stepper(
                "Concurrent Downloads: \(maxConcurrentDownloads)",
                value: $maxConcurrentDownloads,
                in: 1...100
            )
            .font(.caption)

            Stepper(
                "Connections per Download: \(connectionsPerDownload)",
                value: $connectionsPerDownload,
                in: 1...64
            )
            .font(.caption)
        }
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Global Download Limit")
            TextField("0, 500K, 2M", text: $downloadSpeedLimit)
                .textFieldStyle(.roundedBorder)

            fieldLabel("Global Upload Limit")
            TextField("0, 500K, 2M", text: $uploadSpeedLimit)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Updates")
            HStack {
                Text("Current Version: \(updateManager.currentVersion)")
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
                    Button("Update Now") {
                        Task { await updateManager.installUpdate(release) }
                    }
                    .disabled(isUpdateBusy)
                }
            }
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var updateButtonTitle: String {
        switch updateManager.state {
        case .checking:
            return "Checking..."
        case .downloading:
            return "Updating..."
        default:
            return "Check for Updates"
        }
    }

    private var updateStatus: String? {
        switch updateManager.state {
        case .idle:
            return nil
        case .checking:
            return "Checking the latest GitHub release."
        case .available(let release):
            return "Version \(release.version) is available."
        case .upToDate:
            return "You are up to date."
        case .downloading:
            return "Downloading and preparing the update."
        case .readyToRestart:
            return "Restarting to finish the update."
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

    private var isUpdateBusy: Bool {
        switch updateManager.state {
        case .checking, .downloading, .readyToRestart:
            return true
        default:
            return false
        }
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            downloadDirectory = url.path
        }
    }

    private func save() {
        manager.rpcURL = rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.rpcSecret = rpcSecret
        manager.downloadDirectory = downloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.maxConcurrentDownloads = maxConcurrentDownloads
        manager.connectionsPerDownload = connectionsPerDownload
        manager.downloadSpeedLimit = downloadSpeedLimit.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.uploadSpeedLimit = uploadSpeedLimit.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.hasSavedDownloadSettings = true
        manager.startPolling()
        Task {
            await manager.applyGlobalOptions()
            page = .main
        }
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
