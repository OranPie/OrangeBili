import SwiftUI
import AVFoundation
import Accelerate
import SpriteKit
#if canImport(WatchKit)
import WatchKit
#endif
private enum WatchCustomPlayerLog {
    static let enabled = true

    static func debug(_ message: String) {
        guard enabled else { return }
        print("[WatchCustomPlayer] \(message)")
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%d:%02d", m, s)
}

final class FrameConverter {
    private var destBuffer: vImage_Buffer
    private let destFormat: vImage_CGImageFormat

    init(targetWidth: Int, targetHeight: Int) {
        let width = Swift.max(targetWidth, 1)
        let height = Swift.max(targetHeight, 1)

        destFormat = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
                    CGImageAlphaInfo.premultipliedFirst.rawValue
            )
        )!

        destBuffer = vImage_Buffer()
        vImageBuffer_Init(
            &destBuffer,
            vImagePixelCount(height),
            vImagePixelCount(width),
            32,
            vImage_Flags(kvImageNoFlags)
        )
    }

    deinit {
        free(destBuffer.data)
    }

    func convert(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        var src = vImage_Buffer(
            data: base,
            height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)),
            width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)),
            rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
        )

        let err = vImageScale_ARGB8888(&src, &destBuffer, nil, vImage_Flags(kvImageNoFlags))
        guard err == kvImageNoError else { return nil }

        return try? destBuffer.createCGImage(format: destFormat)
    }

    func convert(_ cgImage: CGImage) -> CGImage? {
        var srcBuffer = vImage_Buffer()
        var srcFormat = destFormat

        let initErr = vImageBuffer_InitWithCGImage(
            &srcBuffer,
            &srcFormat,
            nil,
            cgImage,
            vImage_Flags(kvImageNoFlags)
        )
        guard initErr == kvImageNoError else { return nil }
        defer { free(srcBuffer.data) }

        let scaleErr = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(kvImageNoFlags))
        guard scaleErr == kvImageNoError else { return nil }

        return try? destBuffer.createCGImage(format: destFormat)
    }
}

public enum PlayerState: Equatable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case ended
    case error(String)
}

@available(watchOS 9.0, *)
public final class WatchVideoScene: SKScene {
    private let player: AVPlayer
    private let videoNode: SKVideoNode
    private let debugProbeNode = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 3)

    init(player: AVPlayer) {
        self.player = player
        videoNode = SKVideoNode(avPlayer: player)
        super.init(size: .zero)
        scaleMode = .resizeFill
        backgroundColor = .black
        videoNode.yScale = -1
        videoNode.zPosition = 1
        addChild(videoNode)

        // Rendering probe: if this node animates but video stays black, SKVideoNode is the failing layer.
        debugProbeNode.fillColor = .red
        debugProbeNode.strokeColor = .clear
        debugProbeNode.zPosition = 999
        addChild(debugProbeNode)
        let move = SKAction.sequence([
            SKAction.moveBy(x: 30, y: 0, duration: 0.8),
            SKAction.moveBy(x: -30, y: 0, duration: 0.8)
        ])
        debugProbeNode.run(SKAction.repeatForever(move))
        WatchCustomPlayerLog.debug("scene.init probe node attached")
    }

    required init?(coder: NSCoder) {
        return nil
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutVideo()
    }

    private func layoutVideo() {
        videoNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        videoNode.size = size
        debugProbeNode.position = CGPoint(x: 18, y: size.height - 18)
        WatchCustomPlayerLog.debug("scene.layout size=\(size.width)x\(size.height)")
    }

    func setRenderSize(_ renderSize: CGSize) {
        guard renderSize.width > 0, renderSize.height > 0 else { return }
        if size != renderSize {
            size = renderSize
            WatchCustomPlayerLog.debug("scene.setRenderSize -> \(renderSize.width)x\(renderSize.height)")
        }
        layoutVideo()
    }

    func syncPlayback(isPlaying: Bool) {
        isPaused = false
        if isPlaying {
            videoNode.play()
            WatchCustomPlayerLog.debug("scene.syncPlayback PLAY")
        } else {
            videoNode.pause()
            WatchCustomPlayerLog.debug("scene.syncPlayback PAUSE")
        }
    }
}

