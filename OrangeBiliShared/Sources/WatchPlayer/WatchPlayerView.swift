import SwiftUI
import AVFoundation
#if canImport(AVKit)
import AVKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

@available(watchOS 9.0, *)
public final class WatchPlayerEngine: ObservableObject {
    @Published public private(set) var isPlaying = false
    @Published public private(set) var isBuffering = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var bufferedProgress: Double = 0

    private weak var player: AVPlayer?
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var loadedRangesObserver: NSKeyValueObservation?

    deinit {
        clearObservers()
    }

    public func bind(player: AVPlayer) {
        guard self.player !== player else { return }
        clearObservers()
        self.player = player
        refreshFromPlayer()
        attachObservers(player: player)
    }

    public func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
        refreshFromPlayer()
    }

    public func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    public func seek(to seconds: Double) {
        guard let player else { return }
        let safeDuration = duration.isFinite && duration > 0 ? duration : seconds
        let target = min(max(seconds, 0), max(safeDuration, 0))
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func seek(progress: Double) {
        guard duration > 0 else { return }
        seek(to: duration * min(max(progress, 0), 1))
    }

    public func scrubByCrownDelta(_ delta: Double) {
        let secondsPerTick = 0.75
        seek(to: currentTime + (delta * secondsPerTick))
    }

    private func attachObservers(player: AVPlayer) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = max(0, time.seconds.isFinite ? time.seconds : 0)
            self.refreshDurationAndBuffer()
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshFromPlayer()
            }
        }

        itemStatusObserver = player.currentItem?.observe(\.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshFromPlayer()
            }
        }

        loadedRangesObserver = player.currentItem?.observe(\.loadedTimeRanges, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshDurationAndBuffer()
            }
        }
    }

    private func refreshFromPlayer() {
        guard let player else { return }
        isPlaying = player.timeControlStatus == .playing
        isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        currentTime = max(0, player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0)
        refreshDurationAndBuffer()
    }

    private func refreshDurationAndBuffer() {
        guard let item = player?.currentItem else { return }
        let total = item.duration.seconds
        duration = total.isFinite && total > 0 ? total : 0

        guard duration > 0, let range = item.loadedTimeRanges.first?.timeRangeValue else {
            bufferedProgress = 0
            return
        }

        let buffered = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration)
        bufferedProgress = min(max(buffered / duration, 0), 1)
    }

    private func clearObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        timeControlObserver?.invalidate()
        itemStatusObserver?.invalidate()
        loadedRangesObserver?.invalidate()
        timeControlObserver = nil
        itemStatusObserver = nil
        loadedRangesObserver = nil
    }
}

@available(watchOS 9.0, *)
public struct WatchPlayerView<Overlay: View>: View {
    public let player: AVPlayer
    public let playbackRate: Float
    public let sourceLabel: String
    public let isMuted: Bool
    public let danmakuEnabled: Bool
    public let onCycleRate: () -> Void
    public let onToggleDanmaku: () -> Void
    public let onSwitchSource: () -> Void
    public let onToggleMute: () -> Void
    public let onRestart: () -> Void
    public let overlay: () -> Overlay

    @StateObject private var engine = WatchPlayerEngine()
    @State private var controlsVisible = true
    @State private var crownValue: Double = 0
    @State private var lastCrownValue: Double = 0
    @State private var isDraggingSeek = false
    @State private var hideTask: Task<Void, Never>?

    public init(
        player: AVPlayer,
        playbackRate: Float,
        sourceLabel: String,
        isMuted: Bool,
        danmakuEnabled: Bool,
        onCycleRate: @escaping () -> Void,
        onToggleDanmaku: @escaping () -> Void,
        onSwitchSource: @escaping () -> Void,
        onToggleMute: @escaping () -> Void,
        onRestart: @escaping () -> Void,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.player = player
        self.playbackRate = playbackRate
        self.sourceLabel = sourceLabel
        self.isMuted = isMuted
        self.danmakuEnabled = danmakuEnabled
        self.onCycleRate = onCycleRate
        self.onToggleDanmaku = onToggleDanmaku
        self.onSwitchSource = onSwitchSource
        self.onToggleMute = onToggleMute
        self.onRestart = onRestart
        self.overlay = overlay
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            #if canImport(AVKit)
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            #else
            Color.black
            #endif

            overlay()
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    controlsVisible.toggle()
                    if controlsVisible {
                        scheduleAutoHide()
                    }
                }

