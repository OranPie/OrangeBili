import SwiftUI
import OrangeBiliCore

struct DanmakuOverlayView: View {
    @ObservedObject var viewModel: DanmakuViewModel
    @ObservedObject var playerViewModel: PlayerViewModel

    @EnvironmentObject private var render: RenderSettings
    @State private var lastUpdateTime: Double = -1
    @State private var canvasSize: CGSize = .zero
#if os(watchOS)
    private let ticker = Timer.publish(every: 1.0 / 24.0, on: .main, in: .common).autoconnect()
#else
    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
#endif

    var body: some View {
        GeometryReader { geo in
            Group {
#if os(watchOS)
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { _ in
                    Canvas { context, size in
                        let time = currentPlaybackTime()
                        let contentRect = videoContentRect(in: size)
                        for item in viewModel.active {
                            drawDanmaku(item, in: &context, contentRect: contentRect, time: time)
                        }
                    }
                }
#else
                TimelineView(.animation) { _ in
                    Canvas { context, size in
                        let time = currentPlaybackTime()
                        let contentRect = videoContentRect(in: size)
                        for item in viewModel.active {
                            drawDanmaku(item, in: &context, contentRect: contentRect, time: time)
                        }
                    }
                }
#endif
            }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { newValue in
                canvasSize = newValue
            }
        }
        .onReceive(ticker) { _ in
            tickDanmaku()
        }
        .allowsHitTesting(false)
    }

    private func shouldUpdateDanmaku(at time: Double) -> Bool {
        guard lastUpdateTime >= 0 else { return true }
#if os(watchOS)
        return abs(time - lastUpdateTime) >= (1.0 / 48.0)
#else
        return (time - lastUpdateTime) >= (1.0 / 30.0) || time < lastUpdateTime
#endif
    }

    private func currentPlaybackTime() -> Double {
        if let playerTime = playerViewModel.player?.currentTime().seconds, playerTime.isFinite, playerTime >= 0 {
            return playerTime
        }
        let fallback = playerViewModel.currentTime
        return (fallback.isFinite && fallback >= 0) ? fallback : 0
    }

    private func tickDanmaku() {
        let time = currentPlaybackTime()
        viewModel.currentVideoTime = time
        guard shouldUpdateDanmaku(at: time) else { return }
        guard canvasSize.width > 1, canvasSize.height > 1 else { return }
        let contentRect = videoContentRect(in: canvasSize)
        viewModel.update(time: time, size: contentRect.size, settings: render)
        lastUpdateTime = time
    }

    /// Compute the actual video content area within the view, excluding black bars.
    private func videoContentRect(in size: CGSize) -> CGRect {
        guard let info = playerViewModel.videoFormatInfo,
              info.width > 0, info.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let videoAspect = CGFloat(info.width) / CGFloat(info.height)
        let viewAspect = size.width / size.height

        if videoAspect > viewAspect {
            // Wider video → letterbox (black bars top/bottom)
            let h = size.width / videoAspect
            return CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
        } else {
            // Taller video → pillarbox (black bars left/right)
            let w = size.height * videoAspect
            return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
        }
    }

    private func drawDanmaku(_ item: DanmakuViewModel.RenderDanmaku, in context: inout GraphicsContext, contentRect: CGRect, time: Double) {
        let elapsed = time - item.startTime
        let progress = min(max(elapsed / item.duration, 0), 1)
        let cw = contentRect.size.width
        let ch = contentRect.size.height
        let ox = contentRect.minX
        let oy = contentRect.minY

        var x: CGFloat
        var y = item.y + oy
        var opacity = render.danmakuOpacity
        var rotation = Angle.zero

        switch item.mode {
        case .scroll:
            let total = cw + item.textWidth + 12
            x = ox + cw - total * progress + item.textWidth / 2

        case .reverse:
            let total = cw + item.textWidth + 12
            x = ox - item.textWidth / 2 + total * progress

        case .top, .bottom:
            x = ox + cw / 2

        case .advanced:
            guard let p = item.advancedParams else { return }
            let moveProgress = advancedMoveProgress(elapsed: elapsed, params: p)
            let refW: CGFloat = 945
            let refH: CGFloat = 600
            let sx = p.startX > 1 ? p.startX / refW : p.startX
            let sy = p.startY > 1 ? p.startY / refH : p.startY
            let ex = p.endX > 1 ? p.endX / refW : p.endX
            let ey = p.endY > 1 ? p.endY / refH : p.endY
            x = ox + lerp(sx, ex, moveProgress) * cw
            y = oy + lerp(sy, ey, moveProgress) * ch
            opacity = lerp(p.startOpacity, p.endOpacity, progress)
            rotation = .degrees(p.zRotate)
        }

        var textContext = context
        textContext.opacity = opacity

        if rotation != .zero {
            textContext.translateBy(x: x, y: y)
            textContext.rotate(by: rotation)
            textContext.translateBy(x: -x, y: -y)
        }

        let resolvedText = textContext.resolve(
            Text(item.text)
                .font(.system(size: item.fontSize, weight: .semibold))
                .foregroundColor(item.color)
        )

        let anchor: UnitPoint = item.mode == .advanced ? .topLeading : .center
        let point = CGPoint(x: x, y: y)

        // Draw stroke outline behind text (non-advanced only)
        if render.danmakuStrokeEnabled && item.mode != .advanced {
            let sw = render.danmakuStrokeWidth
            let strokeText = textContext.resolve(
                Text(item.text)
                    .font(.system(size: item.fontSize, weight: .semibold))
                    .foregroundColor(.black)
            )
#if os(watchOS)
            let offsets: [(Double, Double)] = [(-sw, 0), (sw, 0), (0, -sw), (0, sw)]
#else
            let offsets: [(Double, Double)] = [(-sw, -sw), (-sw, 0), (-sw, sw), (0, -sw), (0, sw), (sw, -sw), (sw, 0), (sw, sw)]
#endif
            for (dx, dy) in offsets {
                textContext.draw(strokeText, at: CGPoint(x: point.x + dx, y: point.y + dy), anchor: anchor)
            }
        }

        textContext.draw(resolvedText, at: point, anchor: anchor)
    }

    // MARK: - Advanced mode helpers

    private func advancedMoveProgress(elapsed: Double, params: AdvancedDanmakuParams) -> Double {
        let delayS = params.moveDelay / 1000.0
        let moveS = params.moveTime / 1000.0
        if elapsed < delayS { return 0 }
        let moveElapsed = elapsed - delayS
        if moveS <= 0 { return 1 }
        let raw = min(moveElapsed / moveS, 1.0)
        return params.linearSpeedUp ? raw : easeInOut(raw)
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
