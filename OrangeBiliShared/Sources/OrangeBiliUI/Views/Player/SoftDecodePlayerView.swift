import SwiftUI
#if os(watchOS)
import AVFoundation
import OrangeBiliCore
import WatchDecodeCore
#endif

/// FFmpeg software-decode player backend (watchOS only).
/// Moved from Debug/WatchSoftDecodePoCView — now a first-class player backend.
public struct SoftDecodePlayerView: View {
    #if os(watchOS)
    @EnvironmentObject private var render: RenderSettings
    private let sourceURL: URL?
    private let decodeURLOverride: URL?
    private let externalPlayer: AVPlayer?
    private let externalPlayerID: ObjectIdentifier?
    private let requestHeaders: [String: String]
    private let danmakuViewModel: DanmakuViewModel?
    private let playerViewModel: PlayerViewModel?
    @State private var player: AVPlayer?
    @State private var ownsPlayer = false
    @State private var timeObserver: Any?
    @State private var decodeTimer: Timer?
    @State private var decoder: UnsafeMutableRawPointer?
    @State private var decoderInputURL: String?
    @State private var decodeQueue = DispatchQueue(label: "com.orangebili.watchdecode", qos: .userInitiated)
    @State private var isDecoding = false
    @State private var decodeMissCount = 0
    @State private var lastDecodeRequestTime: Double = -1
    @State private var frame: CGImage?
    @State private var renderSize: CGSize = .zero
    @State private var videoAspect: CGFloat = 16.0 / 9.0
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var progress: Double = 0
    @State private var showControls = true
    @State private var isSeeking = false
    @State private var crownValue: Double = 0
    @State private var lastCrownValue: Double = 0
    @State private var hideTask: Task<Void, Never>?
    #endif

    #if os(watchOS)
    public init(
        url: URL,
        headers: [String: String] = [:],
        danmakuViewModel: DanmakuViewModel? = nil,
        playerViewModel: PlayerViewModel? = nil
    ) {
        self.sourceURL = url
        self.decodeURLOverride = nil
        self.externalPlayer = nil
        self.externalPlayerID = nil
        self.requestHeaders = headers
        self.danmakuViewModel = danmakuViewModel
        self.playerViewModel = playerViewModel
    }

    public init(
        player: AVPlayer,
        decodeURL: URL? = nil,
        headers: [String: String] = [:],
        danmakuViewModel: DanmakuViewModel? = nil,
        playerViewModel: PlayerViewModel? = nil
    ) {
        self.sourceURL = nil
        self.decodeURLOverride = decodeURL
        self.externalPlayer = player
        self.externalPlayerID = ObjectIdentifier(player)
        self.requestHeaders = headers
        self.danmakuViewModel = danmakuViewModel
        self.playerViewModel = playerViewModel
    }
    #else
    public init(url: URL, headers: [String: String] = [:], danmakuViewModel: Any? = nil, playerViewModel: Any? = nil) {}
    public init(player: Any, decodeURL: URL? = nil, headers: [String: String] = [:], danmakuViewModel: Any? = nil, playerViewModel: Any? = nil) {}
    #endif

    public var body: some View {
        #if os(watchOS)
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let frame {
                    Image(decorative: frame, scale: 1.0)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }

                if let danmakuViewModel, let playerViewModel {
                    DanmakuOverlayView(viewModel: danmakuViewModel, playerViewModel: playerViewModel)
                        .allowsHitTesting(false)
                }

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showControls.toggle()
                        if showControls { scheduleAutoHide() }
                    }

