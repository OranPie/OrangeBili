import Foundation
import SwiftUI

@MainActor
final class RenderSettings: ObservableObject {
    @Published var textScale: Double {
        didSet {
            textScale = min(max(textScale, 0.65), 1.35)
            defaults.set(textScale, forKey: Keys.textScale)
        }
    }

    @Published var compactStats: Bool {
        didSet { defaults.set(compactStats, forKey: Keys.compactStats) }
    }

    @Published var detailDescriptionLines: Int {
        didSet {
            detailDescriptionLines = min(max(detailDescriptionLines, 2), 8)
            defaults.set(detailDescriptionLines, forKey: Keys.detailDescriptionLines)
        }
    }

    @Published var commentTextScale: Double {
        didSet {
            commentTextScale = min(max(commentTextScale, 0.65), 1.4)
            defaults.set(commentTextScale, forKey: Keys.commentTextScale)
        }
    }

    @Published var videoCardScale: Double {
        didSet {
            videoCardScale = min(max(videoCardScale, 0.75), 1.05)
            defaults.set(videoCardScale, forKey: Keys.videoCardScale)
        }
    }

    @Published var resumeFromLast: Bool {
        didSet { defaults.set(resumeFromLast, forKey: Keys.resumeFromLast) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let textScale = "render.textScale"
        static let compactStats = "render.compactStats"
        static let detailDescriptionLines = "render.detailDescriptionLines"
        static let commentTextScale = "render.commentTextScale"
        static let videoCardScale = "render.videoCardScale"
        static let resumeFromLast = "render.resumeFromLast"
    }

    init() {
        let savedScale = defaults.object(forKey: Keys.textScale) as? Double
        let savedCompact = defaults.object(forKey: Keys.compactStats) as? Bool
        let savedLines = defaults.object(forKey: Keys.detailDescriptionLines) as? Int
        let savedCommentScale = defaults.object(forKey: Keys.commentTextScale) as? Double
        let savedVideoCardScale = defaults.object(forKey: Keys.videoCardScale) as? Double
        let savedResume = defaults.object(forKey: Keys.resumeFromLast) as? Bool

        textScale = savedScale ?? 0.85
        compactStats = savedCompact ?? true
        detailDescriptionLines = savedLines ?? 4
        commentTextScale = savedCommentScale ?? 0.9
        videoCardScale = savedVideoCardScale ?? 0.9
        resumeFromLast = savedResume ?? true
    }
}