@available(watchOS 9.0, *)
public final class WatchPlayerVM: ObservableObject {
    @Published public var state: PlayerState = .idle
    @Published public var progress: Double = 0
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var showControls: Bool = true
    @Published public var bufferProgress: Double = 0

    public let player: AVPlayer
    let scene: WatchVideoScene
    private var isSeeking = false

    private var periodicObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var accessLogObserver: NSObjectProtocol?
    private var errorLogObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?
    private var keepUpObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var bufferFullObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var presentationSizeObservation: NSKeyValueObservation?

    private var hideTask: Task<Void, Never>?
    private let fps: Double
    private var lastLoggedSecond: Int = -1
    private let debugID = UUID().uuidString.prefix(8)

    public init(url: URL, fps: Double = 20) {
        self.fps = fps
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        scene = WatchVideoScene(player: player)
        player.automaticallyWaitsToMinimizeStalling = true
        WatchCustomPlayerLog.debug("vm[\(debugID)] init(url:) \(url.absoluteString)")

        configureAudioSession()
        setupObservers()
    }

    public init(player: AVPlayer, fps: Double = 20) {
        self.fps = fps
        self.player = player
        scene = WatchVideoScene(player: player)
        player.automaticallyWaitsToMinimizeStalling = true
        WatchCustomPlayerLog.debug("vm[\(debugID)] init(player:) reused external player")

        configureAudioSession()
        setupObservers()
    }

    deinit {
        WatchCustomPlayerLog.debug("vm[\(debugID)] deinit")
        hideTask?.cancel()
        if let t = periodicObserver { player.removeTimeObserver(t) }
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
        if let e = accessLogObserver { NotificationCenter.default.removeObserver(e) }
        if let e = errorLogObserver { NotificationCenter.default.removeObserver(e) }
        statusObservation?.invalidate()
        bufferObservation?.invalidate()
        keepUpObservation?.invalidate()
        bufferEmptyObservation?.invalidate()
        bufferFullObservation?.invalidate()
        timeControlObservation?.invalidate()
        presentationSizeObservation?.invalidate()
    }

