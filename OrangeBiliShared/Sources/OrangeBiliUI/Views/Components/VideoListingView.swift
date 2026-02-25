import SwiftUI
import OrangeBiliCore

struct VideoListingView<Subtitle: View>: View {
    let videos: [BiliVideo]
    let rowInsets: EdgeInsets?
    let subtitle: (BiliVideo) -> Subtitle

    init(
        videos: [BiliVideo],
        rowInsets: EdgeInsets? = UIStyle.listRowInsets,
        @ViewBuilder subtitle: @escaping (BiliVideo) -> Subtitle
    ) {
        self.videos = videos
        self.rowInsets = rowInsets
        self.subtitle = subtitle
    }

    var body: some View {
        switch UIStyle.videoLayout {
        case .row:
            ForEach(videos) { video in
                NavigationLink {
                    VideoDetailView(seedVideo: video)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        VideoRowView(video: video)
                        subtitle(video)
                    }
                }
                .listRowInsets(rowInsets ?? UIStyle.listRowInsets)
            }
        case let .grid(columns):
            VideoGridView(videos: videos, columns: columns, rowInsets: rowInsets, subtitle: subtitle)
        }
    }
}

struct VideoGridView<Subtitle: View>: View {
    let videos: [BiliVideo]
    let columns: Int
    let rowInsets: EdgeInsets?
    let subtitle: (BiliVideo) -> Subtitle

    var body: some View {
        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: UIStyle.videoGridSpacing, alignment: .leading),
            count: max(columns, 1)
        )

        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: UIStyle.videoGridSpacing) {
            ForEach(videos) { video in
                NavigationLink {
                    VideoDetailView(seedVideo: video)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        VideoRowView(video: video)
                        subtitle(video)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(rowInsets ?? UIStyle.listRowInsets)
    }
}
