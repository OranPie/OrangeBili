import SwiftUI

struct HistoryRecordsView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        List {
            if historyStore.records.isEmpty {
                Text("还没有播放记录")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(historyStore.records) { record in
                    NavigationLink {
                        VideoDetailView(seedVideo: record.asVideo)
                    } label: {
                        VideoRowView(video: record.asVideo)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            historyStore.delete(id: record.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("观看历史")
    }
}

private extension HistoryRecord {
    var asVideo: BiliVideo {
        BiliVideo(
            bvid: bvid,
            aid: 0,
            title: title,
            author: "历史记录",
            mid: nil,
            coverURL: coverURL,
            viewCount: 0,
            danmakuCount: 0,
            durationText: "00:00",
            publishedAt: watchedAt,
            description: "",
            sourceTag: "本地"
        )
    }
}
