import Foundation

public protocol BiliServiceProtocol {
    func fetchPopular(page: Int, size: Int) async throws -> [BiliVideo]
    func fetchRecommendFeed(page: Int) async throws -> [BiliVideo]
    func searchVideos(keyword: String, page: Int, order: String) async throws -> [BiliVideo]
    func searchUsers(keyword: String, page: Int) async throws -> [UserSearchResult]
    func searchArticles(keyword: String, page: Int) async throws -> [ArticleSearchResult]
    func fetchVideoDetail(bvid: String) async throws -> VideoDetail
    func fetchPlayURL(bvid: String, cid: Int64, quality: Int, preferredCodec: PreferredCodec, streamFormat: PreferredStreamFormat) async throws -> PlayStream
    func fetchOfflineDownloadStream(bvid: String, cid: Int64, quality: Int) async throws -> PlayStream
    func fetchComments(aid: Int64, page: Int) async throws -> [CommentItem]
    func fetchUploader(mid: Int, page: Int) async throws -> (UploaderProfile, [BiliVideo])
    func fetchUploaderVideos(mid: Int, page: Int, order: String) async throws -> [BiliVideo]
    func fetchUploaderArticles(mid: Int, page: Int) async throws -> [UploaderArticle]
    func fetchUploaderTopVideo(mid: Int) async throws -> BiliVideo?
    func fetchUploaderMasterpieces(mid: Int, page: Int) async throws -> [BiliVideo]
    func fetchUploaderRelationState(mid: Int) async throws -> UploaderRelationState
    func followUploader(mid: Int) async throws
    func unfollowUploader(mid: Int) async throws
    func fetchDynamics(scope: DynamicsScope, offset: String?) async throws -> DynamicsPage
    func fetchDynamicDetail(dynamicID: Int64) async throws -> DynamicItem
}

extension BiliServiceProtocol {
    func fetchPlayURL(bvid: String, cid: Int64, quality: Int) async throws -> PlayStream {
        try await fetchPlayURL(bvid: bvid, cid: cid, quality: quality, preferredCodec: .auto, streamFormat: .auto)
    }

    func fetchPlayURL(bvid: String, cid: Int64, quality: Int, preferredCodec: PreferredCodec) async throws -> PlayStream {
        try await fetchPlayURL(bvid: bvid, cid: cid, quality: quality, preferredCodec: preferredCodec, streamFormat: .auto)
    }

    func fetchOfflineDownloadStream(bvid: String, cid: Int64, quality: Int) async throws -> PlayStream {
        try await fetchPlayURL(bvid: bvid, cid: cid, quality: quality, preferredCodec: .avc, streamFormat: .mp4)
    }

    func followUploader(mid: Int) async throws {
        throw BiliError.unauthorized
    }

    func unfollowUploader(mid: Int) async throws {
        throw BiliError.unauthorized
    }
}

struct BiliService: BiliServiceProtocol {
    private let client: NetworkClientProtocol

    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    func fetchPopular(page: Int, size: Int) async throws -> [BiliVideo] {
        let response = try await client.request(.popular(page: page, size: size), as: PopularResponse.self)
        return response.list.map { item in
            BiliVideo(
                bvid: item.bvid,
                aid: item.aid.value64,
                title: item.title.cleanHTMLTags(),
                author: item.owner.name,
                mid: item.owner.mid.value,
                coverURL: URL.biliImageURL(from: item.pic),
                viewCount: item.stat.view.value,
                danmakuCount: item.stat.danmaku.value,
                durationText: item.duration.value.durationString,
                publishedAt: item.publishedAt,
                description: item.desc
            )
        }
    }

    func fetchRecommendFeed(page: Int) async throws -> [BiliVideo] {
        let response = try await client.request(.recommendFeed(page: page), as: RecommendResponse.self)
        return response.item.map { item in
            BiliVideo(
                bvid: item.bvid,
                aid: item.aid.value64,
                title: item.title.cleanHTMLTags(),
                author: item.owner.name,
                mid: item.owner.mid.value,
                coverURL: URL.biliImageURL(from: item.pic),
                viewCount: item.stat.view.value,
                danmakuCount: item.stat.danmaku.value,
                durationText: item.duration.value.durationString,
                publishedAt: item.publishedAt,
                description: item.desc
            )
        }
    }

    func searchVideos(keyword: String, page: Int, order: String) async throws -> [BiliVideo] {
        let response = try await client.request(.search(keyword: keyword, page: page, order: order), as: SearchResponse.self)
        return response.result.map { item in
            BiliVideo(
                bvid: item.bvid,
                aid: item.aid.value64,
                title: item.title.cleanHTMLTags(),
                author: item.author,
                mid: item.mid?.value,
                coverURL: URL.biliImageURL(from: item.pic),
                viewCount: item.play.value,
                danmakuCount: item.danmaku.value,
                durationText: item.durationText,
                publishedAt: item.publishedAt,
                description: item.description.cleanHTMLTags()
            )
        }
    }

    func searchUsers(keyword: String, page: Int) async throws -> [UserSearchResult] {
        let response = try await client.request(.searchUsers(keyword: keyword, page: page), as: UserSearchResponse.self)
        return response.result.map { item in
            UserSearchResult(
                id: item.mid.value,
                name: item.uname.cleanHTMLTags(),
                avatarURL: URL.biliImageURL(from: item.upic),
                sign: item.usign.cleanHTMLTags(),
                fans: item.fans.value
            )
        }
    }

    func searchArticles(keyword: String, page: Int) async throws -> [ArticleSearchResult] {
        let response = try await client.request(.searchArticles(keyword: keyword, page: page), as: ArticleSearchResponse.self)
        return response.result.map { item in
            ArticleSearchResult(
                id: item.id.value,
                title: item.title.cleanHTMLTags(),
                author: item.author.cleanHTMLTags(),
                imageURL: URL.biliImageURL(from: item.imageUrls.first ?? ""),
                summary: item.desc.cleanHTMLTags()
            )
        }
    }

