import SwiftUI

struct DownloadRowView: View {
    @EnvironmentObject var manager: DownloadManager
    let download: Download
    @AppStorage("deleteActionPreference") private var deleteActionPreference = DeleteActionPreference.ask.rawValue
    @State private var showingDeleteOptions = false
    @State private var deleteFiles = false
    @State private var rememberDeleteChoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(download.displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                ProgressView(value: download.progress)
                    .frame(maxWidth: .infinity)

                Text(Fmt.percent(download.progress))
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }

            HStack {
                statusLabel
                Spacer()
                actionButtons
            }

            if showingDeleteOptions {
                deleteOptionsView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            if download.isActive {
                Image(systemName: "arrow.down")
                    .font(.caption2)
                Text(Fmt.speed(download.speed))
            } else if download.isPaused {
                Image(systemName: "pause.fill")
                    .font(.caption2)
                Text("已暂停")
            } else if download.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(Fmt.bytes(download.totalBytes))
            } else if download.isError {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Text(download.status)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            if download.isActive {
                Button { Task { await manager.pause(gid: download.gid) } } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.borderless)
            } else if download.isPaused {
                Button { Task { await manager.unpause(gid: download.gid) } } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
            }

            Button {
                handleDeleteTap()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
    }

    private var deleteOptionsView: some View {
        HStack(spacing: 10) {
            if canDeleteFiles {
                Toggle("同时删除文件", isOn: $deleteFiles)
                    .toggleStyle(.checkbox)
            }
            Toggle("记住本次选择", isOn: $rememberDeleteChoice)
                .toggleStyle(.checkbox)

            Spacer(minLength: 8)

            Button("取消") {
                showingDeleteOptions = false
            }
            .buttonStyle(.bordered)

            Button("删除", role: .destructive) {
                confirmDelete(deleteFiles: deleteFiles, remember: rememberDeleteChoice)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func handleDeleteTap() {
        let preference = DeleteActionPreference(rawValue: deleteActionPreference) ?? .ask
        switch preference {
        case .ask:
            deleteFiles = false
            rememberDeleteChoice = false
            showingDeleteOptions = true
        case .taskOnly:
            confirmDelete(deleteFiles: false, remember: false)
        case .taskAndFiles:
            confirmDelete(deleteFiles: canDeleteFiles, remember: false)
        }
    }

    private func confirmDelete(deleteFiles: Bool, remember: Bool) {
        let effectiveDeleteFiles = canDeleteFiles && deleteFiles
        if remember {
            deleteActionPreference = effectiveDeleteFiles ?
                DeleteActionPreference.taskAndFiles.rawValue :
                DeleteActionPreference.taskOnly.rawValue
        }
        showingDeleteOptions = false
        Task { await manager.remove(download: download, deleteFiles: effectiveDeleteFiles) }
    }

    private var canDeleteFiles: Bool {
        ConnectionMode(rawValue: manager.connectionMode) == .local
    }
}
