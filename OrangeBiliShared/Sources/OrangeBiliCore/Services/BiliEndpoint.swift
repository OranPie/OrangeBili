import Foundation

enum BiliEndpoint {
    case popular(page: Int, size: Int)
    case search(keyword: String, page: Int, order: String)
    case searchLegacy(keyword: String, page: Int, order: String)
    case searchUsers(keyword: String, page: Int)
    case searchUsersLegacy(keyword: String, page: Int)
    case searchArticles(keyword: String, page: Int)
    case searchArticlesLegacy(keyword: String, page: Int)
    case detailWbi(bvid: String)
    case detail(bvid: String)
    case playURLWbi(bvid: String, cid: Int, quality: Int)
    case playURL(bvid: String, cid: Int, quality: Int)
    case comments(aid: Int, page: Int)
    case commentsLegacy(aid: Int, page: Int)
    case uploader(mid: Int)
    case uploaderLegacy(mid: Int)
    case uploaderRelation(mid: Int)
    case uploaderUpStat(mid: Int)
    case uploaderVideos(mid: Int, page: Int)
    case uploaderVideosLegacy(mid: Int, page: Int)
    case uploaderArticles(mid: Int, page: Int)
    case uploaderArticlesLegacy(mid: Int, page: Int)

    var legacyFallback: BiliEndpoint? {
        switch self {
        case let .search(keyword, page, order):
            return .searchLegacy(keyword: keyword, page: page, order: order)
        case let .searchUsers(keyword, page):
            return .searchUsersLegacy(keyword: keyword, page: page)
        case let .searchArticles(keyword, page):
            return .searchArticlesLegacy(keyword: keyword, page: page)
        case let .detailWbi(bvid):
            return .detail(bvid: bvid)
        case let .playURLWbi(bvid, cid, quality):
            return .playURL(bvid: bvid, cid: cid, quality: quality)
        case let .comments(aid, page):
            return .commentsLegacy(aid: aid, page: page)
        case let .uploader(mid):
            return .uploaderLegacy(mid: mid)
        case let .uploaderVideos(mid, page):
            return .uploaderVideosLegacy(mid: mid, page: page)
        case let .uploaderArticles(mid, page):
            return .uploaderArticlesLegacy(mid: mid, page: page)
        default:
            return nil
        }
    }

    func candidates(preferLoggedIn: Bool) -> [BiliEndpoint] {
        let ordered: [BiliEndpoint]
        switch self {
        case let .search(keyword, page, order), let .searchLegacy(keyword, page, order):
            ordered = preferLoggedIn
                ? [.search(keyword: keyword, page: page, order: order), .searchLegacy(keyword: keyword, page: page, order: order)]
                : [.searchLegacy(keyword: keyword, page: page, order: order), .search(keyword: keyword, page: page, order: order)]
        case let .searchUsers(keyword, page), let .searchUsersLegacy(keyword, page):
            ordered = preferLoggedIn
                ? [.searchUsers(keyword: keyword, page: page), .searchUsersLegacy(keyword: keyword, page: page)]
                : [.searchUsersLegacy(keyword: keyword, page: page), .searchUsers(keyword: keyword, page: page)]
        case let .searchArticles(keyword, page), let .searchArticlesLegacy(keyword, page):
            ordered = preferLoggedIn
                ? [.searchArticles(keyword: keyword, page: page), .searchArticlesLegacy(keyword: keyword, page: page)]
                : [.searchArticlesLegacy(keyword: keyword, page: page), .searchArticles(keyword: keyword, page: page)]
        case let .detailWbi(bvid), let .detail(bvid):
            ordered = preferLoggedIn
                ? [.detailWbi(bvid: bvid), .detail(bvid: bvid)]
                : [.detail(bvid: bvid), .detailWbi(bvid: bvid)]
        case let .playURLWbi(bvid, cid, quality), let .playURL(bvid, cid, quality):
            ordered = preferLoggedIn
                ? [.playURLWbi(bvid: bvid, cid: cid, quality: quality), .playURL(bvid: bvid, cid: cid, quality: quality)]
                : [.playURL(bvid: bvid, cid: cid, quality: quality), .playURLWbi(bvid: bvid, cid: cid, quality: quality)]
        case let .comments(aid, page), let .commentsLegacy(aid, page):
            ordered = preferLoggedIn
                ? [.comments(aid: aid, page: page), .commentsLegacy(aid: aid, page: page)]
                : [.commentsLegacy(aid: aid, page: page), .comments(aid: aid, page: page)]
        case let .uploader(mid), let .uploaderLegacy(mid):
            ordered = preferLoggedIn
                ? [.uploader(mid: mid), .uploaderLegacy(mid: mid)]
                : [.uploaderLegacy(mid: mid), .uploader(mid: mid)]
        case let .uploaderRelation(mid):
            ordered = [.uploaderRelation(mid: mid)]
        case let .uploaderUpStat(mid):
            ordered = [.uploaderUpStat(mid: mid)]
        case let .uploaderVideos(mid, page), let .uploaderVideosLegacy(mid, page):
            ordered = preferLoggedIn
                ? [.uploaderVideos(mid: mid, page: page), .uploaderVideosLegacy(mid: mid, page: page)]
                : [.uploaderVideosLegacy(mid: mid, page: page), .uploaderVideos(mid: mid, page: page)]
        case let .uploaderArticles(mid, page), let .uploaderArticlesLegacy(mid, page):
            ordered = preferLoggedIn
                ? [.uploaderArticles(mid: mid, page: page), .uploaderArticlesLegacy(mid: mid, page: page)]
                : [.uploaderArticlesLegacy(mid: mid, page: page), .uploaderArticles(mid: mid, page: page)]
        case let .popular(page, size):
            ordered = [.popular(page: page, size: size)]
        }

        var deduped: [BiliEndpoint] = []
        var seen = Set<String>()
        for endpoint in ordered {
            let key = endpoint.path + "?" + endpoint.cacheKey
            if seen.insert(key).inserted {
                deduped.append(endpoint)
            }
        }
        return deduped
    }