    func fetchVideoDetail(bvid: String) async throws -> VideoDetail {
        let detail = try await client.request(.detailWbi(bvid: bvid), as: VideoDetailResponse.self)
        return VideoDetail(
            bvid: detail.bvid,
            aid: detail.aid.value64,
            cid: detail.cid.value64,
            title: detail.title,
            description: detail.desc,
            coverURL: URL.biliImageURL(from: detail.pic),
            duration: detail.duration.value,
            owner: UploaderProfile(
                id: detail.owner.mid.value,
                name: detail.owner.name,
                avatarURL: URL.biliImageURL(from: detail.owner.face),
                signature: "",
                followerCount: 0,
                followingCount: 0,
                likeCount: 0
            ),
            stats: VideoStats(
                views: detail.stat.view.value,
                danmaku: detail.stat.danmaku.value,
                replies: detail.stat.reply.value,
                favorites: detail.stat.favorite.value,
                coins: detail.stat.coin.value,
                shares: detail.stat.share.value
            )
        )
    }

    func fetchPlayURL(bvid: String, cid: Int64, quality: Int = 32, preferredCodec: PreferredCodec = .auto, streamFormat: PreferredStreamFormat = .auto) async throws -> PlayStream {
        let useDash: Bool
        switch streamFormat {
        case .dash: useDash = true
        case .mp4: useDash = false
        case .auto: useDash = true
        }

        let response = try await client.request(.playURLWbi(bvid: bvid, cid: cid, quality: quality, dash: useDash), as: PlayURLResponse.self)

        // Try DASH first
        if let dash = response.dash, let videos = dash.video, !videos.isEmpty {
            let exact = videos
                .filter { $0.id == quality }
                .sorted { ($0.bandwidth ?? 0) > ($1.bandwidth ?? 0) }
            let lower = videos
                .filter { $0.id < quality }
                .sorted { ($0.id, $0.bandwidth ?? 0) > ($1.id, $1.bandwidth ?? 0) }
            let higher = videos
                .filter { $0.id > quality }
                .sorted { ($0.id, $0.bandwidth ?? 0) < ($1.id, $1.bandwidth ?? 0) }
            let candidates = exact + lower + higher

            // Pick by codec preference
            let targetCodecId: Int? = {
                switch preferredCodec {
                case .avc: return 7
                case .hevc: return 12
                case .auto: return nil
                }
            }()

            let picked: PlayURLResponse.DASHData.Stream?
            if let targetCodecId {
                // Explicit preference, then fallback to known-supported codecs.
                picked = candidates.first(where: { $0.codecid == targetCodecId })
                    ?? candidates.first(where: { $0.codecid == 7 })
                    ?? candidates.first(where: { $0.codecid == 12 })
                    ?? candidates.first
            } else {
                // Auto: prefer AVC, then HEVC, then any remaining stream.
                picked = candidates.first(where: { $0.codecid == 7 })
                    ?? candidates.first(where: { $0.codecid == 12 })
                    ?? candidates.first
            }

            if let video = picked, let videoURL = URL(string: video.baseUrl), !video.baseUrl.isEmpty {
                DebugLogStore.shared.log(
                    category: "player.playurl",
                    message: "pick q=\(quality) id=\(video.id) codec=\(video.codecid) bw=\(video.bandwidth ?? 0) size=\(video.width ?? 0)x\(video.height ?? 0) dashCount=\(videos.count)"
                )
                // Pick best audio
                let bestAudio = dash.audio?
                    .sorted { ($0.bandwidth ?? 0) > ($1.bandwidth ?? 0) }
                    .first

                return PlayStream(
                    url: videoURL,
                    backupURLs: (video.backupUrl ?? []).compactMap(URL.init(string:)),
                    audioURL: bestAudio.flatMap { URL(string: $0.baseUrl) },
                    audioBackupURLs: (bestAudio?.backupUrl ?? []).compactMap(URL.init(string:)),
                    codecId: video.codecid
                )
            }

            if let fallback = candidates.first(where: { !$0.baseUrl.isEmpty && URL(string: $0.baseUrl) != nil }),
               let videoURL = URL(string: fallback.baseUrl) {
                DebugLogStore.shared.log(
                    category: "player.playurl",
                    message: "fallback pick q=\(quality) id=\(fallback.id) codec=\(fallback.codecid ?? -1) bw=\(fallback.bandwidth ?? 0) size=\(fallback.width ?? 0)x\(fallback.height ?? 0) dashCount=\(videos.count)"
                )
                let bestAudio = dash.audio?
                    .sorted { ($0.bandwidth ?? 0) > ($1.bandwidth ?? 0) }
                    .first

                return PlayStream(
                    url: videoURL,
                    backupURLs: (fallback.backupUrl ?? []).compactMap(URL.init(string:)),
                    audioURL: bestAudio.flatMap { URL(string: $0.baseUrl) },
                    audioBackupURLs: (bestAudio?.backupUrl ?? []).compactMap(URL.init(string:)),
                    codecId: fallback.codecid
                )
            }
        }

        // Fallback to durl
        guard let first = response.durl.first, let primaryURL = URL(string: first.url) else {
            throw BiliError.noStream
        }

        return PlayStream(
            url: primaryURL,
            backupURLs: (first.backupUrl ?? []).compactMap(URL.init(string:))
        )
    }

    func fetchOfflineDownloadStream(bvid: String, cid: Int64, quality: Int = 32) async throws -> PlayStream {
        let response = try await client.request(.playURLDownloadWbi(bvid: bvid, cid: cid, quality: quality), as: PlayURLResponse.self)

        // Prefer progressive downloadable stream first; DASH-only fragments can fail for local playback.
        if let first = response.durl.first, let primaryURL = URL(string: first.url) {
            return PlayStream(
                url: primaryURL,
                backupURLs: (first.backupUrl ?? []).compactMap(URL.init(string:))
            )
        }
        DebugLogStore.shared.log(
            category: "download",
            message: "no progressive durl stream for bvid=\(bvid) cid=\(cid) q=\(quality)"
        )
        // Fallback to DASH package (video + audio) for offline packaging.
        return try await fetchPlayURL(
            bvid: bvid,
            cid: cid,
            quality: quality,
            preferredCodec: .avc,
            streamFormat: .dash
        )
    }

