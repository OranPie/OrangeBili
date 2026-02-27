import Combine
import Foundation

@MainActor
public final class BiliAPIBackend: ObservableObject, BiliServiceProtocol {
    public static let shared = BiliAPIBackend()

    @Published public private(set) var isLoggedIn = false
    @Published public private(set) var loggedInMid: Int?

    private let service: BiliServiceProtocol
    private let authStore: BiliAuthStore

    init(service: BiliServiceProtocol = BiliService(client: NetworkClient()), authStore: BiliAuthStore = .shared) {
        self.service = service
        self.authStore = authStore

        Task {
            await refreshAuthState()
        }
    }

    public func updateLoginSession(
        sessdata: String,
        biliJct: String? = nil,
        dedeUserID: String? = nil,
        buvid3: String? = nil,
        buvid4: String? = nil
    ) async {
        let session = BiliLoginSession(
            sessdata: sessdata,
            biliJct: biliJct,
            dedeUserID: dedeUserID,
            buvid3: buvid3,
            buvid4: buvid4
        )
        await authStore.update(session: session)
        await refreshAuthState()
        DebugLogStore.shared.log(category: "backend", message: "update login session done loggedIn=\(isLoggedIn)")
    }

    public func clearLoginSession() async {
        await authStore.update(session: nil)
        await refreshAuthState()
        DebugLogStore.shared.log(category: "backend", message: "clear login session done loggedIn=\(isLoggedIn)")
    }

    public func refreshAuthState() async {
        isLoggedIn = await authStore.isLoggedIn()
        loggedInMid = await authStore.loggedInMid()
        DebugLogStore.shared.log(category: "backend", message: "refresh auth state loggedIn=\(isLoggedIn) mid=\(loggedInMid ?? 0)")
    }

    public func fetchPopular(page: Int, size: Int) async throws -> [BiliVideo] {
        try await service.fetchPopular(page: page, size: size)
    }

    public func fetchRecommendFeed(page: Int) async throws -> [BiliVideo] {
        try await service.fetchRecommendFeed(page: page)
    }

    public func searchVideos(keyword: String, page: Int, order: String) async throws -> [BiliVideo] {
        try await service.searchVideos(keyword: keyword, page: page, order: order)
    }

    public func searchUsers(keyword: String, page: Int) async throws -> [UserSearchResult] {
        try await service.searchUsers(keyword: keyword, page: page)
    }

    public func searchArticles(keyword: String, page: Int) async throws -> [ArticleSearchResult] {
        try await service.searchArticles(keyword: keyword, page: page)
    }

    public func fetchVideoDetail(bvid: String) async throws -> VideoDetail {
        try await service.fetchVideoDetail(bvid: bvid)
    }

    public func fetchPlayURL(bvid: String, cid: Int64, quality: Int, preferredCodec: PreferredCodec, streamFormat: PreferredStreamFormat = .auto) async throws -> PlayStream {
        try await service.fetchPlayURL(bvid: bvid, cid: cid, quality: quality, preferredCodec: preferredCodec, streamFormat: streamFormat)
    }

    public func fetchOfflineDownloadStream(bvid: String, cid: Int64, quality: Int = 32) async throws -> PlayStream {
        try await service.fetchOfflineDownloadStream(bvid: bvid, cid: cid, quality: quality)
    }

    public func fetchComments(aid: Int64, page: Int) async throws -> [CommentItem] {
        try await service.fetchComments(aid: aid, page: page)
    }

    public func fetchUploader(mid: Int, page: Int) async throws -> (UploaderProfile, [BiliVideo]) {
        try await service.fetchUploader(mid: mid, page: page)
    }

    public func fetchUploaderVideos(mid: Int, page: Int, order: String = "pubdate") async throws -> [BiliVideo] {
        try await service.fetchUploaderVideos(mid: mid, page: page, order: order)
    }

    public func fetchUploaderArticles(mid: Int, page: Int) async throws -> [UploaderArticle] {
        try await service.fetchUploaderArticles(mid: mid, page: page)
    }

    public func fetchUploaderTopVideo(mid: Int) async throws -> BiliVideo? {
        try await service.fetchUploaderTopVideo(mid: mid)
    }

    public func fetchUploaderMasterpieces(mid: Int, page: Int = 1) async throws -> [BiliVideo] {
        try await service.fetchUploaderMasterpieces(mid: mid, page: page)
    }

    public func fetchUploaderRelationState(mid: Int) async throws -> UploaderRelationState {
        try await service.fetchUploaderRelationState(mid: mid)
    }

