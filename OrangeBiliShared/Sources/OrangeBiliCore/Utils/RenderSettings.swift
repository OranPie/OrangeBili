import Foundation
import Combine

@MainActor
public final class RenderSettings: ObservableObject {
    private var isUpdating = false

    @Published public var textScale: Double {
        didSet {
            if let clamped = clamp(textScale, min: 0.65, max: 1.35, for: Keys.textScale) {
                textScale = clamped
            }
        }
    }

    @Published public var compactStats: Bool {
        didSet { defaults.set(compactStats, forKey: Keys.compactStats) }
    }

    @Published public var detailDescriptionLines: Int {
        didSet {
            if let clamped = clamp(detailDescriptionLines, min: 2, max: 8, for: Keys.detailDescriptionLines) {
                detailDescriptionLines = clamped
            }
        }
    }

    @Published public var commentTextScale: Double {
        didSet {
            if let clamped = clamp(commentTextScale, min: 0.65, max: 1.4, for: Keys.commentTextScale) {
                commentTextScale = clamped
            }
        }
    }

    @Published public var videoCardScale: Double {
        didSet {
            if let clamped = clamp(videoCardScale, min: 0.75, max: 1.05, for: Keys.videoCardScale) {
                videoCardScale = clamped
            }
        }
    }

    @Published public var resumeFromLast: Bool {
        didSet { defaults.set(resumeFromLast, forKey: Keys.resumeFromLast) }
    }

    @Published public var danmakuEnabled: Bool {
        didSet { defaults.set(danmakuEnabled, forKey: Keys.danmakuEnabled) }
    }

    @Published public var danmakuOpacity: Double {
        didSet {
            if let clamped = clamp(danmakuOpacity, min: 0.2, max: 1.0, for: Keys.danmakuOpacity) {
                danmakuOpacity = clamped
            }
        }
    }

    @Published public var danmakuScale: Double {
        didSet {
            if let clamped = clamp(danmakuScale, min: 0.6, max: 1.6, for: Keys.danmakuScale) {
                danmakuScale = clamped
            }
        }
    }

    @Published public var danmakuSpeed: Double {
        didSet {
            if let clamped = clamp(danmakuSpeed, min: 0.5, max: 2.0, for: Keys.danmakuSpeed) {
                danmakuSpeed = clamped
            }
        }
    }

    @Published public var danmakuAreaRaw: String {
        didSet { defaults.set(danmakuAreaRaw, forKey: Keys.danmakuAreaRaw) }
    }

    @Published public var danmakuAllowTop: Bool {
        didSet { defaults.set(danmakuAllowTop, forKey: Keys.danmakuAllowTop) }
    }

    @Published public var danmakuAllowBottom: Bool {
        didSet { defaults.set(danmakuAllowBottom, forKey: Keys.danmakuAllowBottom) }
    }

    @Published public var danmakuAllowScroll: Bool {
        didSet { defaults.set(danmakuAllowScroll, forKey: Keys.danmakuAllowScroll) }
    }

    @Published public var danmakuUseOriginalColor: Bool {
        didSet { defaults.set(danmakuUseOriginalColor, forKey: Keys.danmakuUseOriginalColor) }
    }

    @Published public var danmakuDensity: Int {
        didSet {
            if let clamped = clamp(danmakuDensity, min: 1, max: 5, for: Keys.danmakuDensity) {
                danmakuDensity = clamped
            }
        }
    }

    @Published public var danmakuMaxLines: Int {
        didSet {
            if let clamped = clamp(danmakuMaxLines, min: 1, max: 6, for: Keys.danmakuMaxLines) {
                danmakuMaxLines = clamped
            }
        }
    }

    @Published public var danmakuKeywordBlocklist: String {
        didSet { defaults.set(danmakuKeywordBlocklist, forKey: Keys.danmakuKeywordBlocklist) }
    }

    @Published public var danmakuUserHashBlocklist: String {
        didSet { defaults.set(danmakuUserHashBlocklist, forKey: Keys.danmakuUserHashBlocklist) }
    }

    @Published public var danmakuSearchQuery: String {
        didSet { defaults.set(danmakuSearchQuery, forKey: Keys.danmakuSearchQuery) }
    }

