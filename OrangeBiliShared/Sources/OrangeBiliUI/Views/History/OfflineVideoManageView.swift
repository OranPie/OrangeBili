import SwiftUI
import OrangeBiliCore

struct OfflineVideoManageView: View {
    let itemID: UUID

    @EnvironmentObject private var downloadManager: OfflineDownloadManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if let item = currentItem {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            headerCard(item)
                            detailsCard(item)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    }

                    Divider()
                    actionsBar(item)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                }
            } else {
                EmptyStateView(L10n.t("offline.missing"), systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(L10n.t("offline.title"))
        .confirmationDialog(
            L10n.t("offline.delete"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.t("action.delete"), role: .destructive) {
                guard let item = currentItem else { return }
                downloadManager.remove(itemID: item.id)
                dismiss()
            }
            Button(L10n.t("action.cancel"), role: .cancel) {}
        }
    }

    private var currentItem: DownloadStatusItem? {
        downloadManager.items.first(where: { $0.id == itemID && $0.localFileURL != nil })
    }

    @ViewBuilder
    private func headerCard(_ item: DownloadStatusItem) -> some View {
        HStack(spacing: 10) {
            AsyncCachedImage(url: item.localCoverURL ?? item.coverURL) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.24))
            }
            .frame(width: 84, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: UIStyle.fontSize(11.5), weight: .semibold))
                    .lineLimit(3)
                Text(item.bvid)
                    .font(.system(size: UIStyle.fontSize(8.5), design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
        }
        .padding(UIStyle.cardPadding)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
    }

    @ViewBuilder
    private func detailsCard(_ item: DownloadStatusItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(label: L10n.t("downloads.state.completed"), value: "✓")
            detailRow(label: L10n.t("tools.cache.size"), value: formatBytes(Int(item.receivedBytes)))
            if let path = item.localFileURL?.lastPathComponent {
                detailRow(label: L10n.t("offline.file"), value: path)
            }
        }
        .padding(UIStyle.cardPadding)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: UIStyle.fontSize(9)))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: UIStyle.fontSize(9), design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private func actionsBar(_ item: DownloadStatusItem) -> some View {
        #if os(watchOS)
        VStack(spacing: 5) {
            NavigationLink(L10n.t("offline.play")) {
                VideoPlayerView(video: offlineVideo(for: item), cid: 0, localFileURL: item.localFileURL)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            .font(.system(size: UIStyle.fontSize(9), weight: .semibold))

            HStack(spacing: 5) {
                NavigationLink(L10n.t("offline.detail")) {
                    VideoDetailView(seedVideo: offlineVideo(for: item))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .font(.system(size: UIStyle.fontSize(8.2), weight: .semibold))

                Button(L10n.t("offline.delete"), role: .destructive) {
                    showDeleteConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .font(.system(size: UIStyle.fontSize(8.2), weight: .semibold))
            }
        }
        #else
        HStack(spacing: 8) {
            NavigationLink(L10n.t("offline.play")) {
                VideoPlayerView(video: offlineVideo(for: item), cid: 0, localFileURL: item.localFileURL)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .font(.system(size: UIStyle.fontSize(10), weight: .semibold))

            NavigationLink(L10n.t("offline.detail")) {
                VideoDetailView(seedVideo: offlineVideo(for: item))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: UIStyle.fontSize(9.5), weight: .semibold))

            Button(L10n.t("offline.delete"), role: .destructive) {
                showDeleteConfirm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: UIStyle.fontSize(9.5), weight: .semibold))
        }
        #endif
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        if bytes >= 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) B"
    }

    private func offlineVideo(for item: DownloadStatusItem) -> BiliVideo {
        BiliVideo(
            bvid: item.bvid,
            aid: 0,
            cid: nil,
            title: item.title,
            author: L10n.t("offline.author"),
            mid: nil,
            coverURL: item.localCoverURL ?? item.coverURL,
            viewCount: 0,
            danmakuCount: 0,
            durationText: "00:00",
            description: "",
            sourceTag: L10n.t("offline.source")
        )
    }
}
