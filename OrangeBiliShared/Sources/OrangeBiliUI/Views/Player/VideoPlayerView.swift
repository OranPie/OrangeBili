import SwiftUI
import OrangeBiliCore
#if canImport(AVFoundation)
import AVFoundation
#endif

struct VideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var historySyncer: HistorySyncer
    @EnvironmentObject private var render: RenderSettings
    @StateObject private var viewModel: PlayerViewModel
    @StateObject private var danmakuViewModel = DanmakuViewModel()
    @State private var resumeSeconds: Int?
    @State private var showResumePrompt = false
    @State private var lastDanmakuLoadDuration = 0

    init(video: BiliVideo, cid: Int64, localFileURL: URL? = nil) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(video: video, cid: cid, localFileURL: localFileURL))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text(L10n.t("player.loading"))
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
                    Button(L10n.t("action.retry")) {
                        Task { await viewModel.load() }
                    }
                }
            } else {
                playerBackend
            }
        }
        .navigationTitle(L10n.t("player.title"))
        #if !os(tvOS)
        .overlay(alignment: .topLeading) {
            if render.showVideoDebugInfo, let info = viewModel.videoFormatInfo {
                formatInfoBadge(info)
            }
        }
        #endif
        .overlay(alignment: .center) {
            if showResumePrompt, let resumeSeconds {
                resumeOverlay(seconds: resumeSeconds)
            }
        }
        .task {
            viewModel.preferredQuality = render.preferredQuality
            #if os(watchOS)
            // Native watch VideoPlayer can show green frames on some non-AVC streams.
            // Force AVC for that backend; keep user preference for FFmpeg backend.
            viewModel.preferredCodec = (render.watchPlayerVendor == .videoPlayer) ? .avc : render.preferredCodec
            viewModel.preferredStreamFormat = render.preferredStreamFormat
            #else
            viewModel.preferredCodec = render.preferredCodec
            viewModel.preferredStreamFormat = render.preferredStreamFormat
            #endif
            await viewModel.load()
            if render.danmakuEnabled {
                await danmakuViewModel.load(
                    cid: viewModel.cid,
                    aid: viewModel.video.aid,
                    durationSeconds: viewModel.totalDurationSeconds,
                    source: render.danmakuSourceEnum
                )
                lastDanmakuLoadDuration = viewModel.totalDurationSeconds
            }
            await checkResume()
        }
        .onChange(of: render.danmakuEnabled) { enabled in
            if enabled {
                Task {
                    await danmakuViewModel.load(
                        cid: viewModel.cid,
                        aid: viewModel.video.aid,
                        durationSeconds: viewModel.totalDurationSeconds,
                        source: render.danmakuSourceEnum
                    )
                    lastDanmakuLoadDuration = viewModel.totalDurationSeconds
                }
            } else {
                danmakuViewModel.reset()
            }
        }
        .onChange(of: viewModel.totalDurationSeconds) { duration in
            guard render.danmakuEnabled else { return }
            guard duration > 0 else { return }
            guard duration != lastDanmakuLoadDuration else { return }
            Task {
                await danmakuViewModel.load(
                    cid: viewModel.cid,
                    aid: viewModel.video.aid,
                    durationSeconds: duration,
                    source: render.danmakuSourceEnum
                )
                lastDanmakuLoadDuration = duration
            }
        }
        .onChange(of: viewModel.didFinishPlaying) { finished in
            if finished { dismiss() }
        }
        .onDisappear {
            let progressToSave: Int = {
                let duration = max(viewModel.totalDurationSeconds, 0)
                let progress = max(viewModel.progressSeconds, 0)
                guard duration > 0 else { return progress }
                let remaining = Double(duration) - max(viewModel.currentTime, 0)
                return remaining < 1.0 ? 0 : progress
            }()
            historyStore.savePlayback(video: viewModel.video, progressSeconds: progressToSave)
            Task {
                await historySyncer.syncHistory(records: historyStore.records)
            }
            viewModel.cleanup()
        }
    }

    // MARK: - Player backend selection

    @ViewBuilder
    private var playerBackend: some View {
        #if os(watchOS)
        if let player = viewModel.player {
            if render.watchPlayerVendor == .ffmpegMinimal {
                SoftDecodePlayerView(
                    player: player,
                    decodeURL: viewModel.currentVideoStreamURL,
                    headers: viewModel.playbackRequestHeaders,
                    danmakuViewModel: danmakuViewModel,
                    playerViewModel: viewModel
                )
                .id(ObjectIdentifier(player))
                .ignoresSafeArea()
            } else {
                SystemPlayerView(viewModel: viewModel, danmakuViewModel: danmakuViewModel)
            }
        } else {
            Text(L10n.t("player.initFailed"))
                .font(.caption)
                .foregroundStyle(.white)
        }
        #elseif canImport(AVKit)
        SystemPlayerView(viewModel: viewModel, danmakuViewModel: danmakuViewModel)
        #else
        Text(L10n.t("player.unsupported"))
            .font(.caption)
            .foregroundStyle(.white)
        #endif
    }

    // MARK: - Helpers

    private func timeText(_ seconds: Int) -> String {
        let safe = max(seconds, 0)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }

    private func checkResume() async {
        guard render.resumeFromLast else { return }
        guard let saved = historyStore.progressSeconds(for: viewModel.video.bvid), saved > 5 else { return }
        resumeSeconds = saved
        showResumePrompt = true
    }

    @ViewBuilder
    private func formatInfoBadge(_ info: VideoFormatInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(info.codec) \(info.width)x\(info.height) \(info.bitsPerComponent)bit")
            Text("pxfmt=\(info.pixelFormat)")
            Text("TF=\(info.transferFunction.isEmpty ? "–" : info.transferFunction)")
            Text("CP=\(info.colorPrimaries.isEmpty ? "–" : info.colorPrimaries)")
            Text("M=\(info.yCbCrMatrix.isEmpty ? "–" : info.yCbCrMatrix)")
            Text("HDR=\(info.isHDR ? "Y" : "N") HEVC_HW=\(info.hevcHWSupported ? "Y" : "N")")
            Text(info.streamURL)
                .lineLimit(2)
            if viewModel.colorFixActive {
                Text("CI_FIX=ON")
                    .foregroundStyle(.green)
            }
        }
        .font(.system(size: UIStyle.fontSize(7), design: .monospaced))
        .foregroundStyle(.white.opacity(0.7))
        .padding(6)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .padding(8)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func resumeOverlay(seconds: Int) -> some View {
        #if os(watchOS)
        let titleFont: Font = .system(size: 11, weight: .semibold)
        let subtitleFont: Font = .system(size: 8)
        let buttonFont: Font = .system(size: 10, weight: .medium)
        #else
        let titleFont: Font = .caption
        let subtitleFont: Font = .system(size: 9)
        let buttonFont: Font = .body
        #endif
        VStack(spacing: 6) {
            Text(L10n.t("player.resume.title"))
                .font(titleFont)
                .foregroundStyle(.white)
            Text(L10n.f("player.resume.subtitle", timeText(seconds)))
                .font(subtitleFont)
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) {
                Button(L10n.t("player.resume.restart")) {
                    viewModel.seek(to: 0)
                    showResumePrompt = false
                }
                .font(buttonFont)
                Button(L10n.t("player.resume.continue")) {
                    viewModel.seek(to: Double(seconds))
                    showResumePrompt = false
                }
                .font(buttonFont)
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10))
        .padding(12)
        .transition(.scale.combined(with: .opacity))
    }
}