    public func configure(renderSize: CGSize) {
        WatchCustomPlayerLog.debug("vm.configure renderSize=\(renderSize.width)x\(renderSize.height)")
        scene.setRenderSize(renderSize)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            print("[WatchCustomPlayer] Audio session error: \(error)")
        }
    }

    private func setupObservers() {
        WatchCustomPlayerLog.debug("vm[\(debugID)] setupObservers")
        state = .loading

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        periodicObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self, !self.isSeeking else { return }
            self.currentTime = time.seconds
            if self.duration > 0 {
                self.progress = (time.seconds / self.duration).clamped(to: 0...1)
            }
            WatchCustomPlayerLog.debug(
                "vm[\(self.debugID)] periodic t=\(String(format: "%.2f", self.currentTime)) rate=\(self.player.rate)"
            )
            let whole = Int(self.currentTime)
            if whole != self.lastLoggedSecond {
                self.lastLoggedSecond = whole
                let keepUp = self.player.currentItem?.isPlaybackLikelyToKeepUp ?? false
                let bufferEmpty = self.player.currentItem?.isPlaybackBufferEmpty ?? false
                let bufferFull = self.player.currentItem?.isPlaybackBufferFull ?? false
                WatchCustomPlayerLog.debug(
                    "vm[\(self.debugID)] tick t=\(String(format: "%.2f", self.currentTime)) dur=\(String(format: "%.2f", self.duration)) progress=\(String(format: "%.3f", self.progress)) keepUp=\(keepUp) empty=\(bufferEmpty) full=\(bufferFull)"
                )
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            WatchCustomPlayerLog.debug("item.didPlayToEnd")
            self?.onPlaybackEnded()
        }

        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.logLatestAccess()
        }

        errorLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.logLatestError()
        }

        statusObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    WatchCustomPlayerLog.debug("item.status=readyToPlay")
                    WatchCustomPlayerLog.debug("item.presentationSize(initial)=\(item.presentationSize.width)x\(item.presentationSize.height)")
                    if let dur = item.duration.seconds.finiteOrNil {
                        self.duration = dur
                    }
                    if self.state == .loading {
                        self.state = .readyToPlay
                    }
                case .failed:
                    WatchCustomPlayerLog.debug("item.status=failed err=\(item.error?.localizedDescription ?? "nil")")
                    self.state = .error(item.error?.localizedDescription ?? "Unknown error")
                default:
                    WatchCustomPlayerLog.debug("item.status=unknown")
                    break
                }
            }
        }

        bufferObservation = player.currentItem?.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, self.duration > 0,
                      let range = item.loadedTimeRanges.first?.timeRangeValue
                else { return }
                let buffered = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration)
                self.bufferProgress = (buffered / self.duration).clamped(to: 0...1)
                let segments = item.loadedTimeRanges.compactMap { value -> String? in
                    let r = value.timeRangeValue
                    let start = CMTimeGetSeconds(r.start)
                    let dur = CMTimeGetSeconds(r.duration)
                    guard start.isFinite, dur.isFinite else { return nil }
                    return String(format: "[%.2f,+%.2f]", start, dur)
                }.joined(separator: ",")
                WatchCustomPlayerLog.debug("buffer progress=\(String(format: "%.3f", self.bufferProgress)) ranges=\(segments)")
            }
        }

        keepUpObservation = player.currentItem?.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                WatchCustomPlayerLog.debug("item.keepUp=\(item.isPlaybackLikelyToKeepUp)")
            }
        }

        bufferEmptyObservation = player.currentItem?.observe(\.isPlaybackBufferEmpty, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                WatchCustomPlayerLog.debug("item.bufferEmpty=\(item.isPlaybackBufferEmpty)")
            }
        }

        bufferFullObservation = player.currentItem?.observe(\.isPlaybackBufferFull, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                WatchCustomPlayerLog.debug("item.bufferFull=\(item.isPlaybackBufferFull)")
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let reason = player.reasonForWaitingToPlay?.rawValue ?? "none"
                WatchCustomPlayerLog.debug("timeControl=\(player.timeControlStatus.rawValue) rate=\(player.rate) waiting=\(reason)")
                let isPlaying = player.timeControlStatus == .playing || player.rate > 0
                self.scene.syncPlayback(isPlaying: isPlaying)
            }
        }

        presentationSizeObservation = player.currentItem?.observe(\.presentationSize, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                WatchCustomPlayerLog.debug("item.presentationSize(update)=\(item.presentationSize.width)x\(item.presentationSize.height)")
            }
        }
    }

    public func play() {
        WatchCustomPlayerLog.debug("action.play")
        player.play()
        scene.syncPlayback(isPlaying: true)
        state = .playing
        scheduleAutoHide()
    }

    public func pause() {
        WatchCustomPlayerLog.debug("action.pause")
        player.pause()
        scene.syncPlayback(isPlaying: false)
        state = .paused
        showControls = true
    }

    public func togglePlay() {
        switch state {
        case .playing:
            pause()
        case .ended:
            replay()
        case .readyToPlay, .paused:
            play()
        default:
            break
        }
    }

    public func replay() {
        WatchCustomPlayerLog.debug("action.replay")
        player.seek(to: .zero) { [weak self] _ in
            self?.play()
        }
        progress = 0
        currentTime = 0
    }

    public func skip(_ seconds: Double) {
        WatchCustomPlayerLog.debug("action.skip \(seconds)")
        let current = player.currentTime()
        let target = CMTimeAdd(current, CMTime(seconds: seconds, preferredTimescale: 600))
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func onPlaybackEnded() {
        scene.syncPlayback(isPlaying: false)
        state = .ended
        showControls = true
    }

    public func beginSeeking() {
        isSeeking = true
    }

    public func updateSeek(to fraction: Double) {
        let clamped = fraction.clamped(to: 0...1)
        progress = clamped
        currentTime = clamped * duration
    }

    public func endSeeking() {
        guard duration > 0 else { isSeeking = false; return }
        WatchCustomPlayerLog.debug("seek.end progress=\(String(format: "%.3f", progress))")
        let target = CMTime(seconds: progress * duration, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async { self?.isSeeking = false }
        }
    }

    public func crownSeek(delta: Double) {
        guard duration > 0 else { return }
        WatchCustomPlayerLog.debug("seek.crown delta=\(String(format: "%.4f", delta))")
        let sensitivity: Double = 0.002
        let newProgress = (progress + delta * sensitivity).clamped(to: 0...1)
        isSeeking = true
        progress = newProgress
        currentTime = newProgress * duration
        let target = CMTime(seconds: currentTime, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async { self?.isSeeking = false }
        }
    }

    public func toggleControls() {
        showControls.toggle()
        if showControls { scheduleAutoHide() }
    }

    public func scheduleAutoHide() {
        hideTask?.cancel()
        guard state == .playing else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self.showControls = false
        }
    }

    private func logLatestAccess() {
        guard let event = player.currentItem?.accessLog()?.events.last else {
            WatchCustomPlayerLog.debug("accessLog: no events")
            return
        }
        WatchCustomPlayerLog.debug(
            "access uri=\(event.uri ?? "nil") observedBitrate=\(Int(event.observedBitrate)) indicatedBitrate=\(Int(event.indicatedBitrate)) stalls=\(event.numberOfStalls) startup=\(String(format: "%.3f", event.startupTime)) transferMs=\(String(format: "%.1f", event.transferDuration)) server=\(event.serverAddress ?? "nil")"
        )
    }

    private func logLatestError() {
        guard let event = player.currentItem?.errorLog()?.events.last else {
            WatchCustomPlayerLog.debug("errorLog: no events")
            return
        }
        WatchCustomPlayerLog.debug(
            "errorLog domain=\(event.errorDomain) code=\(event.errorStatusCode) comment=\(event.errorComment ?? "nil") uri=\(event.uri ?? "nil") server=\(event.serverAddress ?? "nil")"
        )
    }
}

