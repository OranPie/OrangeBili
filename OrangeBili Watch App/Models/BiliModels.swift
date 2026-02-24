import Foundation

struct BiliVideo: Identifiable, Hashable {
    let id: String
    let bvid: String
    let aid: Int
    let cid: Int?
    let title: String
    let author: String
    let mid: Int?
    let coverURL: URL?
    let viewCount: Int
    let danmakuCount: Int
    let durationText: String
    let publishedAt: Date?
    let description: String
    let sourceTag: String?

    init(
        bvid: String,
        aid: Int,
        cid: Int? = nil,
        title: String,
        author: String,
        mid: Int? = nil,
        coverURL: URL?,
        viewCount: Int,
        danmakuCount: Int,
        durationText: String,
        publishedAt: Date? = nil,
        description: String,
        sourceTag: String? = nil
    ) {
        self.id = bvid
        self.bvid = bvid
        self.aid = aid
        self.cid = cid
        self.title = title
        self.author = author
        self.mid = mid
        self.coverURL = coverURL
        self.viewCount = viewCount
        self.danmakuCount = danmakuCount
        self.durationText = durationText
        self.publishedAt = publishedAt
        self.description = description
        self.sourceTag = sourceTag
    }
}

struct VideoDetail: Hashable {
    let bvid: String
    let aid: Int
    let cid: Int
    let title: String
    let description: String
    let coverURL: URL?
    let duration: Int
    let owner: UploaderProfile
    let stats: VideoStats
}

struct VideoStats: Hashable {
    let views: Int
    let danmaku: Int
    let replies: Int
    let favorites: Int
    let coins: Int
    let shares: Int
}

struct PlayStream {
    let url: URL
    let backupURLs: [URL]
}

struct CommentItem: Identifiable, Hashable {
    let id: Int
    let oid: Int
    let mid: Int?
    let username: String
    let avatarURL: URL?
    let message: String
    let likeCount: Int
    let timestamp: Date
    let replyCount: Int
}

struct UploaderProfile: Identifiable, Hashable {
    let id: Int
    let name: String
    let avatarURL: URL?
    let signature: String
    let followerCount: Int
    let followingCount: Int
    let likeCount: Int
}

struct CloudFavoriteFolder: Identifiable, Hashable {
    let id: Int
    let title: String
    let mediaCount: Int
}

struct UserSearchResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let avatarURL: URL?
    let sign: String
    let fans: Int
}

struct ArticleSearchResult: Identifiable, Hashable {
    let id: Int
    let title: String
    let author: String
    let imageURL: URL?
    let summary: String
}

struct UploaderArticle: Identifiable, Hashable {
    let id: Int
    let title: String
    let summary: String
    let imageURL: URL?
    let publishedAt: Date?
    let viewCount: Int
}

struct FollowingUser: Identifiable, Hashable {
    let id: Int
    let name: String
    let avatarURL: URL?
    let sign: String
    let fans: Int
}

struct HistoryRecord: Identifiable, Codable, Hashable {
    let id: String
    let bvid: String
    let title: String
    let coverURL: URL?
    let watchedAt: Date
    let progressSeconds: Int

    init(bvid: String, title: String, coverURL: URL?, watchedAt: Date, progressSeconds: Int) {
        self.id = bvid
        self.bvid = bvid
        self.title = title
        self.coverURL = coverURL
        self.watchedAt = watchedAt
        self.progressSeconds = progressSeconds
    }
}

struct CompanionCommand: Codable {
    enum Kind: String, Codable {
        case requestAuthState
        case syncHistory
    }

    let kind: Kind
    let payload: Data?
}

struct CompanionAuthState: Codable {
    let isLoggedIn: Bool
    let username: String?
}
