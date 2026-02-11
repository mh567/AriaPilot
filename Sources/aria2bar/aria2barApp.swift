import SwiftUI

@main
struct aria2barApp: App {
    @StateObject private var manager = DownloadManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(manager)
        } label: {
            Label("aria2bar", systemImage: "arrow.down.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
