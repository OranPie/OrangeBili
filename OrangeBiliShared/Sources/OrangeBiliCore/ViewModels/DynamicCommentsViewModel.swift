import Foundation

@MainActor
public final class DynamicCommentsViewModel: ObservableObject {
    @Published public private(set) var comments: [CommentItem] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var hasMore = true
    @Published public var errorMessage: String?

    private let resource: DynamicCommentResource
    private let backend: BiliAPIBackend
    private var page = 1

    public init(resource: DynamicCommentResource, backend: BiliAPIBackend? = nil) {
        self.resource = resource
        self.backend = backend ?? BiliAPIBackend.shared
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
            let fetched = try await backend.fetchDynamicComments(resource: resource, page: page)
            hasMore = !fetched.isEmpty
            page += 1
            comments.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func sendComment(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            try await backend.sendDynamicComment(resource: resource, message: trimmed)
            await reload()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func toggleLike(_ comment: CommentItem, currentlyLiked: Bool) async -> Bool {
        do {
            try await backend.likeDynamicComment(resource: resource, rpid: comment.id, liked: !currentlyLiked)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
