import Foundation

public struct BiliVideo: Identifiable, Hashable {
    public let id: String
    public let bvid: String
    public let aid: Int64
    public let cid: Int64?
    public let title: String
    public let author: String
    public let mid: Int?
    public let coverURL: URL?
    public let viewCount: Int
    public let danmakuCount: Int
    public let durationText: String
    public let publishedAt: Date?
    public let description: String
    public let sourceTag: String?

    public init(
        bvid: String,
        aid: Int64,
        cid: Int64? = nil,
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

public struct VideoDetail: Hashable {
    public let bvid: String
    public let aid: Int64
    public let cid: Int64
    public let title: String
    public let description: String
    public let coverURL: URL?
    public let duration: Int
    public let owner: UploaderProfile
    public let stats: VideoStats

    public init(
        bvid: String,
        aid: Int64,
        cid: Int64,
        title: String,
        description: String,
        coverURL: URL?,
        duration: Int,
        owner: UploaderProfile,
        stats: VideoStats
    ) {
        self.bvid = bvid
        self.aid = aid
        self.cid = cid
        self.title = title
        self.description = description
        self.coverURL = coverURL
        self.duration = duration
        self.owner = owner
        self.stats = stats
    }
}

public struct VideoStats: Hashable {
    public let views: Int
    public let danmaku: Int
    public let replies: Int
    public let favorites: Int
    public let coins: Int
    public let shares: Int

    public init(views: Int, danmaku: Int, replies: Int, favorites: Int, coins: Int, shares: Int) {
        self.views = views
        self.danmaku = danmaku
        self.replies = replies
        self.favorites = favorites
        self.coins = coins
        self.shares = shares
    }
}

public struct PlayStream {
    public let url: URL
    public let backupURLs: [URL]
    public let audioURL: URL?
    public let audioBackupURLs: [URL]
    public let codecId: Int?

    public init(url: URL, backupURLs: [URL], audioURL: URL? = nil,
                audioBackupURLs: [URL] = [], codecId: Int? = nil) {
        self.url = url
        self.backupURLs = backupURLs
        self.audioURL = audioURL
        self.audioBackupURLs = audioBackupURLs
        self.codecId = codecId
    }
}

public struct CommentItem: Identifiable, Hashable {
    public let id: Int
    public let oid: Int64
    public let mid: Int?
    public let username: String
    public let avatarURL: URL?
    public let message: String
    public let likeCount: Int
    public let timestamp: Date
    public let replyCount: Int

    public init(
        id: Int,
        oid: Int64,
        mid: Int?,
        username: String,
        avatarURL: URL?,
        message: String,
        likeCount: Int,
        timestamp: Date,
        replyCount: Int
    ) {
        self.id = id
        self.oid = oid
        self.mid = mid
        self.username = username
        self.avatarURL = avatarURL
        self.message = message
        self.likeCount = likeCount
        self.timestamp = timestamp
        self.replyCount = replyCount
    }
}

public struct UploaderProfile: Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let avatarURL: URL?
    public let signature: String
    public let followerCount: Int
    public let followingCount: Int
    public let likeCount: Int

    public init(
        id: Int,
        name: String,
        avatarURL: URL?,
        signature: String,
        followerCount: Int,
        followingCount: Int,
        likeCount: Int
    ) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.signature = signature
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.likeCount = likeCount
    }
}

public struct CloudFavoriteFolder: Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let mediaCount: Int

    public init(id: Int, title: String, mediaCount: Int) {
        self.id = id
        self.title = title
        self.mediaCount = mediaCount
    }
}

public struct UserSearchResult: Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let avatarURL: URL?
    public let sign: String
    public let fans: Int

    public init(id: Int, name: String, avatarURL: URL?, sign: String, fans: Int) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.sign = sign
        self.fans = fans
    }
}

public struct ArticleSearchResult: Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let author: String
    public let imageURL: URL?
    public let summary: String

    public init(id: Int, title: String, author: String, imageURL: URL?, summary: String) {
        self.id = id
        self.title = title
        self.author = author
        self.imageURL = imageURL
        self.summary = summary
    }
}

public struct UploaderArticle: Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let summary: String
    public let imageURL: URL?
    public let publishedAt: Date?
    public let viewCount: Int

    public init(id: Int, title: String, summary: String, imageURL: URL?, publishedAt: Date?, viewCount: Int) {
        self.id = id
        self.title = title
        self.summary = summary
        self.imageURL = imageURL
        self.publishedAt = publishedAt
        self.viewCount = viewCount
    }
}

public struct FollowingUser: Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let avatarURL: URL?
    public let sign: String
    public let fans: Int

    public init(id: Int, name: String, avatarURL: URL?, sign: String, fans: Int) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.sign = sign
        self.fans = fans
    }
}

public struct HistoryRecord: Identifiable, Codable, Hashable {
    public let id: String
    public let bvid: String
    public let title: String
    public let coverURL: URL?
    public let watchedAt: Date
    public let progressSeconds: Int

    public init(bvid: String, title: String, coverURL: URL?, watchedAt: Date, progressSeconds: Int) {
        self.id = bvid
        self.bvid = bvid
        self.title = title
        self.coverURL = coverURL
        self.watchedAt = watchedAt
        self.progressSeconds = progressSeconds
    }
}

public struct CompanionCommand: Codable {
    public enum Kind: String, Codable {
        case requestAuthState
        case syncHistory
        case syncFavorites
        case syncAccount
    }

    public let kind: Kind
    public let payload: Data?

    public init(kind: Kind, payload: Data?) {
        self.kind = kind
        self.payload = payload
    }
}

public struct CompanionAuthState: Codable {
    public let isLoggedIn: Bool
    public let username: String?

    public init(isLoggedIn: Bool, username: String?) {
        self.isLoggedIn = isLoggedIn
        self.username = username
    }
}
