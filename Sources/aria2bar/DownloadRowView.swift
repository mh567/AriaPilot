import SwiftUI

struct DownloadRowView: View {
    @EnvironmentObject var manager: DownloadManager
    let download: Download

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
                Text("Paused")
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

            Button { Task { await manager.remove(gid: download.gid) } } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
    }
}