            if engine.isBuffering {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.85)
                    .padding(.bottom, 48)
            }

            if controlsVisible {
                controlsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.black)
        .animation(.easeInOut(duration: 0.2), value: controlsVisible)
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: -5000,
            through: 5000,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { newValue in
            let delta = newValue - lastCrownValue
            lastCrownValue = newValue
            guard abs(delta) > 0.01 else { return }
            engine.scrubByCrownDelta(delta)
            controlsVisible = true
            scheduleAutoHide()
        }
        .onAppear {
            engine.bind(player: player)
            scheduleAutoHide()
        }
        .onChange(of: sourceLabel) { _ in
            // Source switch in host view usually creates a new AVPlayer.
            engine.bind(player: player)
            scheduleAutoHide()
        }
        .onChange(of: engine.isPlaying) { isPlaying in
            if isPlaying {
                scheduleAutoHide()
            } else {
                hideTask?.cancel()
                controlsVisible = true
            }
        }
        .onDisappear {
            hideTask?.cancel()
        }
    }

    private var controlsPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    engine.togglePlayPause()
                    feedback()
                    scheduleAutoHide()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                }

                Spacer()

                Button {
                    controlsVisible = false
                    hideTask?.cancel()
                } label: {
                    Image(systemName: "chevron.down.circle")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)

            HStack {
                Text(timeText(engine.currentTime))
                Spacer()
                Text(timeText(engine.duration))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 6) {
                Button { engine.skip(by: -10); scheduleAutoHide() } label: {
                    Image(systemName: "gobackward.10")
                }
                Button { onCycleRate(); scheduleAutoHide() } label: {
                    Text(String(format: "%.2gx", playbackRate))
                        .font(.system(size: 9, weight: .semibold))
                }
                Button { onToggleDanmaku(); scheduleAutoHide() } label: {
                    Image(systemName: danmakuEnabled ? "text.bubble.fill" : "text.bubble")
                }
                Button { engine.skip(by: 10); scheduleAutoHide() } label: {
                    Image(systemName: "goforward.10")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)

            HStack(spacing: 6) {
                Button { onSwitchSource(); scheduleAutoHide() } label: {
                    Text(sourceLabel)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                }
                Button { onToggleMute(); scheduleAutoHide() } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                Button { onRestart(); scheduleAutoHide() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)

            timelineBar
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private var timelineBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let duration = max(engine.duration, 0.001)
            let progress = min(max(engine.currentTime / duration, 0), 1)
            let buffered = engine.bufferedProgress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(height: 3)
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: width * buffered, height: 3)
                Capsule()
                    .fill(.red)
                    .frame(width: width * progress, height: 3)
                Circle()
                    .fill(.white)
                    .frame(width: isDraggingSeek ? 12 : 8, height: isDraggingSeek ? 12 : 8)
                    .offset(x: max(0, width * progress - (isDraggingSeek ? 6 : 4)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingSeek = true
                        controlsVisible = true
                        hideTask?.cancel()
                        let fraction = min(max(value.location.x / max(width, 1), 0), 1)
                        engine.seek(progress: fraction)
                    }
                    .onEnded { _ in
                        isDraggingSeek = false
                        scheduleAutoHide()
                    }
            )
        }
        .frame(height: 14)
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard engine.isPlaying, !isDraggingSeek else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }

    private func timeText(_ seconds: Double) -> String {
        let safe = max(Int(seconds), 0)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }

    private func feedback() {
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
}
