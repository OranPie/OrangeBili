import SwiftUI
import OrangeBiliCore

struct HistoryRecordsView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        Group {
            if case .grid = UIStyle.videoLayout {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                        if historyStore.records.isEmpty {
                            EmptyStateView(L10n.t("history.empty"), systemImage: "clock")
                        } else {
                            VideoListingView(videos: historyStore.records.map(\.asVideo), rowInsets: nil) { video in
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
                        VideoListingView(videos: historyStore.records.map(\.asVideo)) { video in
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
        .refreshable {
            // Trigger UI refresh by toggling a minor state
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