    var requiresWbi: Bool {
        switch self {
        case .search, .searchUsers, .searchArticles, .detailWbi, .playURLWbi, .comments, .uploader, .uploaderVideos, .uploaderArticles:
            return true
        default:
            return false
        }
    }

    var requiresBuvidCookie: Bool {
        switch self {
        case .search, .searchUsers, .searchArticles, .uploader, .uploaderVideos, .uploaderArticles:
            return true
        default:
            return false
        }
    }

    enum AuthPolicy {
        case none
        case optional
        case required
    }

    var authPolicy: AuthPolicy {
        switch self {
        case .popular, .comments, .commentsLegacy:
            return .none
        case .search, .searchLegacy, .searchUsers, .searchUsersLegacy, .searchArticles, .searchArticlesLegacy, .detailWbi, .detail, .playURLWbi, .playURL, .uploader, .uploaderLegacy, .uploaderVideos, .uploaderVideosLegacy, .uploaderArticles, .uploaderArticlesLegacy:
            return .optional
        case .uploaderRelation, .uploaderUpStat:
            return .none
        }
    }

    var path: String {
        switch self {
        case .popular:
            return "/x/web-interface/popular"
        case .search:
            return "/x/web-interface/wbi/search/type"
        case .searchLegacy:
            return "/x/web-interface/search/type"
        case .searchUsers, .searchArticles:
            return "/x/web-interface/wbi/search/type"
        case .searchUsersLegacy, .searchArticlesLegacy:
            return "/x/web-interface/search/type"
        case .detailWbi:
            return "/x/web-interface/wbi/view"
        case .detail:
            return "/x/web-interface/view"
        case .playURLWbi:
            return "/x/player/wbi/playurl"
        case .playURL:
            return "/x/player/playurl"
        case .comments:
            return "/x/v2/reply/wbi/main"
        case .commentsLegacy:
            return "/x/v2/reply"
        case .uploader:
            return "/x/space/wbi/acc/info"
        case .uploaderLegacy:
            return "/x/space/acc/info"
        case .uploaderRelation:
            return "/x/relation/stat"
        case .uploaderUpStat:
            return "/x/space/upstat"
        case .uploaderVideos:
            return "/x/space/wbi/arc/search"
        case .uploaderVideosLegacy:
            return "/x/space/arc/search"
        case .uploaderArticles:
            return "/x/space/wbi/article"
        case .uploaderArticlesLegacy:
            return "/x/space/article"
        }
    }

