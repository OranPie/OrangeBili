import Foundation
import Combine

@MainActor
public final class UploaderViewModel: ObservableObject {
    @Published public private(set) var uploader: UploaderProfile?
    @Published public private(set) var relation: UploaderRelationState?
    @Published public private(set) var topVideo: BiliVideo?
    @Published public private(set) var masterpieces: [BiliVideo] = []
    @Published public private(set) var recentVideos: [BiliVideo] = []
    @Published public private(set) var recentArticles: [UploaderArticle] = []
    @Published public private(set) var recentDynamics: [DynamicItem] = []
    @Published public private(set) var isMutatingFollow = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let mid: Int
    private let service: BiliServiceProtocol

    public init(mid: Int, service: BiliServiceProtocol? = nil) {
        self.mid = mid
        self.service = service ?? BiliAPIBackend.shared
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
            let dynamicPage = try? await service.fetchDynamics(scope: .user(mid: mid, name: data.0.name), offset: nil)
            recentDynamics = Array((dynamicPage?.items ?? []).prefix(6))
            topVideo = try? await service.fetchUploaderTopVideo(mid: mid)
            masterpieces = (try? await service.fetchUploaderMasterpieces(mid: mid, page: 1)) ?? []
            relation = try? await service.fetchUploaderRelationState(mid: mid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.show(
                L10n.f("uploader.load.failed", error.localizedDescription),
                icon: "xmark.circle",
                style: .error
            )
        }
    }

    public func toggleFollow() async {
        guard !isMutatingFollow else { return }
        guard let relation else {
            errorMessage = L10n.t("uploader.follow.loginRequired")
            ToastManager.shared.show(
                L10n.t("uploader.follow.loginRequired"),
                icon: "person.crop.circle.badge.exclamationmark",
                style: .warning
            )
            return
        }
        let old = relation
        let targetIsFollowing = !relation.isFollowing
        self.relation = UploaderRelationState(
            isFollowing: targetIsFollowing,
            isFollowedBy: relation.isFollowedBy,
            attribute: relation.attribute
        )
        isMutatingFollow = true
        defer { isMutatingFollow = false }

        do {
            if targetIsFollowing {
                try await service.followUploader(mid: mid)
                ToastManager.shared.show(
                    L10n.t("uploader.follow.success.followed"),
                    icon: "checkmark.circle",
                    style: .success
                )
            } else {
                try await service.unfollowUploader(mid: mid)
                ToastManager.shared.show(
                    L10n.t("uploader.follow.success.unfollowed"),
                    icon: "person.crop.circle.badge.minus",
                    style: .info
                )
            }
        } catch {
            self.relation = old
            errorMessage = error.localizedDescription
            ToastManager.shared.show(
                L10n.f("uploader.follow.failed", error.localizedDescription),
                icon: "xmark.circle",
                style: .error
            )
        }
    }

    public var uploaderMid: Int { mid }
}
