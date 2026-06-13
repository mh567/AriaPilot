import SwiftUI

@main
struct AriaPilotApp: App {
    @StateObject private var manager = DownloadManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(manager)
        } label: {
            Label("AriaPilot", systemImage: "arrow.down.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
