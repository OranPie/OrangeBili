import SwiftUI
import OrangeBiliCore

struct VideoRowView: View {
    let video: BiliVideo

    @EnvironmentObject private var render: RenderSettings

    var body: some View {
        let cardScale = render.videoCardScale
        let platformScale = UIStyle.platformScale
        #if os(tvOS)
        let baseWidth: CGFloat = 240
        #else
        let baseWidth: CGFloat = 96
        #endif
        let baseHeight = baseWidth * 9.0 / 16.0

        HStack(spacing: 8 * cardScale) {
            AsyncCachedImage(url: video.coverURL) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.24))
                    .overlay(ProgressView().scaleEffect(0.7))
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(width: baseWidth * cardScale, height: baseHeight * cardScale)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: render.compactStats ? 2 : 4) {
                Text(video.title)
                    .font(.system(size: 12 * UIStyle.videoTitleScale * render.textScale * cardScale * platformScale * platformScale, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(render.compactStats ? 1 : 2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !render.compactStats {
                    Text(video.author)
                        .font(.system(size: 10 * render.textScale * cardScale * platformScale * platformScale))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    statCell(icon: "play.fill", text: Formatting.count(video.viewCount))
                    statCell(icon: "message", text: Formatting.count(video.danmakuCount))
                }
                .font(.system(size: 9 * render.textScale * cardScale * platformScale * platformScale))
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
                .font(.system(size: 8.5 * render.textScale * cardScale * platformScale * platformScale))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let publishedAt = video.publishedAt {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                        Text(L10n.f("label.published", Formatting.absoluteDate(publishedAt)))
                    }
                    .font(.system(size: 8 * render.textScale * cardScale * platformScale * platformScale))
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
