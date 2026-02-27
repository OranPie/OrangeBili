import Foundation
import Combine

@MainActor
public final class CommentsViewModel: ObservableObject {
    @Published public private(set) var comments: [CommentItem] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let aid: Int64
    private let service: BiliServiceProtocol
    private var page = 1
    private var hasMore = true

    public init(aid: Int64, service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.aid = aid
        self.service = service
    }

    public func loadInitialIfNeeded() async {
        guard comments.isEmpty else { return }
        await loadMore()
    }

    public func reload() async {
        comments = []
        page = 1
        hasMore = true
        errorMessage = nil
        await loadMore()
    }

    public func loadMore() async {
        guard !isLoading, hasMore else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchComments(aid: aid, page: page)
            errorMessage = nil
            hasMore = !fetched.isEmpty
            page += 1
            comments.append(contentsOf: fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