private extension Double {
    var finiteOrNil: Double? { isFinite ? self : nil }
}

@available(watchOS 9.0, *)
public struct VideoCanvas: View {
    let scene: WatchVideoScene

    public init(scene: WatchVideoScene) {
        self.scene = scene
    }

    public var body: some View {
        GeometryReader { geo in
            SpriteView(scene: scene)
                .background(Color.black)
                .onAppear {
                    WatchCustomPlayerLog.debug("canvas.onAppear size=\(geo.size.width)x\(geo.size.height)")
                    scene.setRenderSize(geo.size)
                }
                .onChange(of: geo.size) { newSize in
                    WatchCustomPlayerLog.debug("canvas.onChange size=\(newSize.width)x\(newSize.height)")
                    scene.setRenderSize(newSize)
                }
        }
    }
}

@available(watchOS 9.0, *)
public struct CustomProgressBar: View {
    @Binding var progress: Double
    var bufferProgress: Double
    var onBegin: () -> Void
    var onChange: (Double) -> Void
    var onEnd: () -> Void

    @State private var isDragging = false

    public init(
        progress: Binding<Double>,
        bufferProgress: Double = 0,
        onBegin: @escaping () -> Void = {},
        onChange: @escaping (Double) -> Void = { _ in },
        onEnd: @escaping () -> Void = {}
    ) {
        _progress = progress
        self.bufferProgress = bufferProgress
        self.onBegin = onBegin
        self.onChange = onChange
        self.onEnd = onEnd
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: max(0, width * bufferProgress), height: 3)
                Capsule()
                    .fill(Color.red)
                    .frame(width: max(0, width * progress), height: 3)
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 14 : 8, height: isDragging ? 14 : 8)
                    .offset(x: max(0, width * progress - (isDragging ? 7 : 4)))
                    .animation(.easeOut(duration: 0.12), value: isDragging)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onBegin()
                        }
                        let fraction = (value.location.x / max(width, 1)).clamped(to: 0...1)
                        progress = fraction
                        onChange(fraction)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEnd()
                    }
            )
        }
    }
}

