import Foundation
import Combine

@MainActor
public final class UploaderViewModel: ObservableObject {
    @Published public private(set) var uploader: UploaderProfile?
    @Published public private(set) var recentVideos: [BiliVideo] = []
    @Published public private(set) var recentArticles: [UploaderArticle] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let mid: Int
    private let service: BiliServiceProtocol

    public init(mid: Int, service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.mid = mid
        self.service = service
    }

    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await service.fetchUploader(mid: mid, page: 1)
            uploader = data.0
            recentVideos = Array(data.1.prefix(3))
            recentArticles = try await service.fetchUploaderArticles(mid: mid, page: 1)
            recentArticles = Array(recentArticles.prefix(3))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public var uploaderMid: Int { mid }
}