    public func followUploader(mid: Int) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "fid": String(mid),
            "act": "1",
            "re_src": "11",
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/relation/modify", body: body)
    }

    public func unfollowUploader(mid: Int) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "fid": String(mid),
            "act": "2",
            "re_src": "11",
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/relation/modify", body: body)
    }

    public func fetchDynamics(scope: DynamicsScope, offset: String? = nil) async throws -> DynamicsPage {
        try await service.fetchDynamics(scope: scope, offset: offset)
    }

    public func fetchDynamicDetail(dynamicID: Int64) async throws -> DynamicItem {
        try await service.fetchDynamicDetail(dynamicID: dynamicID)
    }

    public func fetchMyUploader() async throws -> (UploaderProfile, [BiliVideo]) {
        guard let mid = await authStore.loggedInMid() else {
            throw BiliError.unauthorized
        }
        return try await fetchUploader(mid: mid, page: 1)
    }

    public func fetchCloudFavoriteFolders() async throws -> [CloudFavoriteFolder] {
        guard let mid = await authStore.loggedInMid() else {
            throw BiliError.unauthorized
        }

        let request = try await makeAuthedRequest(
            host: "api.bilibili.com",
            path: "/x/v3/fav/folder/created/list-all",
            method: "GET",
            query: [
                "up_mid": String(mid),
                "type": "2",
                "rid": "0"
            ]
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try JSONDecoder().decode(FavFolderEnvelope.self, from: data)
        guard envelope.code == 0 else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }

        return (envelope.data?.list ?? []).map {
            CloudFavoriteFolder(id: $0.id.asInt, title: $0.title, mediaCount: $0.mediaCount.asInt)
        }
    }

    public func fetchCloudFavoriteVideos(mediaID: Int, page: Int = 1, pageSize: Int = 20) async throws -> [BiliVideo] {
        let request = try await makeAuthedRequest(
            host: "api.bilibili.com",
            path: "/x/v3/fav/resource/list",
            method: "GET",
            query: [
                "media_id": String(mediaID),
                "pn": String(page),
                "ps": String(pageSize),
                "platform": "web",
                "type": "0"
            ]
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try JSONDecoder().decode(FavMediaEnvelope.self, from: data)
        guard envelope.code == 0 else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }

        return (envelope.data?.medias ?? []).map {
            BiliVideo(
                bvid: $0.bvid,
                aid: $0.id.asInt64,
                title: $0.title,
                author: $0.upper?.name ?? L10n.t("favorites.cloud.defaultAuthor"),
                mid: $0.upper?.mid.asInt,
                coverURL: normalizedImageURL($0.cover),
                viewCount: $0.cntInfo?.play.asInt ?? 0,
                danmakuCount: $0.cntInfo?.danmaku.asInt ?? 0,
                durationText: Int($0.duration.asInt).durationString,
                description: "",
                sourceTag: L10n.t("favorites.cloud.source")
            )
        }
    }

    public func likeVideo(aid: Int64, bvid: String? = nil, liked: Bool) async throws {
        let csrf = try await requireCSRFToken()
        var body = [
            "aid": String(aid),
            "like": liked ? "1" : "2",
            "csrf": csrf
        ]
        if let bvid, !bvid.isEmpty {
            body["bvid"] = bvid
        }
        _ = try await postAuthed(path: "/x/web-interface/archive/like", body: body)
    }

    public func coinVideo(aid: Int64, bvid: String? = nil, count: Int = 1, alsoLike: Bool = false) async throws {
        let csrf = try await requireCSRFToken()
        var body = [
            "aid": String(aid),
            "multiply": String(min(2, max(1, count))),
            "select_like": alsoLike ? "1" : "0",
            // Endpoint has accepted both names across clients.
            "like": alsoLike ? "1" : "0",
            "csrf": csrf
        ]
        if let bvid, !bvid.isEmpty {
            body["bvid"] = bvid
        }
        _ = try await postAuthed(path: "/x/web-interface/coin/add", body: body)
    }

    public func likeComment(aid: Int64, rpid: Int64, liked: Bool) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": "1",
            "oid": String(aid),
            "rpid": String(rpid),
            "action": liked ? "1" : "0",
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/v2/reply/action", body: body)
    }

    public func replyComment(aid: Int64, rootRpid: Int64, parentRpid: Int64, message: String) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": "1",
            "oid": String(aid),
            "root": String(rootRpid),
            "parent": String(parentRpid),
            "message": message,
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/v2/reply/add", body: body)
    }

    public func deleteComment(aid: Int64, rpid: Int64) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": "1",
            "oid": String(aid),
            "rpid": String(rpid),
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/v2/reply/del", body: body)
    }

    public func fetchCommentReplies(aid: Int64, rootRpid: Int64, page: Int) async throws -> [CommentItem] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.bilibili.com"
        components.path = "/x/v2/reply/reply"
        components.queryItems = [
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "oid", value: String(aid)),
            URLQueryItem(name: "root", value: String(rootRpid)),
            URLQueryItem(name: "pn", value: String(page)),
            URLQueryItem(name: "ps", value: "20")
        ]
        guard let url = components.url else { throw BiliError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: request)
        let wrapped = try JSONDecoder().decode(CommentReplyEnvelope.self, from: data)
        guard wrapped.code == 0 else {
            throw BiliError.apiError(code: wrapped.code, message: wrapped.message)
        }
        return (wrapped.data?.replies ?? []).map { dto in
            CommentItem(
                id: dto.rpid.asInt64,
                oid: aid,
                mid: dto.member?.mid.asInt64,
                username: dto.member?.uname ?? L10n.t("label.user"),
                avatarURL: normalizedImageURL(dto.member?.avatar ?? ""),
                message: dto.content?.message ?? "",
                likeCount: dto.like.asInt,
                timestamp: Date(timeIntervalSince1970: TimeInterval(dto.ctime.asInt)),
                replyCount: dto.rcount.asInt
            )
        }
    }

    public func fetchVideoTags(aid: Int64) async throws -> [String] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.bilibili.com"
        components.path = "/x/tag/archive/tags"
        components.queryItems = [URLQueryItem(name: "aid", value: String(aid))]
        guard let url = components.url else { throw BiliError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: request)
        let wrapped = try JSONDecoder().decode(VideoTagEnvelope.self, from: data)
        guard wrapped.code == 0 else {
            throw BiliError.apiError(code: wrapped.code, message: wrapped.message)
        }
        return (wrapped.data ?? []).map(\.tagName).filter { !$0.isEmpty }
    }

    public func fetchMyFollowings(page: Int, pageSize: Int = 20) async throws -> [FollowingUser] {
        guard let mid = await authStore.loggedInMid() else {
            throw BiliError.unauthorized
        }
        let request = try await makeAuthedRequest(
            host: "api.bilibili.com",
            path: "/x/relation/followings",
            method: "GET",
            query: [
                "vmid": String(mid),
                "pn": String(page),
                "ps": String(pageSize),
                "order": "desc"
            ]
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try JSONDecoder().decode(FollowingEnvelope.self, from: data)
        guard envelope.code == 0 else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }
        return (envelope.data?.list ?? []).map {
            FollowingUser(
                id: $0.mid.asInt,
                name: $0.uname,
                avatarURL: normalizedImageURL($0.face),
                sign: $0.sign ?? "",
                fans: $0.fans?.asInt ?? 0
            )
        }
    }

    public func likeDynamic(dynamicID: Int64, isLike: Bool) async throws {
        let csrf = try await requireCSRFToken()
        guard let uid = await authStore.loggedInMid() else {
            throw BiliError.unauthorized
        }
        let body = [
            "dynamic_id": String(dynamicID),
            "up": isLike ? "1" : "2",
            "uid": String(uid),
            "csrf": csrf
        ]
        _ = try await postAuthed(host: "api.vc.bilibili.com", path: "/dynamic_like/v1/dynamic_like/thumb", body: body)
    }

    public func repostDynamic(dynamicID: Int64, text: String) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "dynamic_id": String(dynamicID),
            "content": text,
            "extension": #"{"emoji_type":1}"#,
            "csrf": csrf
        ]
        _ = try await postAuthed(host: "api.vc.bilibili.com", path: "/dynamic_repost/v1/dynamic_repost/repost", body: body)
    }

    public func fetchDynamicComments(resource: DynamicCommentResource, page: Int, order: Int = 2) async throws -> [CommentItem] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.bilibili.com"
        components.path = "/x/v2/reply"
        components.queryItems = [
            URLQueryItem(name: "type", value: String(resource.type)),
            URLQueryItem(name: "oid", value: String(resource.oid)),
            URLQueryItem(name: "pn", value: String(page)),
            URLQueryItem(name: "ps", value: "20"),
            URLQueryItem(name: "sort", value: String(order))
        ]
        guard let url = components.url else { throw BiliError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        if let cookie = await authStore.cookieHeader(for: .detail(bvid: "BV1xx411c7mD")) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let wrapped = try JSONDecoder().decode(DynamicCommentEnvelope.self, from: data)
        guard wrapped.code == 0 else {
            throw BiliError.apiError(code: wrapped.code, message: wrapped.message)
        }
        return (wrapped.data?.replies ?? []).map { dto in
            CommentItem(
                id: dto.rpid.asInt64,
                oid: resource.oid,
                mid: dto.member?.mid.asInt64,
                username: dto.member?.uname ?? L10n.t("label.user"),
                avatarURL: normalizedImageURL(dto.member?.avatar ?? ""),
                message: dto.content?.message ?? "",
                likeCount: dto.like.asInt,
                timestamp: Date(timeIntervalSince1970: TimeInterval(dto.ctime.asInt)),
                replyCount: dto.rcount.asInt
            )
        }
    }

    public func replyDynamicComment(resource: DynamicCommentResource, rootRpid: Int64, parentRpid: Int64, message: String) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": String(resource.type),
            "oid": String(resource.oid),
            "root": String(rootRpid),
            "parent": String(parentRpid),
            "message": message,
            "csrf": csrf
        ]
        _ = try await postAuthed(host: "api.bilibili.com", path: "/x/v2/reply/add", body: body)
    }

    public func sendDynamicComment(resource: DynamicCommentResource, message: String) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": String(resource.type),
            "oid": String(resource.oid),
            "message": message,
            "csrf": csrf
        ]
        _ = try await postAuthed(host: "api.bilibili.com", path: "/x/v2/reply/add", body: body)
    }

    public func likeDynamicComment(resource: DynamicCommentResource, rpid: Int64, liked: Bool) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": String(resource.type),
            "oid": String(resource.oid),
            "rpid": String(rpid),
            "action": liked ? "1" : "0",
            "csrf": csrf
        ]
        _ = try await postAuthed(host: "api.bilibili.com", path: "/x/v2/reply/action", body: body)
    }

    public func deleteDynamicComment(resource: DynamicCommentResource, rpid: Int64) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": String(resource.type),
            "oid": String(resource.oid),
            "rpid": String(rpid),
            "csrf": csrf
        ]
        _ = try await postAuthed(host: "api.bilibili.com", path: "/x/v2/reply/del", body: body)
    }

    public func fetchMyFriends(page: Int, pageSize: Int = 20) async throws -> [FollowingUser] {
        guard let mid = await authStore.loggedInMid() else {
            throw BiliError.unauthorized
        }
        let request = try await makeAuthedRequest(
            host: "api.bilibili.com",
            path: "/x/relation/friends",
            method: "GET",
            query: [
                "vmid": String(mid),
                "pn": String(page),
                "ps": String(pageSize)
            ]
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try JSONDecoder().decode(FollowingEnvelope.self, from: data)
        guard envelope.code == 0 else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }
        return (envelope.data?.list ?? []).map {
            FollowingUser(
                id: $0.mid.asInt,
                name: $0.uname,
                avatarURL: normalizedImageURL($0.face),
                sign: $0.sign ?? "",
                fans: $0.fans?.asInt ?? 0
            )
        }
    }

    private func postAuthed(path: String, body: [String: String]) async throws -> SimpleEnvelope {
        try await postAuthed(host: "api.bilibili.com", path: path, body: body)
    }

    private func postAuthed(host: String, path: String, body: [String: String]) async throws -> SimpleEnvelope {
        let request = try await makeAuthedRequest(host: host, path: path, method: "POST", query: [:], body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try JSONDecoder().decode(SimpleEnvelope.self, from: data)
        guard envelope.code == 0 else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }
        return envelope
    }

    private func requireCSRFToken() async throws -> String {
        guard let cookieHeader = await authStore.cookieHeader(for: .detail(bvid: "BV1xx411c7mD")) else {
            throw BiliError.unauthorized
        }

        let parts = cookieHeader.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        let token = parts.first(where: { $0.hasPrefix("bili_jct=") })?.replacingOccurrences(of: "bili_jct=", with: "")
        guard let token, !token.isEmpty else {
            throw BiliError.unauthorized
        }
        return token
    }

    private func makeAuthedRequest(
        host: String,
        path: String,
        method: String,
        query: [String: String],
        body: [String: String]? = nil
    ) async throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw BiliError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")

        if let body {
            let bodyString = body
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                .joined(separator: "&")
            request.httpBody = Data(bodyString.utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        guard let cookie = await authStore.cookieHeader(for: .detail(bvid: "BV1xx411c7mD")), !cookie.isEmpty else {
            throw BiliError.unauthorized
        }
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        return request
    }

    private func normalizedImageURL(_ raw: String) -> URL? {
        if raw.hasPrefix("//") {
            return URL(string: "https:\(raw)")
        }
        if raw.hasPrefix("http://") {
            return URL(string: "https://" + raw.dropFirst(7))
        }
        return URL(string: raw)
    }
}

