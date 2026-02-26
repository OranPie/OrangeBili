import SwiftUI
import OrangeBiliCore
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AVKit)
import AVKit
#endif

/// AVKit-based player backend. Used on all platforms for the system VideoPlayer.
struct SystemPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var danmakuViewModel: DanmakuViewModel
    @EnvironmentObject private var render: RenderSettings
    @State private var controlsVisible = true

    var body: some View {
        #if canImport(AVKit)
        if let player = viewModel.player {
            #if os(tvOS)
            tvBody(player: player)
            #elseif os(watchOS)
            watchBody(player: player)
            #else
            iosBody(player: player)
            #endif
        } else {
            Text(L10n.t("player.initFailed"))
                .font(.caption)
                .foregroundStyle(.white)
        }
        #else
        Text(L10n.t("player.unsupported"))
            .font(.caption)
            .foregroundStyle(.white)
        #endif
    }

    // MARK: - tvOS

    #if os(tvOS)
    @ViewBuilder
    private func tvBody(player: AVPlayer) -> some View {
        ZStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()

            if render.danmakuEnabled, render.watchPlayerVendor == .videoPlayer {
                DanmakuOverlayView(
                    viewModel: danmakuViewModel,
                    playerViewModel: viewModel
                )
                .allowsHitTesting(false)
            }
        }
    }
    #endif

    // MARK: - watchOS

    #if os(watchOS)
    @ViewBuilder
    private func watchBody(player: AVPlayer) -> some View {
        ZStack(alignment: .bottom) {
            ZStack {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible.toggle()
                        }
                    }

                if render.danmakuEnabled {
                    DanmakuOverlayView(
                        viewModel: danmakuViewModel,
                        playerViewModel: viewModel
                    )
                    .allowsHitTesting(false)
                }
            }

            if controlsVisible {
                PlayerControlsPanel(
                    viewModel: viewModel,
                    isPlaying: viewModel.player?.timeControlStatus == .playing,
                    onTogglePlayback: { viewModel.togglePlayback() },
                    onHide: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible = false
                        }
                    }
                )
                .controlsPanelChrome()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: controlsVisible)
            }
        }
    }
    #endif

    // MARK: - iOS / macOS

    #if !os(tvOS) && !os(watchOS)
    @ViewBuilder
    private func iosBody(player: AVPlayer) -> some View {
        ZStack(alignment: .bottom) {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        controlsVisible.toggle()
                    }
                }

            if render.danmakuEnabled {
                DanmakuOverlayView(
                    viewModel: danmakuViewModel,
                    playerViewModel: viewModel
                )
            }

            if controlsVisible {
                PlayerControlsPanel(
                    viewModel: viewModel,
                    isPlaying: viewModel.player?.timeControlStatus == .playing,
                    onTogglePlayback: { viewModel.togglePlayback() },
                    onHide: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible = false
                        }
                    }
                )
                .controlsPanelChrome()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: controlsVisible)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        controlsVisible = true
                    }
                } label: {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
            }
        }
    }
    #endif
}
