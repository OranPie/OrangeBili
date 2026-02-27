import AVFoundation
import Foundation
import Combine
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(VideoToolbox)
import VideoToolbox
#endif

public struct VideoFormatInfo {
    public let codec: String
    public let codecRaw: FourCharCode
    public let width: Int
    public let height: Int
    public let bitsPerComponent: Int
    public let transferFunction: String
    public let colorPrimaries: String
    public let yCbCrMatrix: String
    public let isHDR: Bool
    public let isHEVC: Bool
    public let is10Bit: Bool
    public let hevcHWSupported: Bool
    public let allExtensions: String
    public let streamURL: String
    public let pixelFormat: String

    public var summary: String {
        "\(codec) \(width)x\(height) \(bitsPerComponent)bit pxfmt=\(pixelFormat) | transfer=\(transferFunction) primaries=\(colorPrimaries) matrix=\(yCbCrMatrix) | HDR=\(isHDR) HEVC_HW=\(hevcHWSupported) | url=\(streamURL)"
    }
}

@MainActor
public final class PlayerViewModel: ObservableObject {
    @Published public var isLoading = true
    @Published public var errorMessage: String?
    @Published public var progressSeconds: Int = 0
    @Published public private(set) var currentTime: Double = 0
    @Published public var totalDurationSeconds: Int = 0
    @Published public var playbackRate: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var sourceLabel: String = L10n.t("player.source.main")
    @Published public var colorFixActive: Bool = false
    @Published public var videoFormatInfo: VideoFormatInfo?
    @Published public private(set) var playbackRequestHeaders: [String: String] = [:]
    @Published public private(set) var currentVideoStreamURL: URL?
    @Published public var loopPlayback: Bool = false
    @Published public private(set) var didFinishPlaying: Bool = false

    public let video: BiliVideo
    public let cid: Int64
    public let localFileURL: URL?
    public var preferredQuality: Int = 32
    public var preferredCodec: PreferredCodec = .auto
    public var preferredStreamFormat: PreferredStreamFormat = .auto
    private let service: BiliServiceProtocol
    public private(set) var player: AVPlayer?
    private var observer: Any?
    private var continuousObserver: Any?
    private var streamURLs: [URL] = []
    private var streamHeaders: [String: String] = [:]
    private var currentStreamIndex = 0
    private var dashAudioURL: URL?
    private var endObserver: NSObjectProtocol?
    #if canImport(CoreImage)
    private let ciContext = CIContext()
    #endif

