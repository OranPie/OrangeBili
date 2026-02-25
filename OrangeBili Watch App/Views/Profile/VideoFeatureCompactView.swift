import SwiftUI

struct VideoFeatureCompactView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private var features: [(String, String)] {
        [
            (L10n.t("video.feature.seekBack"), "gobackward.10"),
            (L10n.t("video.feature.seekForward"), "goforward.10"),
            (L10n.t("video.feature.speed"), "speedometer"),
            (L10n.t("video.feature.mute"), "speaker.wave.2.fill"),
            (L10n.t("video.feature.replay"), "arrow.counterclockwise"),
            (L10n.t("video.feature.route"), "point.3.connected.trianglepath.dotted"),
            (L10n.t("video.feature.hideControls"), "chevron.down.circle"),
            (L10n.t("video.feature.offline"), "tray.and.arrow.down.fill")
        ]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(features, id: \.0) { item in
                    VStack(spacing: 4) {
                        Image(systemName: item.1)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.0)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .navigationTitle(L10n.t("video.feature.title"))
    }
}
