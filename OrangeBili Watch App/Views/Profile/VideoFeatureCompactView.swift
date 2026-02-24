import SwiftUI

struct VideoFeatureCompactView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private let features: [(String, String)] = [
        ("seek -10s", "gobackward.10"),
        ("seek +10s", "goforward.10"),
        ("倍速切换", "speedometer"),
        ("静音切换", "speaker.wave.2.fill"),
        ("重播", "arrow.counterclockwise"),
        ("线路切换", "point.3.connected.trianglepath.dotted"),
        ("隐藏控制层", "chevron.down.circle"),
        ("离线播放", "tray.and.arrow.down.fill")
    ]

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
        .navigationTitle("视频功能")
    }
}