                if showControls {
                    controlsOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .onAppear { renderSize = geo.size }
            .onChange(of: geo.size) { newValue in renderSize = newValue }
        }
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: -10000,
            through: 10000,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { newValue in
            let delta = newValue - lastCrownValue
            lastCrownValue = newValue
            // Crown delta can be very small on watch; keep threshold low.
            guard abs(delta) > 0.001 else { return }
            if showControls {
                let sensitivity: Float = 0.08
                let current = player?.volume ?? 1
                let value = min(max(current + Float(delta) * sensitivity, 0), 1)
                player?.volume = value
                if value > 0 { player?.isMuted = false }
            } else {
                seekBy(seconds: delta * 1.2, revealControls: false)
            }
        }
        .onAppear {
            setupPlayerIfNeeded()
            updateVideoAspectIfNeeded()
            openDecoderIfNeeded()
            attachTimeObserverIfNeeded()
            startDecodeLoop()
            play()
        }
        .onChange(of: externalPlayerID) { _ in
            rebindExternalPlayerIfNeeded()
        }
        .onChange(of: playerViewModel?.currentVideoStreamURL) { _ in
            openDecoderIfNeeded()
            renderOnePoCFrame()
        }
        .onDisappear {
            hideTask?.cancel()
            stopDecodeLoop()
            detachTimeObserver()
            if ownsPlayer { player?.pause() }
            closeDecoder()
        }
        #else
        Text("watchOS only")
        #endif
    }

    // MARK: - Controls overlay

    #if os(watchOS)
    @ViewBuilder
    private var controlsOverlay: some View {
        if let playerViewModel {
            // Production path: use shared PlayerControlsPanel with custom seek bar
            PlayerControlsPanel(
                viewModel: playerViewModel,
                isPlaying: isPlaying,
                onTogglePlayback: { togglePlayPause() },
                onHide: { showControls = false }
            ) {
                seekBarAndTime
            }
            .controlsPanelChrome()
            .onAppear { scheduleAutoHide() }
        } else {
            // Standalone/debug path: simple inline controls
            standaloneControls
                .onAppear { scheduleAutoHide() }
        }
    }

    /// Seek bar + time display — unique to soft decode (renders frames on seek).
    private var seekBarAndTime: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25)).frame(height: 3)
                    Capsule().fill(.red).frame(width: width * progress, height: 3)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let player else { return }
                            if !isSeeking {
                                isSeeking = true
                                pauseForManualSeek()
                            }
                            let p = min(max(value.location.x / max(width, 1), 0), 1)
                            progress = p
                            let target = CMTime(seconds: p * max(duration, 0), preferredTimescale: 600)
                            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                            currentTime = p * duration
                            renderOnePoCFrame(at: currentTime)
                        }
                        .onEnded { _ in
                            isSeeking = false
                            showControls = true
                        }
                )
            }
            .frame(height: 14)

            ZStack {
                Text(formatTime(currentTime))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("-" + formatTime(max(duration - currentTime, 0)))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.white.opacity(0.8))
        }
    }

    /// Standalone controls for debug/probe usage (no PlayerViewModel).
    private var standaloneControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button { togglePlayPause() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                Spacer()
                Button { showControls = false } label: {
                    Image(systemName: "chevron.down.circle")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)

            seekBarAndTime

            HStack(spacing: 6) {
                Button { seekBy(seconds: -10) } label: {
                    Image(systemName: "gobackward.10")
                }
                Button { cyclePlaybackRateStandalone() } label: {
                    Text(String(format: "%.2gx", player?.rate ?? 1.0))
                        .font(.system(size: 9, weight: .semibold))
                }
                Button { seekBy(seconds: 10) } label: {
                    Image(systemName: "goforward.10")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)

            HStack(spacing: 6) {
                Button { toggleMute() } label: {
                    Image(systemName: (player?.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                Button { seekBy(seconds: -currentTime) } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    // MARK: - Player setup & lifecycle

    private func setupPlayerIfNeeded() {
        guard player == nil else { return }
        if let externalPlayer {
            player = externalPlayer
            ownsPlayer = false
            print("[SoftDecodePlayer] using external player")
            return
        }
        guard let sourceURL else { return }
        let p = AVPlayer(url: sourceURL)
        player = p
        ownsPlayer = true
        print("[SoftDecodePlayer] created local player for \(sourceURL.lastPathComponent)")
    }

    private func attachTimeObserverIfNeeded() {
        guard timeObserver == nil, let player else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isSeeking else { return }
            currentTime = time.seconds
            let d = player.currentItem?.duration.seconds ?? .nan
            duration = (d.isFinite && d > 0) ? d : 0
            if duration > 0 {
                progress = min(max(currentTime / duration, 0), 1)
            }
            updateVideoAspectIfNeeded()
        }
    }

    private func play() {
        guard let player else { return }
        player.play()
        startDecodeLoop()
        scheduleAutoHide()
    }

    private func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            stopDecodeLoop()
            showControls = true
            hideTask?.cancel()
        } else {
            player.play()
            startDecodeLoop()
            scheduleAutoHide()
        }
    }

    private func seekBy(seconds: Double, revealControls: Bool = true) {
        guard let player else { return }
        pauseForManualSeek()
        let base = player.currentTime().seconds
        let target = max(0, min(base + seconds, max(duration, 0)))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        renderOnePoCFrame(at: target)
        if revealControls {
            showControls = true
        }
    }

    private var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }

    private func cyclePlaybackRateStandalone() {
        let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
        let current = player?.rate == 0 ? 1.0 : (player?.rate ?? 1.0)
        let idx = speeds.firstIndex(where: { abs($0 - current) < 0.001 }) ?? 1
        let next = speeds[(idx + 1) % speeds.count]
        if isPlaying { player?.rate = next }
    }

    private func toggleMute() {
        guard let player else { return }
        player.isMuted.toggle()
    }

    private func pauseForManualSeek() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        }
        stopDecodeLoop()
        hideTask?.cancel()
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard isPlaying else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            showControls = false
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    // MARK: - Decode loop

    private func startDecodeLoop() {
        if decodeTimer != nil { return }
        decodeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { _ in
            renderOnePoCFrame()
        }
        decodeTimer?.tolerance = 1.0 / 240.0
    }

    private func stopDecodeLoop() {
        decodeTimer?.invalidate()
        decodeTimer = nil
    }

    private func detachTimeObserver() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func renderOnePoCFrame(at requestedTime: Double? = nil) {
        guard let player else { return }
        guard let decoder else {
            openDecoderIfNeeded()
            return
        }
        guard !isDecoding else { return }

        let t = requestedTime ?? player.currentTime().seconds
        guard t.isFinite else { return }
        guard renderSize.width > 1, renderSize.height > 1 else { return }
        if requestedTime == nil, abs(t - lastDecodeRequestTime) < (1.0 / 120.0) {
            return
        }
        lastDecodeRequestTime = t

        let (pixelWidth, pixelHeight) = decodeTargetSize()
        isDecoding = true
        decodeQueue.async {
            let raw = wdc_decoder_decode_at_time(
                decoder,
                t,
                Int32(pixelWidth),
                Int32(pixelHeight)
            )

            guard let raw else {
                DispatchQueue.main.async {
                    decodeMissCount += 1
                    if decodeMissCount == 1 || decodeMissCount % 30 == 0 {
                        print("[SoftDecodePlayer] decode miss t=\(String(format: "%.2f", t)) miss=\(decodeMissCount)")
                    }
                    if decodeMissCount >= 120 {
                        print("[SoftDecodePlayer] decoder stalled, reopening...")
                        closeDecoder()
                        openDecoderIfNeeded()
                        decodeMissCount = 0
                    }
                    isDecoding = false
                }
                return
            }

            guard let rgba = raw.pointee.rgba else {
                wdc_free_frame(raw)
                DispatchQueue.main.async { isDecoding = false }
                return
            }

            let count = Int(raw.pointee.bytes_per_row * raw.pointee.height)
            guard let provider = CGDataProvider(
                dataInfo: UnsafeMutableRawPointer(raw),
                data: UnsafeRawPointer(rgba),
                size: count,
                releaseData: { info, _, _ in
                    guard let info else { return }
                    wdc_free_frame(info.assumingMemoryBound(to: wdc_frame.self))
                }
            ) else {
                wdc_free_frame(raw)
                DispatchQueue.main.async { isDecoding = false }
                return
            }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
            guard let cg = CGImage(
                width: Int(raw.pointee.width),
                height: Int(raw.pointee.height),
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: Int(raw.pointee.bytes_per_row),
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            ) else {
                DispatchQueue.main.async { isDecoding = false }
                return
            }

            DispatchQueue.main.async {
                decodeMissCount = 0
                frame = cg
                isDecoding = false
            }
        }
    }

    // MARK: - Decoder management

    private func openDecoderIfNeeded() {
        let url = sourceURL
            ?? decodeURLOverride
            ?? (player?.currentItem?.asset as? AVURLAsset)?.url
            ?? (externalPlayer?.currentItem?.asset as? AVURLAsset)?.url
        guard let url else {
            print("[SoftDecodePlayer] decoder open skipped: no URL")
            return
        }

        let input = url.isFileURL ? url.path : url.absoluteString
        if decoder != nil, decoderInputURL == input {
            return
        }
        if decoder != nil {
            closeDecoder()
        }
        let ua = requestHeaders["User-Agent"] ?? requestHeaders["user-agent"]
            ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        let referer = requestHeaders["Referer"] ?? requestHeaders["referer"] ?? "https://www.bilibili.com/"
        let cookie = requestHeaders["Cookie"] ?? requestHeaders["cookie"] ?? ""
        print("[SoftDecodePlayer] open decoder headers ua=\(!ua.isEmpty) referer=\(!referer.isEmpty) cookie=\(!cookie.isEmpty)")
        decoder = input.withCString { cUrl in
            ua.withCString { cUA in
                referer.withCString { cRef in
                    cookie.withCString { cCookie in
                        wdc_decoder_open_with_options(cUrl, cUA, cRef, cCookie)
                    }
                }
            }
        }
        if decoder == nil {
            print("[SoftDecodePlayer] decoder open failed: \(input)")
        } else {
            decoderInputURL = input
            print("[SoftDecodePlayer] decoder opened: \(url.absoluteString)")
        }
    }

    private func closeDecoder() {
        guard let decoder else { return }
        wdc_decoder_close(decoder)
        self.decoder = nil
        decoderInputURL = nil
        isDecoding = false
        lastDecodeRequestTime = -1
        print("[SoftDecodePlayer] decoder closed")
    }

    private func rebindExternalPlayerIfNeeded() {
        guard let externalPlayer else { return }
        guard player !== externalPlayer else { return }

        // Source switch may replace AVPlayer instance; ensure we stop old decode/audio and follow the new player.
        stopDecodeLoop()
        detachTimeObserver()
        player?.pause()
        closeDecoder()

        player = externalPlayer
        ownsPlayer = false
        frame = nil
        decodeMissCount = 0
        lastDecodeRequestTime = -1

        updateVideoAspectIfNeeded()
        openDecoderIfNeeded()
        attachTimeObserverIfNeeded()
        renderOnePoCFrame()
        if externalPlayer.timeControlStatus == .playing {
            startDecodeLoop()
        }
        print("[SoftDecodePlayer] rebound to new external player")
    }

    private func updateVideoAspectIfNeeded() {
        if let info = playerViewModel?.videoFormatInfo, info.width > 0, info.height > 0 {
            videoAspect = max(CGFloat(info.width) / CGFloat(info.height), 0.1)
            return
        }
        if let track = player?.currentItem?.asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            let w = abs(size.width)
            let h = abs(size.height)
            if w > 1, h > 1 {
                videoAspect = max(w / h, 0.1)
            }
        }
    }

    private func decodeTargetSize() -> (Int, Int) {
        let prefers720 = render.preferredQuality >= 64
        let scale: CGFloat = prefers720 ? 3.0 : 2.0
        let maxW = max(Int(renderSize.width * scale), 2)
        let maxH = max(Int(renderSize.height * scale), 2)
        let maxDecodeH = prefers720 ? 720 : 480

        var outW = maxW
        var outH = maxH
        if CGFloat(maxW) / CGFloat(maxH) > videoAspect {
            outH = maxH
            outW = max(Int(CGFloat(outH) * videoAspect), 2)
        } else {
            outW = maxW
            outH = max(Int(CGFloat(outW) / videoAspect), 2)
        }

        if outH > maxDecodeH {
            outH = maxDecodeH
            outW = max(Int(CGFloat(outH) * videoAspect), 2)
        }

        // swscale works best with even dimensions for YUV inputs.
        outW = max((outW / 2) * 2, 2)
        outH = max((outH / 2) * 2, 2)
        return (outW, outH)
    }
    #endif
}
