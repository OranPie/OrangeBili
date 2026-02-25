import SwiftUI

struct HistoryRecordsView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        List {
            if historyStore.records.isEmpty {
                EmptyStateView(L10n.t("history.empty"), systemImage: "clock")
            } else {
                ForEach(historyStore.records) { record in
                    NavigationLink {
                        VideoDetailView(seedVideo: record.asVideo)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            VideoRowView(video: record.asVideo)
                            if record.progressSeconds > 0 {
                                Text(L10n.f("history.lastProgress", Formatting.timeText(record.progressSeconds)))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            historyStore.delete(id: record.id)
                        } label: {
                            Label(L10n.t("action.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("history.title"))
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