    func fetchComments(aid: Int64, page: Int) async throws -> [CommentItem] {
        let response = try await client.request(.comments(aid: aid, page: page), as: CommentResponse.self)
        return (response.replies ?? []).map { reply in
            CommentItem(
                id: reply.rpid.value64,
                oid: aid,
                mid: reply.member?.mid.value64,
                username: reply.member?.uname ?? L10n.t("label.user"),
                avatarURL: URL.biliImageURL(from: reply.member?.avatar ?? ""),
                message: reply.content?.message ?? "",
                likeCount: reply.like.value,
                timestamp: Date(timeIntervalSince1970: TimeInterval(reply.ctime.value)),
                replyCount: reply.repliesCount.value
            )
        }
    }

    func fetchUploader(mid: Int, page: Int) async throws -> (UploaderProfile, [BiliVideo]) {
        let uploader = try await client.request(.uploader(mid: mid), as: UploaderResponse.self)
        let videos = try await client.request(.uploaderVideos(mid: mid, page: page, order: "pubdate"), as: UploaderVideosResponse.self)
        let relation = try? await client.request(.uploaderRelation(mid: mid), as: UploaderRelationResponse.self)
        let upStat = try? await client.request(.uploaderUpStat(mid: mid), as: UploaderUpStatResponse.self)

        let profile = UploaderProfile(
            id: uploader.mid.value,
            name: uploader.name,
            avatarURL: URL.biliImageURL(from: uploader.face),
            signature: uploader.sign,
            followerCount: uploader.fans.value,
            followingCount: relation?.following.value ?? 0,
            likeCount: upStat?.likes.value ?? 0
        )

        let mappedVideos = (videos.list?.vlist ?? []).map { item in
            BiliVideo(
                bvid: item.bvid,
                aid: item.aid.value64,
                title: item.title,
                author: uploader.name,
                mid: uploader.mid.value,
                coverURL: URL.biliImageURL(from: item.pic),
                viewCount: item.play.value,
                danmakuCount: item.videoReview.value,
                durationText: item.length,
                publishedAt: item.publishedAt,
                description: item.description
            )
        }

        return (profile, mappedVideos)
    }

    func fetchUploaderVideos(mid: Int, page: Int, order: String) async throws -> [BiliVideo] {
        let uploader = try await client.request(.uploader(mid: mid), as: UploaderResponse.self)
        let videos = try await client.request(.uploaderVideos(mid: mid, page: page, order: order), as: UploaderVideosResponse.self)
        return (videos.list?.vlist ?? []).map { item in
            BiliVideo(
                bvid: item.bvid,
                aid: item.aid.value64,
                title: item.title,
                author: uploader.name,
                mid: uploader.mid.value,
                coverURL: URL.biliImageURL(from: item.pic),
                viewCount: item.play.value,
                danmakuCount: item.videoReview.value,
                durationText: item.length,
                publishedAt: item.publishedAt,
                description: item.description
            )
        }
    }

    func fetchUploaderArticles(mid: Int, page: Int) async throws -> [UploaderArticle] {
        let response = try await client.request(.uploaderArticles(mid: mid, page: page), as: UploaderArticlesResponse.self)
        return response.items.map { item in
            UploaderArticle(
                id: item.id.value,
                title: item.title,
                summary: item.summary,
                imageURL: URL.biliImageURL(from: item.bannerURL),
                publishedAt: item.publishedAt,
                viewCount: item.view.value
            )
        }
    }

    func fetchUploaderTopVideo(mid: Int) async throws -> BiliVideo? {
        let uploader = try await client.request(.uploader(mid: mid), as: UploaderResponse.self)
        let top = try await client.request(.uploaderTopVideo(mid: mid), as: UploaderTopVideoResponse.self)
        guard let video = top.video else { return nil }
        return BiliVideo(
            bvid: video.bvid,
            aid: video.aid.value64,
            title: video.title,
            author: uploader.name,
            mid: uploader.mid.value,
            coverURL: URL.biliImageURL(from: video.pic),
            viewCount: video.play?.value ?? 0,
            danmakuCount: video.danmaku?.value ?? 0,
            durationText: video.duration.value.durationString,
            publishedAt: video.pubdate.value > 0 ? Date(timeIntervalSince1970: TimeInterval(video.pubdate.value)) : nil,
            description: video.desc
        )
    }

    func fetchUploaderMasterpieces(mid: Int, page: Int) async throws -> [BiliVideo] {
        let uploader = try await client.request(.uploader(mid: mid), as: UploaderResponse.self)
        let response = try await client.request(.uploaderMasterpiece(mid: mid, page: page), as: UploaderMasterpieceResponse.self)
        return response.items.map { item in
            BiliVideo(
                bvid: item.bvid,
                aid: item.aid.value64,
                title: item.title,
                author: uploader.name,
                mid: uploader.mid.value,
                coverURL: URL.biliImageURL(from: item.pic),
                viewCount: item.play.value,
                danmakuCount: item.danmaku.value,
                durationText: item.durationText,
                publishedAt: item.pubdate.value > 0 ? Date(timeIntervalSince1970: TimeInterval(item.pubdate.value)) : nil,
                description: item.desc
            )
        }
    }

    func fetchUploaderRelationState(mid: Int) async throws -> UploaderRelationState {
        let response = try await client.request(.uploaderAccRelation(mid: mid), as: UploaderAccRelationResponse.self)
        let attr = response.beRelation.attribute.value
        let isFollowing = (attr & 2) != 0
        let isFollowedBy = (attr & 1) != 0
        return UploaderRelationState(isFollowing: isFollowing, isFollowedBy: isFollowedBy, attribute: attr)
    }

