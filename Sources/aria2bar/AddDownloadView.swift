import SwiftUI

struct AddDownloadView: View {
    @EnvironmentObject var manager: DownloadManager
    @Binding var page: Page
    @State private var url = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("添加下载")
                .font(.headline)

            TextField("下载链接", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text("保存到：\(downloadLocation)")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack {
                Button("取消") { page = .main }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加") {
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

    private var downloadLocation: String {
        let dir = manager.downloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return dir.isEmpty ? "aria2 默认位置" : dir
    }
}