    public init(video: BiliVideo, cid: Int64, localFileURL: URL? = nil, service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.video = video
        self.cid = cid
        self.localFileURL = localFileURL
        self.service = service
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        if let localFileURL, FileManager.default.fileExists(atPath: localFileURL.path) {
            let player: AVPlayer
            let inspectAsset: AVURLAsset
            if let dash = Self.readLocalDASHManifest(from: localFileURL) {
                let videoAsset = AVURLAsset(url: dash.videoURL)
                inspectAsset = videoAsset
                currentVideoStreamURL = dash.videoURL
                if let audioURL = dash.audioURL {
                    let audioAsset = AVURLAsset(url: audioURL)
                    if let merged = Self.makeDASHCompositionItem(videoAsset: videoAsset, audioAsset: audioAsset) {
                        player = AVPlayer(playerItem: merged)
                    } else {
                        player = AVPlayer(playerItem: AVPlayerItem(asset: videoAsset))
                    }
                } else {
                    player = AVPlayer(playerItem: AVPlayerItem(asset: videoAsset))
                }
            } else {
                let asset = AVURLAsset(url: localFileURL)
                inspectAsset = asset
                currentVideoStreamURL = localFileURL
                player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            }
            player.isMuted = isMuted
            self.player = player
            observeProgress()
            isLoading = false
            player.playImmediately(atRate: playbackRate)
            Task {
                let info = await inspectVideoFormat(asset: inspectAsset)
                videoFormatInfo = info
                DebugLogStore.shared.log(category: "player", message: "format: \(info.summary)")
                DebugLogStore.shared.log(category: "player.ext", message: "extensions: \(info.allExtensions)")
            }
            #if canImport(CoreImage)
            Task {
                await applyColorFixIfNeeded(asset: inspectAsset, item: player.currentItem ?? AVPlayerItem(asset: inspectAsset))
            }
            #endif
            return
        }

        do {
            var headers = [
                "Referer": "https://www.bilibili.com",
                "User-Agent": PlatformInfo.userAgent
            ]
            if let session = await BiliAuthStore.shared.currentSession(),
               let cookie = Self.cookieHeader(from: session) {
                headers["Cookie"] = cookie
            }
            streamHeaders = headers
            playbackRequestHeaders = headers
            DebugLogStore.shared.log(
                category: "player.request",
                message: "headers ua=\(headers["User-Agent"] != nil) referer=\(headers["Referer"] != nil) cookie=\(headers["Cookie"] != nil)"
            )
            dashAudioURL = nil
            streamURLs = try await collectPlayableURLs()
            currentStreamIndex = 0
            sourceLabel = streamURLs.count > 1
                ? L10n.f("player.source.indexed", 1, streamURLs.count)
                : L10n.t("player.source.main")
            try prepareRemotePlayer(url: streamURLs[currentStreamIndex])
            isLoading = false
            player?.play()
            if playbackRate != 1.0 {
                player?.rate = playbackRate
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    public func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.playImmediately(atRate: playbackRate)
        }
    }

    public func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = max(0, min(seconds, Double(max(totalDurationSeconds, 1))))
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func skip(by seconds: Double) {
        seek(to: Double(progressSeconds) + seconds)
    }

    public func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.rate = playbackRate
        }
    }

    public func cyclePlaybackRate() {
        let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
        let currentIndex = speeds.firstIndex(where: { abs($0 - playbackRate) < 0.001 }) ?? 1
        let next = speeds[(currentIndex + 1) % speeds.count]
        setPlaybackRate(next)
    }

    public func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    public func restart() {
        seek(to: 0)
    }

    public func switchSource() {
        guard streamURLs.count > 1 else { return }
        let currentTime = Double(progressSeconds)
        currentStreamIndex = (currentStreamIndex + 1) % streamURLs.count
        sourceLabel = L10n.f("player.source.indexed", currentStreamIndex + 1, streamURLs.count)
        do {
            try prepareRemotePlayer(url: streamURLs[currentStreamIndex])
            seek(to: currentTime)
            player?.play()
            if playbackRate != 1.0 {
                player?.rate = playbackRate
            }
        } catch {
            errorMessage = L10n.f("player.source.switch.fail", error.localizedDescription)
        }
    }

    public func cleanup() {
        if let observer {
            player?.removeTimeObserver(observer)
            self.observer = nil
        }
        if let continuousObserver {
            player?.removeTimeObserver(continuousObserver)
            self.continuousObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        currentVideoStreamURL = nil
    }

    private func collectPlayableURLs() async throws -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        // Try preferred quality first, then fallbacks
        var qualities = [preferredQuality]
        for q in [16, 32] where !qualities.contains(q) {
            qualities.append(q)
        }
        for quality in qualities {
            if let stream = try? await service.fetchPlayURL(bvid: video.bvid, cid: cid, quality: quality, preferredCodec: preferredCodec, streamFormat: preferredStreamFormat) {
                // Capture DASH audio from the first successful stream
                if dashAudioURL == nil, let audioURL = stream.audioURL {
                    dashAudioURL = audioURL
                }
                let candidates = [stream.url] + stream.backupURLs
                for url in candidates where (url.scheme ?? "").lowercased() == "https" {
                    let key = url.absoluteString
                    if !seen.contains(key) {
                        urls.append(url)
                        seen.insert(key)
                    }
                }
            }
        }
        if urls.isEmpty {
            throw BiliError.noStream
        }
        return urls
    }

    private func prepareRemotePlayer(url: URL) throws {
        if let observer {
            player?.removeTimeObserver(observer)
            self.observer = nil
        }
        if let continuousObserver {
            player?.removeTimeObserver(continuousObserver)
            self.continuousObserver = nil
        }
        player?.pause()
        currentVideoStreamURL = url

        let videoAsset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": streamHeaders])

        let item: AVPlayerItem
        if let audioURL = dashAudioURL {
            // DASH: merge separate video + audio tracks via AVMutableComposition
            let audioAsset = AVURLAsset(url: audioURL, options: ["AVURLAssetHTTPHeaderFieldsKey": streamHeaders])
            if let compositionItem = Self.makeDASHCompositionItem(videoAsset: videoAsset, audioAsset: audioAsset) {
                item = compositionItem
            } else {
                // Fallback: video-only
                item = AVPlayerItem(asset: videoAsset)
            }
        } else {
            item = AVPlayerItem(asset: videoAsset)
        }

        item.preferredForwardBufferDuration = 2
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = isMuted
        self.player = player
        observeProgress()

        Task {
            let info = await inspectVideoFormat(asset: videoAsset)
            videoFormatInfo = info
            DebugLogStore.shared.log(category: "player", message: "format: \(info.summary)")
            DebugLogStore.shared.log(category: "player.ext", message: "extensions: \(info.allExtensions)")
        }

        #if canImport(CoreImage)
        Task {
            await applyColorFixIfNeeded(asset: videoAsset, item: item)
        }
        #endif
    }

    private nonisolated static func makeDASHCompositionItem(videoAsset: AVURLAsset, audioAsset: AVURLAsset) -> AVPlayerItem? {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }

        do {
            guard let sourceVideoTrack = videoAsset.tracks(withMediaType: .video).first,
                  let sourceAudioTrack = audioAsset.tracks(withMediaType: .audio).first else {
                return nil
            }

            let videoDuration = sourceVideoTrack.timeRange.duration
            let audioDuration = sourceAudioTrack.timeRange.duration

            let resolvedDuration: CMTime = {
                let videoValid = videoDuration.isNumeric && videoDuration.seconds > 0
                let audioValid = audioDuration.isNumeric && audioDuration.seconds > 0
                if videoValid && audioValid { return CMTimeMinimum(videoDuration, audioDuration) }
                if videoValid { return videoDuration }
                if audioValid { return audioDuration }
                return videoAsset.duration
            }()
            guard resolvedDuration.isNumeric && resolvedDuration.seconds > 0 else { return nil }
            let timeRange = CMTimeRange(start: .zero, duration: resolvedDuration)

            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
            try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
            return AVPlayerItem(asset: composition)
        } catch {
            DebugLogStore.shared.log(category: "player", message: "DASH composition failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func observeProgress() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.loopPlayback {
                    self.seek(to: 0)
                    self.player?.playImmediately(atRate: self.playbackRate)
                } else {
                    self.didFinishPlaying = true
                }
            }
        }
        observer = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            guard let self else { return }
            if let safeProgress = Self.safeIntFromDouble(time.seconds) {
                self.progressSeconds = safeProgress
            }
            let duration = self.player?.currentItem?.duration.seconds ?? .nan
            if let safeDuration = Self.safeIntFromDouble(duration), safeDuration > 0 {
                self.totalDurationSeconds = safeDuration
            }
        }
        continuousObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite {
                self.currentTime = seconds
            }
        }
    }

    #if canImport(CoreImage)
    private func applyColorFixIfNeeded(asset: AVURLAsset, item: AVPlayerItem) async {
        let needsFix = await detectProblematicFormat(asset: asset)
        guard needsFix else { return }

        let composition = try? await AVVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { [weak self] request in
                let image = request.sourceImage.clamped(to: request.sourceImage.extent)
                request.finish(with: image, context: self?.ciContext)
            }
        )
        item.videoComposition = composition
        colorFixActive = true
    }

    nonisolated private func detectProblematicFormat(asset: AVURLAsset) async -> Bool {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let descriptions = try? await track.load(.formatDescriptions),
              let desc = descriptions.first else {
            return false
        }

        let codec = CMFormatDescriptionGetMediaSubType(desc)
        let extensions = CMFormatDescriptionGetExtensions(desc) as? [String: Any] ?? [:]

        let isHEVC = codec == kCMVideoCodecType_HEVC

        let transfer = extensions["CVTransferFunction"] as? String ?? ""
        let primaries = extensions["CVColorPrimaries"] as? String ?? ""
        let isHDR = transfer.contains("HLG") || transfer.contains("PQ") ||
                    transfer.contains("2100") || primaries.contains("2020")

        let bitsPerComponent = extensions["BitsPerComponent"] as? Int ?? 8
        let is10Bit = bitsPerComponent > 8

        #if canImport(VideoToolbox)
        let hevcHWSupported = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        #else
        let hevcHWSupported = false
        #endif

        return isHDR || is10Bit || (isHEVC && !hevcHWSupported)
    }
    #endif

    nonisolated private func inspectVideoFormat(asset: AVURLAsset) async -> VideoFormatInfo {
        let urlStr = asset.url.absoluteString
        let urlSuffix = String(urlStr.prefix(120))

        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let descriptions = try? await track.load(.formatDescriptions),
              let desc = descriptions.first else {
            return VideoFormatInfo(codec: "unknown", codecRaw: 0, width: 0, height: 0, bitsPerComponent: 0, transferFunction: "", colorPrimaries: "", yCbCrMatrix: "", isHDR: false, isHEVC: false, is10Bit: false, hevcHWSupported: false, allExtensions: "", streamURL: urlSuffix, pixelFormat: "")
        }

        let codec = CMFormatDescriptionGetMediaSubType(desc)
        let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
        let extensions = CMFormatDescriptionGetExtensions(desc) as? [String: Any] ?? [:]

        let isHEVC = codec == kCMVideoCodecType_HEVC
        let isAVC = codec == kCMVideoCodecType_H264

        let codecName: String
        if isHEVC { codecName = "HEVC/H.265" }
        else if isAVC { codecName = "AVC/H.264" }
        else { codecName = String(format: "%c%c%c%c", (codec >> 24) & 0xFF, (codec >> 16) & 0xFF, (codec >> 8) & 0xFF, codec & 0xFF) }

        let transfer = extensions["CVTransferFunction"] as? String ?? ""
        let primaries = extensions["CVColorPrimaries"] as? String ?? ""
        let matrix = extensions["CVYCbCrMatrix"] as? String ?? ""
        let bitsPerComponent = extensions["BitsPerComponent"] as? Int ?? 8
        let is10Bit = bitsPerComponent > 8
        let isHDR = transfer.contains("HLG") || transfer.contains("PQ") ||
                    transfer.contains("2100") || primaries.contains("2020")

        // Extract pixel format
        let pixelFormatRaw = extensions["CVPixelFormatType"] as? Int
            ?? extensions["PixelFormatType"] as? Int ?? 0
        let pixelFormat: String
        if pixelFormatRaw > 0 {
            pixelFormat = String(format: "0x%08X (%d)", pixelFormatRaw, pixelFormatRaw)
        } else {
            pixelFormat = "–"
        }

        #if canImport(VideoToolbox)
        let hevcHW = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        #else
        let hevcHW = false
        #endif

        let extStr = extensions.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")

        return VideoFormatInfo(
            codec: codecName, codecRaw: codec,
            width: Int(dimensions.width), height: Int(dimensions.height),
            bitsPerComponent: bitsPerComponent,
            transferFunction: transfer, colorPrimaries: primaries, yCbCrMatrix: matrix,
            isHDR: isHDR, isHEVC: isHEVC, is10Bit: is10Bit, hevcHWSupported: hevcHW,
            allExtensions: extStr, streamURL: urlSuffix, pixelFormat: pixelFormat
        )
    }

    private static func safeIntFromDouble(_ value: Double) -> Int? {
        guard value.isFinite else { return nil }
        if value >= Double(Int.max) { return Int.max }
        if value <= Double(Int.min) { return Int.min }
        return Int(value)
    }
}

