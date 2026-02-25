import SwiftUI
import OrangeBiliCore

struct OfflineVideoManageView: View {
    let itemID: UUID

    @EnvironmentObject private var downloadManager: OfflineDownloadManager

    var body: some View {
        List {
            if let item = currentItem {
                Section(L10n.t("offline.file")) {
                    HStack(spacing: 8) {
                        AsyncCachedImage(url: item.localCoverURL ?? item.coverURL) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.gray.opacity(0.24))
                        }
                        .frame(width: 60, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption2)
                                .lineLimit(2)
                            Text(item.bvid)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section(L10n.t("offline.actions")) {
                    NavigationLink(L10n.t("offline.play")) {
                        VideoPlayerView(video: offlineVideo(for: item), cid: 0, localFileURL: item.localFileURL)
                    }
                    NavigationLink(L10n.t("offline.detail")) {
                        VideoDetailView(seedVideo: offlineVideo(for: item))
                    }
                    Button(L10n.t("offline.delete"), role: .destructive) {
                        downloadManager.remove(itemID: item.id)
                    }
                }
            } else {
                EmptyStateView(L10n.t("offline.missing"), systemImage: "exclamationmark.triangle")
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("offline.title"))
    }

    private var currentItem: DownloadStatusItem? {
        downloadManager.items.first(where: { $0.id == itemID && $0.localFileURL != nil })
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