private struct CommentReplyEnvelope: Decodable {
    struct DataBody: Decodable {
        let replies: [ReplyDTO]?
    }

    struct ReplyDTO: Decodable {
        struct MemberDTO: Decodable {
            let mid: IntString
            let uname: String?
            let avatar: String?
        }

        struct ContentDTO: Decodable {
            let message: String?
        }

        let rpid: IntString
        let like: IntString
        let ctime: IntString
        let rcount: IntString
        let member: MemberDTO?
        let content: ContentDTO?
    }

    let code: Int
    let message: String
    let data: DataBody?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? (try? c.decodeIfPresent(String.self, forKey: .msg)) ?? "unknown"
        data = try? c.decodeIfPresent(DataBody.self, forKey: .data)
    }
}

private typealias DynamicCommentEnvelope = CommentReplyEnvelope

private struct VideoTagEnvelope: Decodable {
    struct Item: Decodable {
        let tagName: String

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
        }
    }

    let code: Int
    let message: String
    let data: [Item]?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? (try? c.decodeIfPresent(String.self, forKey: .msg)) ?? "unknown"
        data = try? c.decodeIfPresent([Item].self, forKey: .data)
    }
}

private struct SimpleEnvelope: Decodable {
    let code: Int
    let message: String

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? (try? c.decodeIfPresent(String.self, forKey: .msg)) ?? "unknown"
    }
}