private extension PlayerViewModel {
    struct LocalDASHManifest: Decodable {
        let version: Int
        let bvid: String
        let videoFile: String
        let audioFile: String
    }

    struct LocalDASHFiles {
        let videoURL: URL
        let audioURL: URL?
    }

    static func readLocalDASHManifest(from url: URL) -> LocalDASHFiles? {
        guard url.pathExtension.lowercased() == "json" else { return nil }
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(LocalDASHManifest.self, from: data) else { return nil }
        let base = url.deletingLastPathComponent()
        let videoURL = base.appendingPathComponent(manifest.videoFile)
        let audioURL = base.appendingPathComponent(manifest.audioFile)
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }
        return LocalDASHFiles(videoURL: videoURL, audioURL: FileManager.default.fileExists(atPath: audioURL.path) ? audioURL : nil)
    }

    static func cookieHeader(from session: BiliLoginSession) -> String? {
        guard session.isValid else { return nil }
        var items: [String] = ["SESSDATA=\(session.sessdata)"]
        if let biliJct = session.biliJct, !biliJct.isEmpty {
            items.append("bili_jct=\(biliJct)")
        }
        if let dedeUserID = session.dedeUserID, !dedeUserID.isEmpty {
            items.append("DedeUserID=\(dedeUserID)")
        }
        if let buvid3 = session.buvid3, !buvid3.isEmpty {
            items.append("buvid3=\(buvid3)")
        }
        if let buvid4 = session.buvid4, !buvid4.isEmpty {
            items.append("buvid4=\(buvid4)")
        }
        return items.joined(separator: "; ")
    }
}