    var query: [String: String] {
        switch self {
        case let .popular(page, size):
            return [
                "pn": String(page),
                "ps": String(size)
            ]
        case let .search(keyword, page, order):
            return [
                "keyword": keyword,
                "search_type": "video",
                "page": String(page),
                "page_size": "10",
                "order": order,
                "web_location": "1550101"
            ]
        case let .searchLegacy(keyword, page, order):
            return [
                "keyword": keyword,
                "search_type": "video",
                "page": String(page),
                "page_size": "10",
                "order": order
            ]
        case let .searchUsers(keyword, page):
            return [
                "keyword": keyword,
                "search_type": "bili_user",
                "page": String(page),
                "page_size": "20",
                "order": "fans",
                "web_location": "1550101"
            ]
        case let .searchUsersLegacy(keyword, page):
            return [
                "keyword": keyword,
                "search_type": "bili_user",
                "page": String(page),
                "page_size": "20",
                "order": "fans"
            ]
        case let .searchArticles(keyword, page):
            return [
                "keyword": keyword,
                "search_type": "article",
                "page": String(page),
                "page_size": "20",
                "order": "totalrank",
                "web_location": "1550101"
            ]
        case let .searchArticlesLegacy(keyword, page):
            return [
                "keyword": keyword,
                "search_type": "article",
                "page": String(page),
                "page_size": "20",
                "order": "totalrank"
            ]
        case let .detailWbi(bvid):
            return ["bvid": bvid]
        case let .detail(bvid):
            return ["bvid": bvid]
        case let .playURLWbi(bvid, cid, quality):
            return [
                "bvid": bvid,
                "cid": String(cid),
                "qn": String(quality),
                "fnval": "0",
                "fnver": "0",
                "fourk": "0",
                "platform": "html5",
                "high_quality": "0"
            ]
        case let .playURL(bvid, cid, quality):
            return [
                "bvid": bvid,
                "cid": String(cid),
                "qn": String(quality),
                "fnval": "0",
                "fnver": "0",
                "fourk": "0",
                "platform": "html5",
                "high_quality": "0"
            ]
        case let .comments(aid, page):
            return [
                "type": "1",
                "oid": String(aid),
                "mode": "3",
                "next": String(max(0, page - 1)),
                "ps": "10",
                "web_location": "1315875"
            ]
        case let .commentsLegacy(aid, page):
            return [
                "type": "1",
                "oid": String(aid),
                "pn": String(page),
                "ps": "10",
                "sort": "2"
            ]
        case let .uploader(mid):
            return ["mid": String(mid)]
        case let .uploaderLegacy(mid):
            return ["mid": String(mid)]
        case let .uploaderRelation(mid):
            return ["vmid": String(mid)]
        case let .uploaderUpStat(mid):
            return ["mid": String(mid)]
        case let .uploaderVideos(mid, page):
            return [
                "mid": String(mid),
                "pn": String(page),
                "ps": "10",
                "tid": "0",
                "keyword": "",
                "order": "pubdate",
                "platform": "web",
                "web_location": "1550101",
                "order_avoided": "true",
                "dm_img_list": "[]",
                "dm_img_str": "V2ViR0wgMS",
                "dm_cover_img_str": "QU5HTEUgKEludGVsLCBJbnRlbChSKSBIRCBHcmFwaGljcyBEaXJlY3QzRDExIHZzXzVfMCBwc181XzApR29vZ2xlIEluYy4gKEludGVsKQ"
            ]
        case let .uploaderVideosLegacy(mid, page):
            return [
                "mid": String(mid),
                "pn": String(page),
                "ps": "10",
                "tid": "0",
                "keyword": "",
                "order": "pubdate"
            ]
        case let .uploaderArticles(mid, page):
            return [
                "mid": String(mid),
                "pn": String(page),
                "ps": "10",
                "sort": "publish_time",
                "web_location": "1550101"
            ]
        case let .uploaderArticlesLegacy(mid, page):
            return [
                "mid": String(mid),
                "pn": String(page),
                "ps": "10",
                "sort": "publish_time"
            ]
        }
    }


    var cacheKey: String {
        let base = query
            .filter { $0.key != "wts" && $0.key != "w_rid" }
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return path + "?" + base
    }

    var supportsOfflineCache: Bool {
        switch self {
        case .popular, .playURL, .playURLWbi:
            return false
        default:
            return true
        }
    }

    func makeRequest(with query: [String: String]) throws -> URLRequest {
        var components = URLComponents(string: "https://api.bilibili.com")
        components?.path = path
        components?.queryItems = query
            .sorted(by: { $0.key < $1.key })
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components?.url else {
            throw BiliError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        return request
    }
}