    func fetchDynamics(scope: DynamicsScope, offset: String?) async throws -> DynamicsPage {
        let endpoint: BiliEndpoint
        switch scope {
        case .following:
            endpoint = .dynamicFeedAll(offset: offset)
        case .mine:
            guard let mid = await BiliAuthStore.shared.loggedInMid() else {
                throw BiliError.unauthorized
            }
            endpoint = .dynamicFeedSpace(hostMid: mid, offset: offset)
        case let .user(mid, _):
            endpoint = .dynamicFeedSpace(hostMid: mid, offset: offset)
        }

        let response = try await client.request(endpoint, as: DynamicFeedResponse.self)
        let items = response.items.compactMap(Self.mapDynamicItem)
        let hasMore = response.hasMore.value == 1 || !(response.offset?.isEmpty ?? true)
        return DynamicsPage(items: items, nextOffset: response.offset, hasMore: hasMore)
    }

    func fetchDynamicDetail(dynamicID: Int64) async throws -> DynamicItem {
        let response = try await client.request(.dynamicDetail(dynamicID: dynamicID), as: DynamicDetailResponse.self)
        guard let item = Self.mapDynamicItem(response.item) else {
            throw BiliError.badResponse
        }
        return item
    }

    private static func mapDynamicItem(_ dto: DynamicFeedResponse.ItemDTO) -> DynamicItem? {
        let id = dto.idStr?.value64 ?? dto.basic?.commentIDStr?.value64 ?? 0
        guard id > 0 else { return nil }

        let author = dto.modules?.author
        let stat = dto.modules?.stat
        let dynamic = dto.modules?.dynamic

        let text = (dynamic?.desc?.richTextNodes?.map(\.text).joined() ?? "").decodeHTMLEntities()
        var kind: DynamicKind = .text
        var video: DynamicVideoPayload?
        var opus: DynamicOpusPayload?

        if let major = dynamic?.major {
            switch major.type {
            case "MAJOR_TYPE_ARCHIVE":
                if let archive = major.archive {
                    kind = .video
                    video = DynamicVideoPayload(
                        bvid: archive.bvid ?? "",
                        aid: archive.aid?.value64 ?? 0,
                        cid: archive.cid?.value64,
                        title: archive.title ?? "",
                        coverURL: URL.biliImageURL(from: archive.cover ?? "")
                    )
                }
            case "MAJOR_TYPE_OPUS", "MAJOR_TYPE_DRAW":
                kind = .opus
                let pics = (major.opus?.pics ?? []).compactMap { URL.biliImageURL(from: $0.url) }
                opus = DynamicOpusPayload(title: major.opus?.title ?? "", imageURLs: pics)
            default:
                kind = .unknown
            }
        } else if dto.orig != nil {
            kind = .forward
        }

        let forwardPreview = dto.orig?.modules?.dynamic?.desc?.richTextNodes?.map(\.text).joined().decodeHTMLEntities()
        let commentType = dto.basic?.commentType?.value ?? 17
        let commentOID = dto.basic?.commentIDStr?.value64 ?? id

        return DynamicItem(
            id: id,
            authorMid: author?.mid?.value ?? 0,
            authorName: author?.name ?? L10n.t("label.uploader.unknown"),
            authorAvatarURL: URL.biliImageURL(from: author?.face ?? ""),
            publishedAt: author?.pubTs?.asDate,
            text: text,
            kind: kind,
            video: video,
            opus: opus,
            forwardedTextPreview: forwardPreview,
            stats: DynamicStat(
                likeCount: stat?.like?.value ?? 0,
                repostCount: stat?.forward?.value ?? 0,
                commentCount: stat?.reply?.value ?? 0
            ),
            isLiked: (stat?.isLike?.value ?? 0) == 1,
            commentResource: DynamicCommentResource(type: commentType, oid: commentOID)
        )
    }
}

private struct DynamicFeedResponse: Decodable {
    struct ItemDTO: Decodable {
        struct BasicDTO: Decodable {
            let commentType: LossyInt?
            let commentIDStr: LossyInt?

            private enum CodingKeys: String, CodingKey {
                case commentType
                case commentIDStr = "comment_id_str"
            }
        }

        struct ModulesDTO: Decodable {
            struct AuthorDTO: Decodable {
                let mid: LossyInt?
                let name: String?
                let face: String?
                let pubTs: LossyInt?

                private enum CodingKeys: String, CodingKey {
                    case mid
                    case name
                    case face
                    case pubTs = "pub_ts"
                }
            }

            struct StatDTO: Decodable {
                let like: LossyInt?
                let reply: LossyInt?
                let forward: LossyInt?
                let isLike: LossyInt?
            }

            struct DynamicDTO: Decodable {
                struct DescDTO: Decodable {
                    struct RichTextNodeDTO: Decodable {
                        let text: String
                    }

                    let richTextNodes: [RichTextNodeDTO]?

                    private enum CodingKeys: String, CodingKey {
                        case richTextNodes = "rich_text_nodes"
                    }
                }

                struct MajorDTO: Decodable {
                    struct ArchiveDTO: Decodable {
                        let bvid: String?
                        let aid: LossyInt?
                        let cid: LossyInt?
                        let title: String?
                        let cover: String?
                    }

                    struct OpusDTO: Decodable {
                        struct PicDTO: Decodable {
                            let url: String
                        }

                        let title: String?
                        let pics: [PicDTO]?
                    }

                    let type: String
                    let archive: ArchiveDTO?
                    let opus: OpusDTO?
                }

                let desc: DescDTO?
                let major: MajorDTO?
            }

            let author: AuthorDTO?
            let stat: StatDTO?
            let dynamic: DynamicDTO?

            private enum CodingKeys: String, CodingKey {
                case author = "module_author"
                case stat = "module_stat"
                case dynamic = "module_dynamic"
            }
        }

