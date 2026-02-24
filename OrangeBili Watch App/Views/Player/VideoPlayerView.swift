import SwiftUI
#if canImport(AVKit)
import AVKit
#endif

struct VideoPlayerView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @StateObject private var viewModel: PlayerViewModel
    @State private var controlsVisible = true

    init(video: BiliVideo, cid: Int, localFileURL: URL? = nil) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(video: video, cid: cid, localFileURL: localFileURL))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("加载中...")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                    Button("重试") {
                        Task { await viewModel.load() }
                    }
                }
            } else {
                playerContent
            }
        }
        .navigationTitle("播放")
        .task {
            await viewModel.load()
        }
        .onDisappear {
            historyStore.savePlayback(video: viewModel.video, progressSeconds: viewModel.progressSeconds)
            Task {
                await CompanionBridge.shared.syncHistory(records: historyStore.records)
            }
            viewModel.cleanup()
        }
    }

    @ViewBuilder
    private var playerContent: some View {
        #if canImport(AVKit)
        if let player = viewModel.player {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible.toggle()
                        }
                    }

                if controlsVisible {
                    controlsPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
        } else {
            Text("播放器初始化失败")
                .font(.caption)
                .foregroundStyle(.white)
        }
        #else
        Text("当前平台不支持内嵌播放器")
            .font(.caption)
            .foregroundStyle(.white)
        #endif
    }

    private var controlsPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        controlsVisible = false
                    }
                } label: {
                    Image(systemName: "chevron.down.circle")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)

            HStack {
                Text(timeText(viewModel.progressSeconds))
                Spacer()
                Text(timeText(max(viewModel.totalDurationSeconds, 0)))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 10) {
                Button {
                    viewModel.skip(by: -10)
                } label: {
                    Image(systemName: "gobackward.10")
                }

                Button {
                    viewModel.cyclePlaybackRate()
                } label: {
                    Text(String(format: "%.2gx", viewModel.playbackRate))
                        .font(.system(size: 9, weight: .semibold))
                        .frame(minWidth: 34)
                }

                Button {
                    viewModel.skip(by: 10)
                } label: {
                    Image(systemName: "goforward.10")
                }

                Button {
                    viewModel.switchSource()
                } label: {
                    Text(viewModel.sourceLabel)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                        .frame(minWidth: 44)
                }

                Button {
                    viewModel.toggleMute()
                } label: {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }

                Button {
                    viewModel.restart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private var isPlaying: Bool {
        viewModel.player?.timeControlStatus == .playing
    }

    private func timeText(_ seconds: Int) -> String {
        let safe = max(seconds, 0)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }
}
