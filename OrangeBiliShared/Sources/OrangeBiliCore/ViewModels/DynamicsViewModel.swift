import Foundation

@MainActor
public final class DynamicsViewModel: ObservableObject {
    @Published public private(set) var scope: DynamicsScope
    @Published public private(set) var items: [DynamicItem] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var hasMore = true
    @Published public var errorMessage: String?

    private var nextOffset: String?
    private let backend: BiliAPIBackend

    public init(scope: DynamicsScope, backend: BiliAPIBackend? = nil) {
        self.scope = scope
        self.backend = backend ?? BiliAPIBackend.shared
    }

    public func switchScope(_ scope: DynamicsScope) async {
        guard self.scope != scope else { return }
        self.scope = scope
        await reload()
    }

    public func reload() async {
        items = []
        nextOffset = nil
        hasMore = true
        errorMessage = nil
        await loadMore()
    }

    public func loadInitialIfNeeded() async {
        guard items.isEmpty else { return }
        await loadMore()
    }

    public func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await backend.fetchDynamics(scope: scope, offset: nextOffset)
            errorMessage = nil
            nextOffset = page.nextOffset
            hasMore = page.hasMore && !(page.nextOffset?.isEmpty ?? true)
            let merged = items + page.items
            var seen = Set<Int64>()
            items = merged.filter { seen.insert($0.id).inserted }
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.show(
                L10n.f("dynamic.load.failed", error.localizedDescription),
                icon: "xmark.circle",
                style: .error
            )
        }
    }

    public func toggleLike(itemID: Int64) async {
        guard backend.isLoggedIn else {
            errorMessage = L10n.t("dynamic.login.required")
            ToastManager.shared.show(
                L10n.t("dynamic.login.required"),
                icon: "person.crop.circle.badge.exclamationmark",
                style: .warning
            )
            return
        }
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let old = items[idx]
        let targetLike = !old.isLiked
        let updated = DynamicItem(
            id: old.id,
            authorMid: old.authorMid,
            authorName: old.authorName,
            authorAvatarURL: old.authorAvatarURL,
            publishedAt: old.publishedAt,
            text: old.text,
            kind: old.kind,
            video: old.video,
            opus: old.opus,
            forwardedTextPreview: old.forwardedTextPreview,
            stats: DynamicStat(
                likeCount: max(0, old.stats.likeCount + (targetLike ? 1 : -1)),
                repostCount: old.stats.repostCount,
                commentCount: old.stats.commentCount
            ),
            isLiked: targetLike,
            commentResource: old.commentResource
        )
        items[idx] = updated
        do {
            try await backend.likeDynamic(dynamicID: itemID, isLike: targetLike)
        } catch {
            items[idx] = old
            errorMessage = error.localizedDescription
            ToastManager.shared.show(
                L10n.f("dynamic.like.failed", error.localizedDescription),
                icon: "xmark.circle",
                style: .error
            )
        }
    }

    public func repost(itemID: Int64, text: String) async -> Bool {
        guard backend.isLoggedIn else {
            errorMessage = L10n.t("dynamic.login.required")
            ToastManager.shared.show(
                L10n.t("dynamic.login.required"),
                icon: "person.crop.circle.badge.exclamationmark",
                style: .warning
            )
            return false
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do {
            try await backend.repostDynamic(dynamicID: itemID, text: text)
            ToastManager.shared.show(
                L10n.t("dynamic.repost.success"),
                icon: "checkmark.circle",
                style: .success
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.show(
                L10n.f("dynamic.repost.failed", error.localizedDescription),
                icon: "xmark.circle",
                style: .error
            )
            return false
        }
    }
}
