import SwiftUI
import OrangeBiliCore

struct HistoryRecordsView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var enrichedVideos: [String: BiliVideo] = [:]

    var body: some View {
        let videos = historyStore.records.map { record in
            enrichedVideos[record.bvid] ?? record.asVideo
        }
        Group {
            if case .grid = UIStyle.videoLayout {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                        if historyStore.records.isEmpty {
                            EmptyStateView(L10n.t("history.empty"), systemImage: "clock")
                        } else {
                            VideoListingView(videos: videos, rowInsets: nil) { video in
                                if let record = historyStore.records.first(where: { $0.bvid == video.bvid }), record.progressSeconds > 0 {
                                    Text(L10n.f("history.lastProgress", Formatting.timeText(record.progressSeconds)))
                                        .font(.system(size: UIStyle.fontSize(8)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, UIStyle.listRowInsets.leading)
                    .padding(.vertical, UIStyle.listRowInsets.top)
                }
            } else {
                List {
                    if historyStore.records.isEmpty {
                        EmptyStateView(L10n.t("history.empty"), systemImage: "clock")
                    } else {
                        VideoListingView(videos: videos) { video in
                            if let record = historyStore.records.first(where: { $0.bvid == video.bvid }), record.progressSeconds > 0 {
                                Text(L10n.f("history.lastProgress", Formatting.timeText(record.progressSeconds)))
                                    .font(.system(size: UIStyle.fontSize(8)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(L10n.t("history.title"))
        .task {
            await enrichRecords()
        }
        .refreshable {
            await enrichRecords()
        }
    }

    private func enrichRecords() async {
        for record in historyStore.records {
            guard enrichedVideos[record.bvid] == nil else { continue }
            do {
                let detail = try await apiBackend.fetchVideoDetail(bvid: record.bvid)
                enrichedVideos[record.bvid] = BiliVideo(
                    bvid: detail.bvid,
                    aid: detail.aid,
                    cid: detail.cid,
                    title: detail.title,
                    author: detail.owner.name,
                    mid: detail.owner.id,
                    coverURL: detail.coverURL,
                    viewCount: detail.stats.views,
                    danmakuCount: detail.stats.danmaku,
                    durationText: Formatting.timeText(detail.duration),
                    publishedAt: record.watchedAt,
                    description: detail.description,
                    sourceTag: L10n.t("label.local")
                )
            } catch {
                // Network unavailable or API error — keep placeholder
            }
        }
    }
}

private extension HistoryRecord {
    var asVideo: BiliVideo {
        BiliVideo(
            bvid: bvid,
            aid: 0,
            title: title,
            author: L10n.t("history.author"),
            mid: nil,
            coverURL: coverURL,
            viewCount: 0,
            danmakuCount: 0,
            durationText: "00:00",
            publishedAt: watchedAt,
            description: "",
            sourceTag: L10n.t("label.local")
        )
    }
}
