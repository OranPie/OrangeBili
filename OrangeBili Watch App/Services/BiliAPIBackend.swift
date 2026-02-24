import Combine
import Foundation

@MainActor
final class BiliAPIBackend: ObservableObject, BiliServiceProtocol {
    static let shared = BiliAPIBackend()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var loggedInMid: Int?

    private let service: BiliServiceProtocol
    private let authStore: BiliAuthStore

    init(service: BiliServiceProtocol = BiliService(client: NetworkClient()), authStore: BiliAuthStore = .shared) {
        self.service = service
        self.authStore = authStore

        Task {
            await refreshAuthState()
        }
    }

    func updateLoginSession(
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

    func clearLoginSession() async {
        await authStore.update(session: nil)
        await refreshAuthState()
        DebugLogStore.shared.log(category: "backend", message: "clear login session done loggedIn=\(isLoggedIn)")
    }

    func refreshAuthState() async {
        isLoggedIn = await authStore.isLoggedIn()
        loggedInMid = await authStore.loggedInMid()
        DebugLogStore.shared.log(category: "backend", message: "refresh auth state loggedIn=\(isLoggedIn) mid=\(loggedInMid ?? 0)")
    }

    func fetchPopular(page: Int, size: Int) async throws -> [BiliVideo] {
        try await service.fetchPopular(page: page, size: size)
    }

    func searchVideos(keyword: String, page: Int, order: String) async throws -> [BiliVideo] {
        try await service.searchVideos(keyword: keyword, page: page, order: order)
    }

    func searchUsers(keyword: String, page: Int) async throws -> [UserSearchResult] {
        try await service.searchUsers(keyword: keyword, page: page)
    }

    func searchArticles(keyword: String, page: Int) async throws -> [ArticleSearchResult] {
        try await service.searchArticles(keyword: keyword, page: page)
    }

    func fetchVideoDetail(bvid: String) async throws -> VideoDetail {
        try await service.fetchVideoDetail(bvid: bvid)
    }

    func fetchPlayURL(bvid: String, cid: Int, quality: Int) async throws -> PlayStream {
        try await service.fetchPlayURL(bvid: bvid, cid: cid, quality: quality)
    }

    func fetchComments(aid: Int, page: Int) async throws -> [CommentItem] {
        try await service.fetchComments(aid: aid, page: page)
    }

    func fetchUploader(mid: Int, page: Int) async throws -> (UploaderProfile, [BiliVideo]) {
        try await service.fetchUploader(mid: mid, page: page)
    }

    func fetchUploaderVideos(mid: Int, page: Int) async throws -> [BiliVideo] {
        try await service.fetchUploaderVideos(mid: mid, page: page)
    }

    func fetchUploaderArticles(mid: Int, page: Int) async throws -> [UploaderArticle] {
        try await service.fetchUploaderArticles(mid: mid, page: page)
    }

    func fetchMyUploader() async throws -> (UploaderProfile, [BiliVideo]) {
        guard let mid = await authStore.loggedInMid() else {
            throw BiliError.unauthorized
        }
        return try await fetchUploader(mid: mid, page: 1)
    }

    func fetchCloudFavoriteFolders() async throws -> [CloudFavoriteFolder] {
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

    func fetchCloudFavoriteVideos(mediaID: Int, page: Int = 1, pageSize: Int = 20) async throws -> [BiliVideo] {
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
                aid: $0.id.asInt,
                title: $0.title,
                author: $0.upper?.name ?? "收藏夹",
                mid: $0.upper?.mid.asInt,
                coverURL: normalizedImageURL($0.cover),
                viewCount: $0.cntInfo?.play.asInt ?? 0,
                danmakuCount: $0.cntInfo?.danmaku.asInt ?? 0,
                durationText: Int($0.duration.asInt).durationString,
                description: "",
                sourceTag: "云端"
            )
        }
    }

    func likeVideo(aid: Int, liked: Bool) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "aid": String(aid),
            "like": liked ? "1" : "2",
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/web-interface/archive/like", body: body)
    }

    func coinVideo(aid: Int, count: Int = 1, alsoLike: Bool = false) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "aid": String(aid),
            "multiply": String(min(2, max(1, count))),
            "select_like": alsoLike ? "1" : "0",
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/web-interface/coin/add", body: body)
    }

    func likeComment(aid: Int, rpid: Int, liked: Bool) async throws {
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

    func replyComment(aid: Int, rootRpid: Int, parentRpid: Int, message: String) async throws {
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

    func deleteComment(aid: Int, rpid: Int) async throws {
        let csrf = try await requireCSRFToken()
        let body = [
            "type": "1",
            "oid": String(aid),
            "rpid": String(rpid),
            "csrf": csrf
        ]
        _ = try await postAuthed(path: "/x/v2/reply/del", body: body)
    }

    func fetchCommentReplies(aid: Int, rootRpid: Int, page: Int) async throws -> [CommentItem] {
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
        request.setValue("Mozilla/5.0 (Apple Watch; watchOS 11.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: request)
        let wrapped = try JSONDecoder().decode(CommentReplyEnvelope.self, from: data)
        guard wrapped.code == 0 else {
            throw BiliError.apiError(code: wrapped.code, message: wrapped.message)
        }
        return (wrapped.data?.replies ?? []).map { dto in
            CommentItem(
                id: dto.rpid.asInt,
                oid: aid,
                mid: dto.member?.mid.asInt,
                username: dto.member?.uname ?? "用户",
                avatarURL: normalizedImageURL(dto.member?.avatar ?? ""),
                message: dto.content?.message ?? "",
                likeCount: dto.like.asInt,
                timestamp: Date(timeIntervalSince1970: TimeInterval(dto.ctime.asInt)),
                replyCount: dto.rcount.asInt
            )
        }
    }

    func fetchVideoTags(aid: Int) async throws -> [String] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.bilibili.com"
        components.path = "/x/tag/archive/tags"
        components.queryItems = [URLQueryItem(name: "aid", value: String(aid))]
        guard let url = components.url else { throw BiliError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (Apple Watch; watchOS 11.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: request)
        let wrapped = try JSONDecoder().decode(VideoTagEnvelope.self, from: data)
        guard wrapped.code == 0 else {
            throw BiliError.apiError(code: wrapped.code, message: wrapped.message)
        }
        return (wrapped.data ?? []).map(\.tagName).filter { !$0.isEmpty }
    }

    func fetchMyFollowings(page: Int, pageSize: Int = 20) async throws -> [FollowingUser] {
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
                fans: $0.fans.asInt
            )
        }
    }

    private func postAuthed(path: String, body: [String: String]) async throws -> SimpleEnvelope {
        let request = try await makeAuthedRequest(host: "api.bilibili.com", path: path, method: "POST", query: [:], body: body)
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
        request.setValue("Mozilla/5.0 (Apple Watch; watchOS 11.0)", forHTTPHeaderField: "User-Agent")
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
        let fans: IntString
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

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let int = try? c.decode(Int.self) {
            asInt = int
        } else if let str = try? c.decode(String.self) {
            asInt = Int(str) ?? 0
        } else {
            asInt = 0
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