@available(watchOS 9.0, *)
public struct TransportControls: View {
    @ObservedObject var vm: WatchPlayerVM

    public init(vm: WatchPlayerVM) {
        self.vm = vm
    }

    public var body: some View {
        HStack(spacing: 24) {
            Button { vm.skip(-5) } label: {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

            Button { vm.togglePlay() } label: {
                Image(systemName: centerIcon)
                    .font(.system(size: 32, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

            Button { vm.skip(5) } label: {
                Image(systemName: "goforward.5")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
        }
    }

    private var centerIcon: String {
        switch vm.state {
        case .playing: return "pause.fill"
        case .ended: return "arrow.counterclockwise"
        default: return "play.fill"
        }
    }
}

@available(watchOS 9.0, *)
public struct ControlsOverlay: View {
    @ObservedObject var vm: WatchPlayerVM

    public init(vm: WatchPlayerVM) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            TransportControls(vm: vm)
                .padding(.bottom, 8)
            Spacer()
            CustomProgressBar(
                progress: $vm.progress,
                bufferProgress: vm.bufferProgress,
                onBegin: { vm.beginSeeking() },
                onChange: { vm.updateSeek(to: $0) },
                onEnd: { vm.endSeeking() }
            )
            .frame(height: 20)

            HStack {
                Text(formatTime(vm.currentTime))
                Spacer()
                Text("-" + formatTime(max(0, vm.duration - vm.currentTime)))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }
}

@available(watchOS 9.0, *)
public struct LoadingOverlay: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Loading...")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

@available(watchOS 9.0, *)
public struct ErrorOverlay: View {
    let message: String
    let onRetry: () -> Void

    public init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Button("Retry", action: onRetry)
                    .font(.caption)
            }
            .padding()
        }
    }
}

@available(watchOS 9.0, *)
public struct WatchCustomPlayerView: View {
    @StateObject private var vm: WatchPlayerVM
    @State private var crownValue: Double = 0
    @State private var lastCrownValue: Double = 0

    public init(url: URL, fps: Double = 20) {
        _vm = StateObject(wrappedValue: WatchPlayerVM(url: url, fps: fps))
    }

    public init(player: AVPlayer, fps: Double = 20) {
        _vm = StateObject(wrappedValue: WatchPlayerVM(player: player, fps: fps))
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                switch vm.state {
                case .idle, .loading:
                    LoadingOverlay()
                case .error(let msg):
                    ErrorOverlay(message: msg) { vm.replay() }
                default:
                    videoLayer
                }
            }
            .onAppear {
                #if canImport(WatchKit)
                let scale = WKInterfaceDevice.current().screenScale
                #else
                let scale: CGFloat = 1
                #endif
                vm.configure(renderSize: CGSize(
                    width: geo.size.width * scale,
                    height: geo.size.height * scale
                ))
                WatchCustomPlayerLog.debug("view.onAppear state=\(String(describing: vm.state)) size=\(geo.size.width)x\(geo.size.height) scale=\(scale)")
                if vm.state == .readyToPlay {
                    vm.play()
                }
            }
        }
        .ignoresSafeArea()
        .onDisappear {
            WatchCustomPlayerLog.debug("view.onDisappear")
            vm.pause()
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
            if abs(delta) > 0.01 {
                vm.crownSeek(delta: delta)
            }
        }
        .onChange(of: vm.state) { newState in
            if newState == .readyToPlay {
                vm.play()
            }
        }
    }

    private var videoLayer: some View {
        ZStack {
            VideoCanvas(scene: vm.scene)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { vm.toggleControls() }
            if vm.showControls {
                Color.black.opacity(0.35)
                    .allowsHitTesting(false)
                ControlsOverlay(vm: vm)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showControls)
    }
}
