import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: DownloadManager
    @Binding var page: Page
    @State private var rpcURL = ""
    @State private var rpcSecret = ""
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("RPC URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("http://localhost:6800/jsonrpc", text: $rpcURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Secret Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Optional", text: $rpcSecret)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .font(.caption)
                .onChange(of: launchAtLogin, perform: setLaunchAtLogin)

            HStack {
                Button("Cancel") { page = .main }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    manager.rpcURL = rpcURL
                    manager.rpcSecret = rpcSecret
                    manager.startPolling()
                    page = .main
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear {
            rpcURL = manager.rpcURL
            rpcSecret = manager.rpcSecret
            launchAtLogin = SMAppService.mainApp.status == .enabled
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
