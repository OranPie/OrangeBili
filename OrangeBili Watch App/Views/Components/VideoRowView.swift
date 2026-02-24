import SwiftUI

struct VideoRowView: View {
    let video: BiliVideo

    @EnvironmentObject private var render: RenderSettings

    var body: some View {
        let cardScale = render.videoCardScale
        HStack(spacing: 8 * cardScale) {
            AsyncCachedImage(url: video.coverURL) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.24))
                    .overlay(ProgressView().scaleEffect(0.7))
            }
            .frame(width: 68 * cardScale, height: 40 * cardScale)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: render.compactStats ? 2 : 4) {
                Text(video.title)
                    .font(.system(size: 12 * render.textScale * cardScale, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(render.compactStats ? 1 : 2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !render.compactStats {
                    Text(video.author)
                        .font(.system(size: 10 * render.textScale * cardScale))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    statCell(icon: "play.fill", text: Formatting.count(video.viewCount))
                    statCell(icon: "message", text: Formatting.count(video.danmakuCount))
                }
                .font(.system(size: 9 * render.textScale * cardScale))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                    Text(Formatting.compactDuration(video.durationText))
                        .lineLimit(1)
                    if let sourceTag = video.sourceTag {
                        Text("· \(sourceTag)")
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 8.5 * render.textScale * cardScale))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let publishedAt = video.publishedAt {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                        Text("发布 \(Formatting.absoluteDate(publishedAt))")
                    }
                    .font(.system(size: 8 * render.textScale * cardScale))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func statCell(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(.secondary)
    }
}
