import AVFoundation
import Foundation

@MainActor
public final class PlayerViewModel: ObservableObject {
    @Published public var isLoading = true
    @Published public var errorMessage: String?
    @Published public var progressSeconds: Int = 0
    @Published public var totalDurationSeconds: Int = 0
    @Published public var playbackRate: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var sourceLabel: String = L10n.t("player.source.main")

    public let video: BiliVideo
    public let cid: Int
    public let localFileURL: URL?
    private let service: BiliServiceProtocol
    public private(set) var player: AVPlayer?
    private var observer: Any?
    private var streamURLs: [URL] = []
    private var streamHeaders: [String: String] = [:]
    private var currentStreamIndex = 0

    public init(video: BiliVideo, cid: Int, localFileURL: URL? = nil, service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.video = video
        self.cid = cid
        self.localFileURL = localFileURL
        self.service = service
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        if let localFileURL, FileManager.default.fileExists(atPath: localFileURL.path) {
            let item = AVPlayerItem(url: localFileURL)
            let player = AVPlayer(playerItem: item)
            player.isMuted = isMuted
            self.player = player
            observeProgress()
            isLoading = false
            player.playImmediately(atRate: playbackRate)
            return
        }

        do {
            let headers = [
                "Referer": "https://www.bilibili.com",
                "User-Agent": PlatformInfo.userAgent
            ]
            streamHeaders = headers
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
        player?.pause()
        player = nil
    }

    private func collectPlayableURLs() async throws -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        for quality in [16, 32] {
            if let stream = try? await service.fetchPlayURL(bvid: video.bvid, cid: cid, quality: quality) {
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
        player?.pause()

        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": streamHeaders])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = isMuted
        self.player = player
        observeProgress()
    }

    private func observeProgress() {
        observer = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            guard let self else { return }
            self.progressSeconds = Int(time.seconds)
            let duration = self.player?.currentItem?.duration.seconds ?? .nan
            if duration.isFinite, duration > 0 {
                self.totalDurationSeconds = Int(duration)
            }
        }
    }
}
