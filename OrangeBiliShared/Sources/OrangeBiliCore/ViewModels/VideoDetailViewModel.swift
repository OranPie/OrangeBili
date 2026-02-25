import Foundation

@MainActor
public final class VideoDetailViewModel: ObservableObject {
    @Published public private(set) var detail: VideoDetail?
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let service: BiliServiceProtocol

    public init(service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.service = service
    }

    public func load(bvid: String) async {
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