private struct FavFolderEnvelope: Decodable {
    struct DataBody: Decodable {
        let list: [FolderItem]
    }

    struct FolderItem: Decodable {
        let id: IntString
        let title: String
        let mediaCount: IntString

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case mediaCount = "media_count"
        }
    }

    let code: Int
    let message: String
    let data: DataBody?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? (try? c.decodeIfPresent(String.self, forKey: .msg)) ?? "unknown"
        data = try? c.decodeIfPresent(DataBody.self, forKey: .data)
    }
}

private struct FavMediaEnvelope: Decodable {
    struct DataBody: Decodable {
        let medias: [MediaItem]
    }

    struct MediaItem: Decodable {
        struct Upper: Decodable {
            let mid: IntString
            let name: String
        }

        struct CntInfo: Decodable {
            let play: IntString
            let danmaku: IntString
        }

        let id: IntString
        let bvid: String
        let title: String
        let cover: String
        let duration: IntString
        let upper: Upper?
        let cntInfo: CntInfo?

        private enum CodingKeys: String, CodingKey {
            case id
            case bvid
            case title
            case cover
            case duration
            case upper
            case cntInfo = "cnt_info"
        }
    }

    let code: Int
    let message: String
    let data: DataBody?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? (try? c.decodeIfPresent(String.self, forKey: .msg)) ?? "unknown"
        data = try? c.decodeIfPresent(DataBody.self, forKey: .data)
    }
}

private struct FollowingEnvelope: Decodable {
    struct DataBody: Decodable {
        let list: [UserItem]?
    }

    struct UserItem: Decodable {
        let mid: IntString
        let uname: String
        let face: String
        let sign: String?
        let fans: IntString?
    }

    let code: Int
    let message: String
    let data: DataBody?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? (try? c.decodeIfPresent(String.self, forKey: .msg)) ?? "unknown"
        data = try? c.decodeIfPresent(DataBody.self, forKey: .data)
    }
}

private struct IntString: Decodable {
    let asInt: Int
    let asInt64: Int64

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let int = try? c.decode(Int.self) {
            asInt = int
            asInt64 = Int64(int)
        } else if let int64 = try? c.decode(Int64.self) {
            asInt = Int(exactly: int64) ?? (int64 > 0 ? Int.max : Int.min)
            asInt64 = int64
        } else if let str = try? c.decode(String.self) {
            asInt64 = Int64(str) ?? 0
            asInt = Int(exactly: asInt64) ?? (asInt64 > 0 ? Int.max : Int.min)
        } else {
            asInt = 0
            asInt64 = 0
        }
    }
}

private extension Int {
    var durationString: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
