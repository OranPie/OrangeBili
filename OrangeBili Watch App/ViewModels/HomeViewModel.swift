import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    struct Category: Identifiable, Hashable {
        let id: String
        let title: String
        let keyword: String?
    }

    @Published private(set) var videos: [BiliVideo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategoryID = "all"

    let categories: [Category] = [
        .init(id: "all", title: "全部", keyword: nil),
        .init(id: "anime", title: "动画", keyword: "动画"),
        .init(id: "game", title: "游戏", keyword: "游戏"),
        .init(id: "tech", title: "科技", keyword: "科技"),
        .init(id: "music", title: "音乐", keyword: "音乐"),
        .init(id: "film", title: "影视", keyword: "影视"),
        .init(id: "knowledge", title: "知识", keyword: "知识"),
        .init(id: "food", title: "美食", keyword: "美食")
    ]

    private let service: BiliServiceProtocol
    private var page = 1
    private var hasMore = true

    init(service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.service = service
    }

    var selectedCategory: Category {
        categories.first(where: { $0.id == selectedCategoryID }) ?? categories[0]
    }

    func loadInitialIfNeeded() async {
        guard videos.isEmpty else { return }
        await refresh()
    }

    func selectCategory(_ category: Category) async {
        guard selectedCategoryID != category.id else { return }
        selectedCategoryID = category.id
        await refresh()
    }

    func refresh() async {
        page = 1
        hasMore = true
        videos = []
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched: [BiliVideo]
            if let keyword = selectedCategory.keyword {
                fetched = try await service.searchVideos(keyword: keyword, page: page, order: "")
            } else {
                fetched = try await service.fetchPopular(page: page, size: 12)
            }

            errorMessage = nil
            hasMore = !fetched.isEmpty
            page += 1
            videos.append(contentsOf: fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