        struct OrigDTO: Decodable {
            struct ModulesDTO: Decodable {
                struct DynamicDTO: Decodable {
                    struct DescDTO: Decodable {
                        struct RichTextNodeDTO: Decodable {
                            let text: String
                        }

                        let richTextNodes: [RichTextNodeDTO]?

                        private enum CodingKeys: String, CodingKey {
                            case richTextNodes = "rich_text_nodes"
                        }
                    }

                    let desc: DescDTO?
                }

                let dynamic: DynamicDTO?

                private enum CodingKeys: String, CodingKey {
                    case dynamic = "module_dynamic"
                }
            }

            let modules: ModulesDTO?
        }

        let idStr: LossyInt?
        let basic: BasicDTO?
        let modules: ModulesDTO?
        let orig: OrigDTO?

        private enum CodingKeys: String, CodingKey {
            case idStr = "id_str"
            case basic
            case modules
            case orig
        }
    }

    let items: [ItemDTO]
    let offset: String?
    let hasMore: LossyInt

    private enum CodingKeys: String, CodingKey {
        case items
        case offset
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode([ItemDTO].self, forKey: .items)) ?? []
        offset = try? c.decodeIfPresent(String.self, forKey: .offset)
        hasMore = c.decodeLossyInt(forKey: .hasMore)
    }
}

private struct DynamicDetailResponse: Decodable {
    let item: DynamicFeedResponse.ItemDTO
}

private struct LossyInt: Decodable {
    let value: Int
    /// Full 64-bit value — use for fields like cid/aid that can exceed Int32.max on watchOS arm64_32.
    let value64: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
            value64 = Int64(intValue)
        } else if let int64Value = try? container.decode(Int64.self) {
            value = Int(exactly: int64Value) ?? (int64Value > 0 ? Int.max : Int.min)
            value64 = int64Value
        } else if let doubleValue = try? container.decode(Double.self) {
            if !doubleValue.isFinite {
                value = 0
                value64 = 0
            } else if doubleValue >= Double(Int.max) {
                value = Int.max
                value64 = Int64(doubleValue)
            } else if doubleValue <= Double(Int.min) {
                value = Int.min
                value64 = Int64(doubleValue)
            } else {
                value = Int(doubleValue)
                value64 = Int64(doubleValue)
            }
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue.boundedIntValue ?? 0
            value64 = stringValue.boundedInt64Value ?? 0
        } else {
            value = 0
            value64 = 0
        }
    }

    init(_ value: Int) {
        self.value = value
        self.value64 = Int64(value)
    }

    init(int64 value: Int64) {
        self.value = Int(exactly: value) ?? (value > 0 ? Int.max : Int.min)
        self.value64 = value
    }
}

private extension LossyInt {
    var asDate: Date? {
        guard value64 > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(value64))
    }
}

private extension String {
    var boundedIntValue: Int? {
        let digits = replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
        guard !digits.isEmpty else { return nil }
        if let parsed = Int(digits) {
            return parsed
        }
        if let parsed64 = Int64(digits) {
            return Int(exactly: parsed64) ?? (parsed64 > 0 ? Int.max : Int.min)
        }
        if let parsedDouble = Double(digits), parsedDouble.isFinite {
            if parsedDouble >= Double(Int.max) { return Int.max }
            if parsedDouble <= Double(Int.min) { return Int.min }
            return Int(parsedDouble)
        }
        return nil
    }

    var boundedInt64Value: Int64? {
        let digits = replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
        guard !digits.isEmpty else { return nil }
        if let parsed = Int64(digits) { return parsed }
        if let parsedDouble = Double(digits), parsedDouble.isFinite {
            return Int64(parsedDouble)
        }
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeString(forKey key: Key, default defaultValue: String = "") -> String {
        ((try? decodeIfPresent(String.self, forKey: key)) ?? defaultValue).decodeHTMLEntities()
    }

    func decodeLossyInt(forKey key: Key, default defaultValue: Int = 0) -> LossyInt {
        (try? decodeIfPresent(LossyInt.self, forKey: key)) ?? LossyInt(defaultValue)
    }
}

private struct PopularResponse: Decodable {
    let list: [PopularVideoDTO]

    private enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decodeIfPresent([PopularVideoDTO].self, forKey: .list)) ?? []
    }
}

private struct RecommendResponse: Decodable {
    let item: [PopularVideoDTO]

    private enum CodingKeys: String, CodingKey { case item }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        item = (try? c.decodeIfPresent([PopularVideoDTO].self, forKey: .item)) ?? []
    }
}

private struct PopularVideoDTO: Decodable {
    struct OwnerDTO: Decodable {
        let name: String
        let mid: LossyInt

        private enum CodingKeys: String, CodingKey { case name, mid }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.decodeString(forKey: .name, default: L10n.t("label.uploader.unknown"))
            mid = c.decodeLossyInt(forKey: .mid)
        }
    }

    struct StatDTO: Decodable {
        let view: LossyInt
        let danmaku: LossyInt

        private enum CodingKeys: String, CodingKey { case view, danmaku }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            view = c.decodeLossyInt(forKey: .view)
            danmaku = c.decodeLossyInt(forKey: .danmaku)
        }
    }

    let bvid: String
    let aid: LossyInt
    let title: String
    let pic: String
    let duration: LossyInt
    let pubdate: LossyInt
    let desc: String
    let owner: OwnerDTO
    let stat: StatDTO

    private enum CodingKeys: String, CodingKey {
        case bvid, aid, title, pic, duration, pubdate, desc, owner, stat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bvid = c.decodeString(forKey: .bvid)
        aid = c.decodeLossyInt(forKey: .aid)
        title = c.decodeString(forKey: .title)
        pic = c.decodeString(forKey: .pic)
        duration = c.decodeLossyInt(forKey: .duration)
        pubdate = c.decodeLossyInt(forKey: .pubdate)
        desc = c.decodeString(forKey: .desc)
        owner = (try? c.decode(OwnerDTO.self, forKey: .owner)) ?? OwnerDTO(name: L10n.t("label.uploader.unknown"), mid: LossyInt(0))
        stat = (try? c.decode(StatDTO.self, forKey: .stat)) ?? StatDTO(view: LossyInt(0), danmaku: LossyInt(0))
    }

    var publishedAt: Date? {
        guard pubdate.value > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(pubdate.value))
    }
}

