import SwiftUI

struct OfflineVideoManageView: View {
    let itemID: UUID

    @EnvironmentObject private var downloadManager: OfflineDownloadManager

    var body: some View {
        List {
            if let item = currentItem {
                Section("文件") {
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

                Section("操作") {
                    NavigationLink("播放离线视频") {
                        VideoPlayerView(video: offlineVideo(for: item), cid: 0, localFileURL: item.localFileURL)
                    }
                    NavigationLink("查看详情") {
                        VideoDetailView(seedVideo: offlineVideo(for: item))
                    }
                    Button("删除离线文件", role: .destructive) {
                        downloadManager.remove(itemID: item.id)
                    }
                }
            } else {
                Text("文件不存在或已删除")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("离线管理")
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
            author: "离线缓存",
            mid: nil,
            coverURL: item.localCoverURL ?? item.coverURL,
            viewCount: 0,
            danmakuCount: 0,
            durationText: "00:00",
            description: "",
            sourceTag: "本地"
        )
    }
}
