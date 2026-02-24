import Foundation

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published private(set) var comments: [CommentItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let aid: Int
    private let service: BiliServiceProtocol
    private var page = 1
    private var hasMore = true

    init(aid: Int, service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.aid = aid
        self.service = service
    }

    func loadInitialIfNeeded() async {
        guard comments.isEmpty else { return }
        await loadMore()
    }

    func loadMore() async {
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
