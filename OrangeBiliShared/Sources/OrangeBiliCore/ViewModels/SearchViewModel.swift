import Foundation
import Combine

@MainActor
public final class SearchViewModel: ObservableObject {
    public enum Scope: String, CaseIterable, Identifiable {
        case video = "视频"
        case user = "用户"
        case article = "专栏"

        public var id: String { rawValue }
    }

    @Published public var keyword = ""
    @Published public var order = "totalrank"
    @Published public var scope: Scope = .video
    @Published public private(set) var videoResults: [BiliVideo] = []
    @Published public private(set) var userResults: [UserSearchResult] = []
    @Published public private(set) var articleResults: [ArticleSearchResult] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let service: BiliServiceProtocol
    private var page = 1
    private var hasMore = true

    public init(service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.service = service
    }

    public func search(reset: Bool = true) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        if reset {
            page = 1
            hasMore = true
            clearResults()
        }

        await loadMore()
    }

    public func loadMore() async {
        guard !isLoading, hasMore else { return }
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            switch scope {
            case .video:
                let fetched = try await service.searchVideos(keyword: trimmed, page: page, order: order)
                hasMore = !fetched.isEmpty
                page += 1
                videoResults.append(contentsOf: fetched)
            case .user:
                let fetched = try await service.searchUsers(keyword: trimmed, page: page)
                hasMore = !fetched.isEmpty
                page += 1
                userResults.append(contentsOf: fetched)
            case .article:
                let fetched = try await service.searchArticles(keyword: trimmed, page: page)
                hasMore = !fetched.isEmpty
                page += 1
                articleResults.append(contentsOf: fetched)
            }
            errorMessage = nil
        } catch {
            let orderLabel = order.isEmpty ? "default" : order
            DebugLogStore.shared.log(
                category: "search",
                message: "viewmodel fail scope=\(scope.rawValue) keyword=\(trimmed) page=\(page) order=\(orderLabel) err=\(error.localizedDescription)"
            )
            errorMessage = error.localizedDescription
        }
    }

    private func clearResults() {
        videoResults = []
        userResults = []
        articleResults = []
    }
}
