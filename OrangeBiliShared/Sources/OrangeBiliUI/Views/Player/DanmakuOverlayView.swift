import SwiftUI
import OrangeBiliCore

struct DanmakuOverlayView: View {
    @ObservedObject var viewModel: DanmakuViewModel
    let currentTime: Double

    @EnvironmentObject private var render: RenderSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(viewModel.active) { item in
                    Text(item.item.text)
                        .font(.system(size: item.fontSize, weight: .semibold))
                        .foregroundStyle(item.color.opacity(render.danmakuOpacity))
                        .position(
                            x: viewModel.xPosition(for: item, time: currentTime, width: proxy.size.width),
                            y: item.y
                        )
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: currentTime) { _, newValue in
                viewModel.update(time: newValue, size: proxy.size, settings: render)
            }
        }
        .allowsHitTesting(false)
    }
}