private struct SearchResponse: Decodable {
    let result: [SearchVideoDTO]

    private enum CodingKeys: String, CodingKey { case result }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        result = (try? c.decodeIfPresent([SearchVideoDTO].self, forKey: .result)) ?? []
    }
}

private struct UserSearchResponse: Decodable {
    let result: [UserSearchDTO]

    private enum CodingKeys: String, CodingKey { case result }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        result = (try? c.decodeIfPresent([UserSearchDTO].self, forKey: .result)) ?? []
    }
}

private struct UserSearchDTO: Decodable {
    let mid: LossyInt
    let uname: String
    let usign: String
    let upic: String
    let fans: LossyInt

    private enum CodingKeys: String, CodingKey {
        case mid, uname, usign, upic, fans
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mid = c.decodeLossyInt(forKey: .mid)
        uname = c.decodeString(forKey: .uname, default: L10n.t("label.uploader"))
        usign = c.decodeString(forKey: .usign)
        upic = c.decodeString(forKey: .upic)
        fans = c.decodeLossyInt(forKey: .fans)
    }
}

private struct ArticleSearchResponse: Decodable {
    let result: [ArticleSearchDTO]

    private enum CodingKeys: String, CodingKey { case result }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        result = (try? c.decodeIfPresent([ArticleSearchDTO].self, forKey: .result)) ?? []
    }
}

private struct ArticleSearchDTO: Decodable {
    let id: LossyInt
    let title: String
    let author: String
    let desc: String
    let imageUrls: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case desc
        case imageUrls = "image_urls"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyInt(forKey: .id)
        title = c.decodeString(forKey: .title)
        author = c.decodeString(forKey: .author, default: L10n.t("label.article"))
        desc = c.decodeString(forKey: .desc)
        imageUrls = (try? c.decodeIfPresent([String].self, forKey: .imageUrls)) ?? []
    }
}

private struct SearchVideoDTO: Decodable {
    let bvid: String
    let aid: LossyInt
    let title: String
    let author: String
    let mid: LossyInt?
    let pic: String
    let play: LossyInt
    let danmaku: LossyInt
    let duration: DurationUnion
    let pubdate: LossyInt
    let description: String

    private enum CodingKeys: String, CodingKey {
        case bvid, aid, title, author, mid, pic, play, danmaku, duration, pubdate, description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bvid = c.decodeString(forKey: .bvid)
        aid = c.decodeLossyInt(forKey: .aid)
        title = c.decodeString(forKey: .title)
        author = c.decodeString(forKey: .author, default: L10n.t("label.uploader.unknown"))
        mid = try? c.decodeIfPresent(LossyInt.self, forKey: .mid)
        pic = c.decodeString(forKey: .pic)
        play = c.decodeLossyInt(forKey: .play)
        danmaku = c.decodeLossyInt(forKey: .danmaku)
        pubdate = c.decodeLossyInt(forKey: .pubdate)
        if let decodedDuration = try? c.decodeIfPresent(DurationUnion.self, forKey: .duration) {
            duration = decodedDuration
        } else {
            duration = .text("00:00")
        }
        description = c.decodeString(forKey: .description)
    }

    var durationText: String {
        switch duration {
        case let .seconds(seconds):
            return seconds.value.durationString
        case let .text(text):
            return text
        }
    }

    var publishedAt: Date? {
        guard pubdate.value > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(pubdate.value))
    }
}

private enum DurationUnion: Decodable {
    case seconds(LossyInt)
    case text(String)

    init(from decoder: Decoder) throws {
        if let intValue = try? LossyInt(from: decoder) {
            self = .seconds(intValue)
            return
        }
        if let text = try? String(from: decoder) {
            self = .text(text)
            return
        }
        self = .text("00:00")
    }
}

private struct VideoDetailResponse: Decodable {
    struct OwnerDTO: Decodable {
        let mid: LossyInt
        let name: String
        let face: String

        private enum CodingKeys: String, CodingKey { case mid, name, face }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mid = c.decodeLossyInt(forKey: .mid)
            name = c.decodeString(forKey: .name, default: L10n.t("label.uploader"))
            face = c.decodeString(forKey: .face)
        }
    }

    struct StatDTO: Decodable {
        let view: LossyInt
        let danmaku: LossyInt
        let reply: LossyInt
        let favorite: LossyInt
        let coin: LossyInt
        let share: LossyInt

        private enum CodingKeys: String, CodingKey { case view, danmaku, reply, favorite, coin, share }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            view = c.decodeLossyInt(forKey: .view)
            danmaku = c.decodeLossyInt(forKey: .danmaku)
            reply = c.decodeLossyInt(forKey: .reply)
            favorite = c.decodeLossyInt(forKey: .favorite)
            coin = c.decodeLossyInt(forKey: .coin)
            share = c.decodeLossyInt(forKey: .share)
        }
    }

    let bvid: String
    let aid: LossyInt
    let cid: LossyInt
    let title: String
    let desc: String
    let pic: String
    let duration: LossyInt
    let owner: OwnerDTO
    let stat: StatDTO

    private enum CodingKeys: String, CodingKey {
        case bvid, aid, cid, title, desc, pic, duration, owner, stat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bvid = c.decodeString(forKey: .bvid)
        aid = c.decodeLossyInt(forKey: .aid)
        cid = c.decodeLossyInt(forKey: .cid)
        title = c.decodeString(forKey: .title)
        desc = c.decodeString(forKey: .desc)
        pic = c.decodeString(forKey: .pic)
        duration = c.decodeLossyInt(forKey: .duration)
        owner = (try? c.decode(OwnerDTO.self, forKey: .owner)) ?? OwnerDTO(mid: LossyInt(0), name: L10n.t("label.uploader"), face: "")
        stat = (try? c.decode(StatDTO.self, forKey: .stat)) ?? StatDTO(view: LossyInt(0), danmaku: LossyInt(0), reply: LossyInt(0), favorite: LossyInt(0), coin: LossyInt(0), share: LossyInt(0))
    }
}