    @Published public var danmakuSearchOnly: Bool {
        didSet { defaults.set(danmakuSearchOnly, forKey: Keys.danmakuSearchOnly) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let textScale = "render.textScale"
        static let compactStats = "render.compactStats"
        static let detailDescriptionLines = "render.detailDescriptionLines"
        static let commentTextScale = "render.commentTextScale"
        static let videoCardScale = "render.videoCardScale"
        static let resumeFromLast = "render.resumeFromLast"
        static let danmakuEnabled = "render.danmaku.enabled"
        static let danmakuOpacity = "render.danmaku.opacity"
        static let danmakuScale = "render.danmaku.scale"
        static let danmakuSpeed = "render.danmaku.speed"
        static let danmakuAreaRaw = "render.danmaku.area"
        static let danmakuAllowTop = "render.danmaku.allowTop"
        static let danmakuAllowBottom = "render.danmaku.allowBottom"
        static let danmakuAllowScroll = "render.danmaku.allowScroll"
        static let danmakuUseOriginalColor = "render.danmaku.useOriginalColor"
        static let danmakuDensity = "render.danmaku.density"
        static let danmakuMaxLines = "render.danmaku.maxLines"
        static let danmakuKeywordBlocklist = "render.danmaku.keywordBlocklist"
        static let danmakuUserHashBlocklist = "render.danmaku.userHashBlocklist"
        static let danmakuSearchQuery = "render.danmaku.searchQuery"
        static let danmakuSearchOnly = "render.danmaku.searchOnly"
    }

    public init() {
        let savedScale = defaults.object(forKey: Keys.textScale) as? Double
        let savedCompact = defaults.object(forKey: Keys.compactStats) as? Bool
        let savedLines = defaults.object(forKey: Keys.detailDescriptionLines) as? Int
        let savedCommentScale = defaults.object(forKey: Keys.commentTextScale) as? Double
        let savedVideoCardScale = defaults.object(forKey: Keys.videoCardScale) as? Double
        let savedResume = defaults.object(forKey: Keys.resumeFromLast) as? Bool
        let savedDanmakuEnabled = defaults.object(forKey: Keys.danmakuEnabled) as? Bool
        let savedDanmakuOpacity = defaults.object(forKey: Keys.danmakuOpacity) as? Double
        let savedDanmakuScale = defaults.object(forKey: Keys.danmakuScale) as? Double
        let savedDanmakuSpeed = defaults.object(forKey: Keys.danmakuSpeed) as? Double
        let savedDanmakuArea = defaults.object(forKey: Keys.danmakuAreaRaw) as? String
        let savedAllowTop = defaults.object(forKey: Keys.danmakuAllowTop) as? Bool
        let savedAllowBottom = defaults.object(forKey: Keys.danmakuAllowBottom) as? Bool
        let savedAllowScroll = defaults.object(forKey: Keys.danmakuAllowScroll) as? Bool
        let savedUseColor = defaults.object(forKey: Keys.danmakuUseOriginalColor) as? Bool
        let savedDensity = defaults.object(forKey: Keys.danmakuDensity) as? Int
        let savedMaxLines = defaults.object(forKey: Keys.danmakuMaxLines) as? Int
        let savedKeywordBlocklist = defaults.object(forKey: Keys.danmakuKeywordBlocklist) as? String
        let savedUserHashBlocklist = defaults.object(forKey: Keys.danmakuUserHashBlocklist) as? String
        let savedSearchQuery = defaults.object(forKey: Keys.danmakuSearchQuery) as? String
        let savedSearchOnly = defaults.object(forKey: Keys.danmakuSearchOnly) as? Bool

        #if os(tvOS)
        let defaultTextScale = 1.05
        let defaultCommentScale = 1.0
        let defaultVideoCardScale = 1.0
        let defaultDetailLines = 5
        #elseif os(macOS)
        let defaultTextScale = 1.0
        let defaultCommentScale = 0.95
        let defaultVideoCardScale = 0.95
        let defaultDetailLines = 5
        #else
        let defaultTextScale = 0.9
        let defaultCommentScale = 0.9
        let defaultVideoCardScale = 0.9
        let defaultDetailLines = 4
        #endif

        textScale = savedScale ?? defaultTextScale
        compactStats = savedCompact ?? true
        detailDescriptionLines = savedLines ?? defaultDetailLines
        commentTextScale = savedCommentScale ?? defaultCommentScale
        videoCardScale = savedVideoCardScale ?? defaultVideoCardScale
        resumeFromLast = savedResume ?? true
        danmakuEnabled = savedDanmakuEnabled ?? false
        danmakuOpacity = savedDanmakuOpacity ?? 0.85
        danmakuScale = savedDanmakuScale ?? 1.0
        danmakuSpeed = savedDanmakuSpeed ?? 1.0
        danmakuAreaRaw = savedDanmakuArea ?? DanmakuArea.full.rawValue
        danmakuAllowTop = savedAllowTop ?? true
        danmakuAllowBottom = savedAllowBottom ?? true
        danmakuAllowScroll = savedAllowScroll ?? true
        danmakuUseOriginalColor = savedUseColor ?? true
        danmakuDensity = savedDensity ?? 3
        danmakuMaxLines = savedMaxLines ?? 3
        danmakuKeywordBlocklist = savedKeywordBlocklist ?? ""
        danmakuUserHashBlocklist = savedUserHashBlocklist ?? ""
        danmakuSearchQuery = savedSearchQuery ?? ""
        danmakuSearchOnly = savedSearchOnly ?? false
    }
    private func clamp<T: Comparable>(_ value: T, min lower: T, max upper: T, for key: String) -> T? {
        if isUpdating {
            defaults.set(value, forKey: key)
            return nil
        }
        let clamped = Swift.min(Swift.max(value, lower), upper)
        defaults.set(clamped, forKey: key)
        guard clamped != value else { return nil }
        isUpdating = true
        defer { isUpdating = false }
        return clamped
    }
}

public extension RenderSettings {
    var danmakuArea: DanmakuArea {
        get { DanmakuArea(rawValue: danmakuAreaRaw) ?? .full }
        set { danmakuAreaRaw = newValue.rawValue }
    }
}
