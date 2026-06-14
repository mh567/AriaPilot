import AppKit
import SwiftUI

struct AddDownloadView: View {
    @EnvironmentObject var manager: DownloadManager
    @Binding var page: Page
    @State private var url = ""
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 12) {
            Text("添加下载")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("下载链接", text: $url)
                    .textFieldStyle(.roundedBorder)

                Button {
                    pasteDownloadURL()
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
                .disabled(isAdding)
            }

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

            if let error = manager.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .lineLimit(3)
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.red)
            }

            HStack {
                Button("取消") { page = .main }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isAdding)
                Spacer()
                Button(isAdding ? "添加中..." : "添加") {
                    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        isAdding = true
                        let added = await manager.addDownload(url: trimmed)
                        isAdding = false
                        if added {
                            page = .main
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isAdding || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }

    private var downloadLocation: String {
        let dir = manager.downloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return dir.isEmpty ? "aria2 默认位置" : dir
    }

    private func pasteDownloadURL() {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        url = trimmed
    }
}