private struct PlayURLResponse: Decodable {
    struct DURL: Decodable {
        let url: String
        let backupUrl: [String]?

        private enum CodingKeys: String, CodingKey {
            case url
            case backupUrl
            case backup_url
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            url = c.decodeString(forKey: .url)
            backupUrl = (try? c.decodeIfPresent([String].self, forKey: .backupUrl))
                ?? (try? c.decodeIfPresent([String].self, forKey: .backup_url))
        }
    }

    struct DASHData: Decodable {
        struct Stream: Decodable {
            let id: Int
            let codecid: Int?
            let baseUrl: String
            let backupUrl: [String]?
            let bandwidth: Int?
            let width: Int?
            let height: Int?

            private enum CodingKeys: String, CodingKey {
                case id, codecid
                case base_url, baseUrl
                case backup_url, backupUrl
                case bandwidth, width, height
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                id = (try? c.decodeIfPresent(Int.self, forKey: .id)) ?? 0
                codecid = try? c.decodeIfPresent(Int.self, forKey: .codecid)
                baseUrl = c.decodeString(forKey: .base_url, default: c.decodeString(forKey: .baseUrl))
                backupUrl = (try? c.decodeIfPresent([String].self, forKey: .backup_url))
                    ?? (try? c.decodeIfPresent([String].self, forKey: .backupUrl))
                bandwidth = try? c.decodeIfPresent(Int.self, forKey: .bandwidth)
                width = try? c.decodeIfPresent(Int.self, forKey: .width)
                height = try? c.decodeIfPresent(Int.self, forKey: .height)
            }
        }
        let video: [Stream]?
        let audio: [Stream]?
    }

    let dash: DASHData?
    let durl: [DURL]

    private enum CodingKeys: String, CodingKey { case dash, durl }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dash = try? c.decodeIfPresent(DASHData.self, forKey: .dash)
        durl = (try? c.decodeIfPresent([DURL].self, forKey: .durl)) ?? []
    }
}

private struct CommentResponse: Decodable {
    let replies: [CommentDTO]?

    private enum CodingKeys: String, CodingKey { case replies }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        replies = try? c.decodeIfPresent([CommentDTO].self, forKey: .replies)
    }
}

private struct CommentDTO: Decodable {
    struct MemberDTO: Decodable {
        let mid: LossyInt
        let uname: String?
        let avatar: String?

        private enum CodingKeys: String, CodingKey { case mid, uname, avatar }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mid = c.decodeLossyInt(forKey: .mid)
            uname = try? c.decodeIfPresent(String.self, forKey: .uname)
            avatar = try? c.decodeIfPresent(String.self, forKey: .avatar)
        }
    }

    struct ContentDTO: Decodable {
        let message: String?

        private enum CodingKeys: String, CodingKey { case message }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            message = try? c.decodeIfPresent(String.self, forKey: .message)
        }
    }

    let rpid: LossyInt
    let like: LossyInt
    let ctime: LossyInt
    let repliesCount: LossyInt
    let member: MemberDTO?
    let content: ContentDTO?

    private enum CodingKeys: String, CodingKey { case rpid, like, ctime, member, content, repliesCount = "rcount" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rpid = c.decodeLossyInt(forKey: .rpid)
        like = c.decodeLossyInt(forKey: .like)
        ctime = c.decodeLossyInt(forKey: .ctime)
        repliesCount = c.decodeLossyInt(forKey: .repliesCount)
        member = try? c.decodeIfPresent(MemberDTO.self, forKey: .member)
        content = try? c.decodeIfPresent(ContentDTO.self, forKey: .content)
    }
}

private struct UploaderResponse: Decodable {
    let mid: LossyInt
    let name: String
    let sign: String
    let face: String
    let fans: LossyInt

    private enum CodingKeys: String, CodingKey { case mid, name, sign, face, fans }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mid = c.decodeLossyInt(forKey: .mid)
        name = c.decodeString(forKey: .name, default: L10n.t("label.uploader"))
        sign = c.decodeString(forKey: .sign)
        face = c.decodeString(forKey: .face)
        fans = c.decodeLossyInt(forKey: .fans)
    }
}

private struct UploaderRelationResponse: Decodable {
    let following: LossyInt

    private enum CodingKeys: String, CodingKey { case following }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        following = c.decodeLossyInt(forKey: .following)
    }
}

private struct UploaderUpStatResponse: Decodable {
    let likes: LossyInt

    private enum CodingKeys: String, CodingKey {
        case likes = "likes"
        case archive = "archive"
    }

    private struct ArchiveDTO: Decodable {
        let view: LossyInt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let likeValue = try? c.decodeIfPresent(LossyInt.self, forKey: .likes) {
            likes = likeValue
        } else if let archive = try? c.decodeIfPresent(ArchiveDTO.self, forKey: .archive) {
            likes = archive.view
        } else {
            likes = LossyInt(0)
        }
    }
}

private struct UploaderAccRelationResponse: Decodable {
    struct BeRelationDTO: Decodable {
        let attribute: LossyInt
    }

    let beRelation: BeRelationDTO

    private enum CodingKeys: String, CodingKey {
        case beRelation = "be_relation"
    }
}

private struct UploaderTopVideoResponse: Decodable {
    struct VideoDTO: Decodable {
        let aid: LossyInt
        let bvid: String
        let title: String
        let pic: String
        let desc: String
        let duration: LossyInt
        let pubdate: LossyInt
        let stat: StatDTO?

        struct StatDTO: Decodable {
            let view: LossyInt?
            let danmaku: LossyInt?
        }

