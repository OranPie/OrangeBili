import Foundation

@MainActor
final class VideoDetailViewModel: ObservableObject {
    @Published private(set) var detail: VideoDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: BiliServiceProtocol

    init(service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.service = service
    }

    func load(bvid: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await service.fetchVideoDetail(bvid: bvid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
