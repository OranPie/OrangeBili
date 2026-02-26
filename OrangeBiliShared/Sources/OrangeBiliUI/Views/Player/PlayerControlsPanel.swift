import SwiftUI
import OrangeBiliCore

/// Shared player controls used by both SystemPlayerView and SoftDecodePlayerView.
/// Does NOT apply its own background — callers wrap with `controlsPanelChrome()`.
struct PlayerControlsPanel<MiddleContent: View>: View {
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject private var render: RenderSettings

    let isPlaying: Bool
    let onTogglePlayback: () -> Void
    let onHide: () -> Void
    let middleContent: MiddleContent

    /// Standard init — shows the default time row on watchOS.
    init(viewModel: PlayerViewModel,
         isPlaying: Bool,
         onTogglePlayback: @escaping () -> Void,
         onHide: @escaping () -> Void
    ) where MiddleContent == DefaultTimeRow {
        self.viewModel = viewModel
        self.isPlaying = isPlaying
        self.onTogglePlayback = onTogglePlayback
        self.onHide = onHide
        self.middleContent = DefaultTimeRow(viewModel: viewModel)
    }

    /// Custom middle content — replaces the default time row (e.g. seek bar + time).
    init(viewModel: PlayerViewModel,
         isPlaying: Bool,
         onTogglePlayback: @escaping () -> Void,
         onHide: @escaping () -> Void,
         @ViewBuilder middleContent: () -> MiddleContent
    ) {
        self.viewModel = viewModel
        self.isPlaying = isPlaying
        self.onTogglePlayback = onTogglePlayback
        self.onHide = onHide
        self.middleContent = middleContent()
    }

    var body: some View {
        VStack(spacing: 6) {
            topRow
            #if os(watchOS)
            middleContent
            watchControlsRow
            watchSecondaryRow
            #else
            nonWatchControlsRow
            #endif
        }
    }

    // MARK: - Rows

    private var topRow: some View {
        HStack(spacing: 8) {
            #if os(watchOS)
            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            #else
            Menu {
                ForEach(RenderSettings.qualityOptions, id: \.id) { option in
                    Button {
                        render.preferredQuality = option.id
                    } label: {
                        if option.id == render.preferredQuality {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                Text(render.qualityLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
            }
            #endif

            Spacer()

            Button(action: onHide) {
                Image(systemName: "chevron.down.circle")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
    }

    #if os(watchOS)
    private var watchControlsRow: some View {
        HStack(spacing: 6) {
            Button { viewModel.skip(by: -10) } label: {
                Image(systemName: "gobackward.10")
            }
            Button { viewModel.cyclePlaybackRate() } label: {
                Text(String(format: "%.2gx", viewModel.playbackRate))
                    .font(.system(size: 9, weight: .semibold))
            }
            Button { cycleDanmakuMode() } label: {
                Image(systemName: danmakuModeIcon)
                    .foregroundStyle(danmakuModeColor)
            }
            Button { viewModel.skip(by: 10) } label: {
                Image(systemName: "goforward.10")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
    }

    private var watchSecondaryRow: some View {
        HStack(spacing: 6) {
            Button { viewModel.switchSource() } label: {
                Text(viewModel.sourceLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1)
            }
            Button { viewModel.toggleMute() } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            Button { viewModel.loopPlayback.toggle() } label: {
                Image(systemName: viewModel.loopPlayback ? "repeat.1" : "repeat")
                    .foregroundStyle(viewModel.loopPlayback ? Theme.accent : .white)
            }
            Button { viewModel.restart() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
    }
    #endif

    #if !os(watchOS)
    private var nonWatchControlsRow: some View {
        HStack(spacing: 10) {
            Button { viewModel.skip(by: -10) } label: {
                Image(systemName: "gobackward.10")
            }
            Button { viewModel.cyclePlaybackRate() } label: {
                Text(String(format: "%.2gx", viewModel.playbackRate))
                    .font(.system(size: 9, weight: .semibold))
                    .frame(minWidth: 34)
            }
            Button { cycleDanmakuMode() } label: {
                Image(systemName: danmakuModeIcon)
                    .foregroundStyle(danmakuModeColor)
            }
            Button { viewModel.skip(by: 10) } label: {
                Image(systemName: "goforward.10")
            }
            Button { viewModel.switchSource() } label: {
                Text(viewModel.sourceLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1)
                    .frame(minWidth: 44)
            }
            Button { viewModel.toggleMute() } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            Button { viewModel.loopPlayback.toggle() } label: {
                Image(systemName: viewModel.loopPlayback ? "repeat.1" : "repeat")
                    .foregroundStyle(viewModel.loopPlayback ? Theme.accent : .white)
            }
            Button { viewModel.restart() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
    }
    #endif

    // MARK: - Danmaku helpers

    func cycleDanmakuMode() {
        if !render.danmakuEnabled {
            render.danmakuEnabled = true
            render.danmakuAdvancedOnly = false
        } else if !render.danmakuAdvancedOnly {
            render.danmakuAdvancedOnly = true
        } else {
            render.danmakuEnabled = false
            render.danmakuAdvancedOnly = false
        }
    }

    var danmakuModeIcon: String {
        if !render.danmakuEnabled { return "text.bubble" }
        if render.danmakuAdvancedOnly { return "wand.and.stars" }
        return "text.bubble.fill"
    }

    var danmakuModeColor: Color {
        if !render.danmakuEnabled { return .white }
        if render.danmakuAdvancedOnly { return .yellow }
        return Theme.accent
    }
}

// MARK: - Default time row (used by SystemPlayerView)

struct DefaultTimeRow: View {
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        #if os(watchOS)
        HStack {
            Text(timeText(viewModel.progressSeconds))
            Spacer()
            Text(timeText(max(viewModel.totalDurationSeconds, 0)))
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.white.opacity(0.92))
        #endif
    }

    private func timeText(_ seconds: Int) -> String {
        let safe = max(seconds, 0)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }
}

// MARK: - Chrome modifier (shared background + padding)

extension View {
    /// Applies the standard player-controls rounded background.
    func controlsPanelChrome() -> some View {
        self
        #if os(watchOS)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        #else
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        #endif
            .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 8))
        #if os(watchOS)
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        #else
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        #endif
    }
}