        var play: LossyInt? { stat?.view }
        var danmaku: LossyInt? { stat?.danmaku }
    }

    let video: VideoDTO?

    private enum CodingKeys: String, CodingKey {
        case aid, bvid, title, pic, desc, duration, pubdate, stat
        case top
    }

    init(from decoder: Decoder) throws {
        if let direct = try? VideoDTO(from: decoder) {
            video = direct
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.top), let nested = try? c.decode(VideoDTO.self, forKey: .top) {
            video = nested
        } else {
            video = nil
        }
    }
}

private struct UploaderMasterpieceResponse: Decodable {
    struct ItemDTO: Decodable {
        let aid: LossyInt
        let bvid: String
        let title: String
        let pic: String
        let duration: LossyInt
        let pubdate: LossyInt
        let play: LossyInt
        let danmaku: LossyInt
        let desc: String

        private enum CodingKeys: String, CodingKey {
            case aid, bvid, title, pic, duration, pubdate, play, danmaku, desc
        }

        var durationText: String {
            duration.value.durationString
        }
    }

    let items: [ItemDTO]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let list = try? c.decode([ItemDTO].self) {
            items = list
        } else {
            items = []
        }
    }
}

private struct UploaderVideosResponse: Decodable {
    struct ArcList: Decodable {
        let vlist: [ArcVideo]?

        private enum CodingKeys: String, CodingKey { case vlist }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            vlist = try? c.decodeIfPresent([ArcVideo].self, forKey: .vlist)
        }
    }

    struct ArcVideo: Decodable {
        let aid: LossyInt
        let bvid: String
        let title: String
        let pic: String
        let play: LossyInt
        let videoReview: LossyInt
        let length: String
        let created: LossyInt
        let description: String

        private enum CodingKeys: String, CodingKey {
            case aid, bvid, title, pic, play, videoReview, length, created, description
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            aid = c.decodeLossyInt(forKey: .aid)
            bvid = c.decodeString(forKey: .bvid)
            title = c.decodeString(forKey: .title)
            pic = c.decodeString(forKey: .pic)
            play = c.decodeLossyInt(forKey: .play)
            videoReview = c.decodeLossyInt(forKey: .videoReview)
            length = c.decodeString(forKey: .length, default: "00:00")
            created = c.decodeLossyInt(forKey: .created)
            description = c.decodeString(forKey: .description)
        }

        var publishedAt: Date? {
            guard created.value > 0 else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(created.value))
        }
    }

    let list: ArcList?

    private enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = try? c.decodeIfPresent(ArcList.self, forKey: .list)
    }
}

private struct UploaderArticlesResponse: Decodable {
    struct ArticleDTO: Decodable {
        let id: LossyInt
        let title: String
        let summary: String
        let bannerURL: String
        let view: LossyInt
        let publishTime: LossyInt

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case summary
            case bannerURL = "banner_url"
            case imageURL = "image_url"
            case view
            case stats
            case publishTime = "publish_time"
            case ctime
        }

        private struct StatsDTO: Decodable {
            let view: LossyInt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = c.decodeLossyInt(forKey: .id)
            title = c.decodeString(forKey: .title)
            summary = c.decodeString(forKey: .summary)
            bannerURL =
                (try? c.decodeIfPresent(String.self, forKey: .bannerURL)) ??
                (try? c.decodeIfPresent(String.self, forKey: .imageURL)) ??
                ""
            if let direct = try? c.decode(LossyInt.self, forKey: .view) {
                view = direct
            } else if let stats = try? c.decode(StatsDTO.self, forKey: .stats) {
                view = stats.view
            } else {
                view = LossyInt(0)
            }
            publishTime =
                (try? c.decodeIfPresent(LossyInt.self, forKey: .publishTime)) ??
                (try? c.decodeIfPresent(LossyInt.self, forKey: .ctime)) ??
                LossyInt(0)
        }

        var publishedAt: Date? {
            guard publishTime.value > 0 else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(publishTime.value))
        }
    }

    let items: [ArticleDTO]

    private enum CodingKeys: String, CodingKey {
        case articles
        case list
    }

    private struct ListContainer: Decodable {
        let articles: [ArticleDTO]?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let direct = try? c.decode([ArticleDTO].self, forKey: .articles) {
            items = direct
            return
        }
        if let list = try? c.decode(ListContainer.self, forKey: .list), let nested = list.articles {
            items = nested
            return
        }
        items = []
    }
}

private extension String {
    func cleanHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .decodeHTMLEntities()
    }

    func decodeHTMLEntities() -> String {
        self
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

private extension URL {
    static func biliImageURL(from value: String) -> URL? {
        let raw: String
        if value.hasPrefix("//") {
            raw = "https:\(value)"
        } else if value.hasPrefix("http://") {
            raw = "https://" + value.dropFirst("http://".count)
        } else {
            raw = value
        }

        guard var components = URLComponents(string: raw) else {
            return URL(string: raw)
        }

        if components.scheme == "http" {
            components.scheme = "https"
        }

        return components.url
    }
}

private extension Int {
    var durationString: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


private extension PopularVideoDTO.OwnerDTO {
    init(name: String, mid: LossyInt) {
        self.name = name
        self.mid = mid
    }
}

private extension PopularVideoDTO.StatDTO {
    init(view: LossyInt, danmaku: LossyInt) {
        self.view = view
        self.danmaku = danmaku
    }
}

private extension VideoDetailResponse.OwnerDTO {
    init(mid: LossyInt, name: String, face: String) {
        self.mid = mid
        self.name = name
        self.face = face
    }
}

private extension VideoDetailResponse.StatDTO {
    init(view: LossyInt, danmaku: LossyInt, reply: LossyInt, favorite: LossyInt, coin: LossyInt, share: LossyInt) {
        self.view = view
        self.danmaku = danmaku
        self.reply = reply
        self.favorite = favorite
        self.coin = coin
        self.share = share
    }
}
