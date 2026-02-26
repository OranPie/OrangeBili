import SwiftUI
#if os(watchOS)
import AVFoundation
import AVKit
import WatchCustomPlayer
#endif

public struct WatchVideoProbeLabView: View {
    #if os(watchOS)
    private enum Mode: String, CaseIterable, Identifiable {
        case system = "Mode 1: System VideoPlayer"
        case custom = "Custom SpriteKit"
        case cBridge = "C Decode PoC"

        var id: String { rawValue }
    }

    @State private var mode: Mode = .system
    private let externalPlayer: AVPlayer?
    private let requestHeaders: [String: String]
    @State private var systemPlayer: AVPlayer?
    @State private var ownsSystemPlayer = false
    @State private var localURL: URL?
    @State private var loadError: String?
    @State private var loaded = false
    #endif

    public init() {
        #if os(watchOS)
        self.externalPlayer = nil
        self.requestHeaders = [:]
        #endif
    }

    #if os(watchOS)
    public init(player: AVPlayer, headers: [String: String] = [:]) {
        self.externalPlayer = player
        self.requestHeaders = headers
    }
    #endif

    public var body: some View {
        #if os(watchOS)
        VStack(spacing: 8) {
            Text("Watch Video Probe")
                .font(.headline)

            if let localURL {
                Picker("Renderer", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.navigationLink)

                Group {
                    switch mode {
                    case .system:
                        if let systemPlayer {
                            VideoPlayer(player: systemPlayer)
                                .frame(height: 132)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Text("System player unavailable")
                        }
                    case .custom:
                        WatchCustomPlayerView(url: localURL, fps: 20)
                            .frame(height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .cBridge:
                        if let systemPlayer {
                            SoftDecodePlayerView(player: systemPlayer, headers: requestHeaders)
                                .frame(height: 132)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            SoftDecodePlayerView(url: localURL, headers: requestHeaders)
                                .frame(height: 132)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Text(localURL.lastPathComponent)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            } else if let loadError {
                Text(loadError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
            }
        }
        .padding(8)
        .task {
            guard !loaded else { return }
            loaded = true
            setupProbeVideo()
        }
        .onDisappear {
            if ownsSystemPlayer {
                systemPlayer?.pause()
            }
        }
        #else
        Text("Watch-only probe view")
            .font(.caption)
        #endif
    }

    #if os(watchOS)
    private func setupProbeVideo() {
        if let externalPlayer {
            systemPlayer = externalPlayer
            ownsSystemPlayer = false
            if let urlAsset = externalPlayer.currentItem?.asset as? AVURLAsset {
                localURL = urlAsset.url
                print("[WatchVideoProbeLab] Using external player URL: \(urlAsset.url.absoluteString)")
            } else {
                loadError = "External player has no AVURLAsset URL"
            }
            return
        }

        guard let url = Bundle.module.url(forResource: "watch_probe", withExtension: "mp4") else {
            loadError = "Missing bundled watch_probe.mp4"
            return
        }
        localURL = url
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.play()
        systemPlayer = player
        ownsSystemPlayer = true
        print("[WatchVideoProbeLab] Loaded local probe video: \(url.path)")
    }
    #endif
}
