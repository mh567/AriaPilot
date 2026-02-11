import SwiftUI

struct AddDownloadView: View {
    @EnvironmentObject var manager: DownloadManager
    @Binding var page: Page
    @State private var url = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Download")
                .font(.headline)

            TextField("URL", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { page = .main }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        await manager.addDownload(url: trimmed)
                        page = .main
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }
}
