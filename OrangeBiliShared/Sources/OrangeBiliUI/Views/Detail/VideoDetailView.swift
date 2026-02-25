import SwiftUI
import OrangeBiliCore

struct VideoDetailView: View {
    private enum Destination: Hashable, Identifiable {
        case comments(Int)
        case uploader(Int)
        case tag(String)

        var id: String {
            switch self {
            case let .comments(aid): return "comments-\(aid)"
            case let .uploader(mid): return "uploader-\(mid)"
            case let .tag(keyword): return "tag-\(keyword)"
            }
        }
    }

    let seedVideo: BiliVideo

    @EnvironmentObject private var render: RenderSettings
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var downloadManager: OfflineDownloadManager
    @EnvironmentObject private var apiBackend: BiliAPIBackend
    @StateObject private var viewModel = VideoDetailViewModel()
    @State private var destination: Destination?
    @State private var liked = false
    @State private var actionStatus: String?
    @State private var tags: [String] = []

    var body: some View {
        let platformScale = UIStyle.platformScale * UIStyle.platformScale
        List {
            if let detail = viewModel.detail {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        AsyncCachedImage(url: detail.coverURL) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.3))
                        }
                        .aspectRatio(16 / 9, contentMode: .fit)
#if os(tvOS)
                        .frame(height: 360)
#else
                        .frame(height: 120)
#endif
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(detail.title)
                            .font(.system(size: 11.5 * render.textScale * platformScale, weight: .semibold))
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            metaChip(label: L10n.t("detail.meta.up"), value: detail.owner.name, monospaced: false)
                            metaChip(label: L10n.t("detail.meta.bv"), value: detail.bvid, monospaced: true)
                        }

                        if !detail.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            CompactDisclosure {
                                Text(L10n.t("detail.description"))
                                    .font(.system(size: 8.5 * render.textScale * platformScale))
                                    .foregroundStyle(.secondary)
                            } content: {
                                Text(detail.description)
                                    .font(.system(size: 9 * render.textScale * platformScale))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(min(render.detailDescriptionLines, 4))
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            InlineStatChip(icon: "play.fill", text: Formatting.count(detail.stats.views))
                            InlineStatChip(icon: "message", text: Formatting.count(detail.stats.danmaku))
                            InlineStatChip(icon: "text.bubble", text: Formatting.count(detail.stats.replies))
                        }

                        CompactDisclosure {
                            Text(L10n.t("detail.stats.more"))
                                .font(.system(size: 8.5 * render.textScale * platformScale))
                                .foregroundStyle(.secondary)
                        } content: {
                            HStack(spacing: 6) {
                                InlineStatChip(icon: "star.fill", text: Formatting.count(detail.stats.favorites))
                                InlineStatChip(icon: "centsign.circle", text: Formatting.count(detail.stats.coins))
                                InlineStatChip(icon: "square.and.arrow.up", text: Formatting.count(detail.stats.shares))
                            }
                        }
                    }
                } header: {
                    Text(L10n.t("detail.stats"))
                }

                if !tags.isEmpty {
                    Section(L10n.t("detail.tags")) {
                        compactTagLine(tags)
                    }
                }

                Section {
                    let downloadedItem = localDownloadedItem(for: detail.bvid)
                    let activeStatus = activeDownloadStatus(for: detail.bvid)

#if os(tvOS)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                favoritesStore.toggle(video: seedVideo.with(cid: detail.cid))
                            } label: {
                                compactActionTile(
                                    title: favoritesStore.isFavorite(bvid: seedVideo.bvid) ? L10n.t("action.unfavorite") : L10n.t("action.favorite"),
                                    systemImage: favoritesStore.isFavorite(bvid: seedVideo.bvid) ? "heart.slash.fill" : "heart.fill"
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await startOfflineDownload(detail: detail) }
                            } label: {
                                compactActionTile(
                                    title: downloadedItem != nil ? L10n.t("detail.downloaded") : L10n.t("action.download"),
                                    systemImage: downloadedItem != nil ? "checkmark.circle.fill" : "arrow.down.circle"
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(downloadedItem != nil || activeStatus != nil)
                        }

                        HStack(spacing: 10) {
                            if let local = downloadedItem {
                                NavigationLink {
                                    VideoPlayerView(video: seedVideo.with(cid: detail.cid), cid: detail.cid, localFileURL: local.localFileURL)
                                } label: {
                                    compactActionTile(title: L10n.t("action.play.offline"), systemImage: "play.circle.fill")
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    VideoPlayerView(video: seedVideo.with(cid: detail.cid), cid: detail.cid)
                                } label: {
                                    compactActionTile(title: L10n.t("action.play"), systemImage: "play.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
#else
                    HStack(spacing: 6) {
                        Button {
                            favoritesStore.toggle(video: seedVideo.with(cid: detail.cid))
                        } label: {
                            compactActionTile(
                                title: favoritesStore.isFavorite(bvid: seedVideo.bvid) ? L10n.t("action.unfavorite") : L10n.t("action.favorite"),
                                systemImage: favoritesStore.isFavorite(bvid: seedVideo.bvid) ? "heart.slash.fill" : "heart.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await startOfflineDownload(detail: detail) }
                        } label: {
                            compactActionTile(
                                title: downloadedItem != nil ? L10n.t("detail.downloaded") : L10n.t("action.download"),
                                systemImage: downloadedItem != nil ? "checkmark.circle.fill" : "arrow.down.circle"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(downloadedItem != nil || activeStatus != nil)

                        if let local = downloadedItem {
                            NavigationLink {
                                VideoPlayerView(video: seedVideo.with(cid: detail.cid), cid: detail.cid, localFileURL: local.localFileURL)
                            } label: {
                                compactActionTile(title: L10n.t("action.play.offline"), systemImage: "play.circle.fill")
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                VideoPlayerView(video: seedVideo.with(cid: detail.cid), cid: detail.cid)
                            } label: {
                                compactActionTile(title: L10n.t("action.play"), systemImage: "play.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
#endif

                    HStack(spacing: 6) {
                        Button {
                            destination = .comments(detail.aid)
                        } label: {
                            compactActionTile(title: L10n.t("detail.comments"), systemImage: "text.bubble")
                        }
                        .buttonStyle(.plain)

                        if let mid = seedVideo.mid ?? viewModel.detail?.owner.id {
                            Button {
                                destination = .uploader(mid)
                            } label: {
                                compactActionTile(title: L10n.t("detail.uploader"), systemImage: "person.crop.circle")
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                    }

                    if apiBackend.isLoggedIn {
                        HStack(spacing: 6) {
                            Button {
                                Task { await toggleLike(aid: detail.aid) }
                            } label: {
                                compactActionTile(title: liked ? L10n.t("action.unlike") : L10n.t("action.like"), systemImage: liked ? "hand.thumbsup.slash.fill" : "hand.thumbsup.fill")
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await sendCoin(aid: detail.aid) }
                            } label: {
                                compactActionTile(title: L10n.t("action.coin"), systemImage: "centsign.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let status = activeStatus {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("\(Int(status.progress * 100))%")
                            .lineLimit(1)
                            Spacer()
                            Text(formatBytes(Int(status.speedBytesPerSec)) + "/s")
                                .lineLimit(1)
                        }
                        .font(.system(size: 8.5 * render.textScale * platformScale))
                        .foregroundStyle(.secondary)
                    } else if downloadedItem != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(L10n.t("detail.downloaded.local"))
                                .lineLimit(1)
                        }
                        .font(.system(size: 8.5 * render.textScale * platformScale))
                        .foregroundStyle(.secondary)
                    }

                    if let actionStatus {
                        Text(actionStatus)
                            .font(.system(size: 8.5 * render.textScale * platformScale))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            } else if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                EmptyStateView(viewModel.errorMessage ?? L10n.t("error.loadFailed"), systemImage: "exclamationmark.triangle")
            }
        }
        .font(.system(size: UIStyle.normalTextSize))
        .listStyle(.plain)
        .navigationTitle(L10n.t("detail.title"))
        .task {
            await viewModel.load(bvid: seedVideo.bvid)
            if let aid = viewModel.detail?.aid {
                await loadTags(aid: aid)
            }
        }
        .task(id: viewModel.detail?.aid) {
            if let aid = viewModel.detail?.aid {
                await loadTags(aid: aid)
            }
        }
        .navigationDestination(item: $destination) { target in
            switch target {
            case let .comments(aid):
                CommentsView(aid: aid)
            case let .uploader(mid):
                UploaderView(mid: mid)
            case let .tag(keyword):
                TagVideosView(keyword: keyword)
            }
        }
    }


    @ViewBuilder
    private func metaChip(label: String, value: String, monospaced: Bool) -> some View {
        let platformScale = UIStyle.platformScale * UIStyle.platformScale
        HStack(spacing: 2) {
                Text(label)
                .font(.system(size: 7.5 * render.textScale * platformScale, weight: .bold))
                Text(value)
                .font(.system(size: 7.5 * render.textScale * platformScale, weight: .medium, design: monospaced ? .monospaced : .default))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, UIStyle.chipPadding.leading)
        .padding(.vertical, UIStyle.chipPadding.top)
        .background(Color.gray.opacity(0.14), in: Capsule())
    }

    private func startOfflineDownload(detail: VideoDetail) async {
        do {
            let stream = try await BiliAPIBackend.shared.fetchPlayURL(bvid: detail.bvid, cid: detail.cid, quality: 32)
            let headers = [
                "Referer": "https://www.bilibili.com",
                "User-Agent": PlatformInfo.userAgent
            ]
            downloadManager.startDownload(
                bvid: detail.bvid,
                title: detail.title,
                url: stream.url,
                headers: headers,
                coverURL: detail.coverURL
            )
            Task {
                _ = try? await DanmakuService.shared.fetchDanmaku(cid: detail.cid)
            }
        } catch {
            DebugLogStore.shared.log(category: "download", message: "start fail \(detail.bvid): \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func compactActionTile(title: String, systemImage: String) -> some View {
        let platformScale = UIStyle.platformScale * UIStyle.platformScale
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.system(size: 10.5 * render.textScale * platformScale, weight: .semibold))
#if os(tvOS)
        .frame(maxWidth: .infinity, minHeight: UIStyle.buttonMinSize)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
#else
        .frame(maxWidth: .infinity, minHeight: 28)
        .padding(.horizontal, 4)
#endif
        .background(Color.gray.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
    }

    private func localDownloadedItem(for bvid: String) -> DownloadStatusItem? {
        downloadManager.items.first {
            $0.bvid == bvid && $0.state == .completed && $0.localFileURL != nil
        }
    }

    private func activeDownloadStatus(for bvid: String) -> DownloadStatusItem? {
        downloadManager.items.first {
            $0.bvid == bvid && ($0.state == .downloading || $0.state == .queued)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1fMB", Double(bytes) / 1_000_000)
        }
        if bytes >= 1_000 {
            return String(format: "%.1fKB", Double(bytes) / 1_000)
        }
        return "\(bytes)B"
    }

    private func toggleLike(aid: Int) async {
        do {
            let target = !liked
            try await apiBackend.likeVideo(aid: aid, liked: target)
            liked = target
            actionStatus = target ? L10n.t("action.like.success") : L10n.t("action.like.cancel")
        } catch {
            actionStatus = L10n.f("action.like.fail", error.localizedDescription)
        }
    }

    private func sendCoin(aid: Int) async {
        do {
            try await apiBackend.coinVideo(aid: aid, count: 1, alsoLike: false)
            actionStatus = L10n.t("action.coin.success")
        } catch {
            actionStatus = L10n.f("action.coin.fail", error.localizedDescription)
        }
    }

    @ViewBuilder
    private func compactTagLine(_ keywords: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(keywords, id: \.self) { keyword in
                    Button {
                        destination = .tag(keyword)
                    } label: {
                        Text("#\(keyword)")
                            .font(.system(size: 10 * render.textScale * UIStyle.platformScale * UIStyle.platformScale, weight: .semibold))
                            .lineLimit(1)
                            .padding(.horizontal, UIStyle.chipPadding.leading)
                            .padding(.vertical, UIStyle.chipPadding.top)
                            .background(Color.gray.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadTags(aid: Int) async {
        do {
            tags = try await apiBackend.fetchVideoTags(aid: aid)
        } catch {
            tags = []
        }
    }
}

private extension BiliVideo {
    func with(cid: Int) -> BiliVideo {
        BiliVideo(
            bvid: bvid,
            aid: aid,
            cid: cid,
            title: title,
            author: author,
            mid: mid,
            coverURL: coverURL,
            viewCount: viewCount,
            danmakuCount: danmakuCount,
            durationText: durationText,
            publishedAt: publishedAt,
            description: description,
            sourceTag: sourceTag
        )
    }
}

private struct TagVideosView: View {
    let keyword: String

    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var videos: [BiliVideo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasMore = true

    var body: some View {
        Group {
            if case .grid = UIStyle.videoLayout {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                        if let errorMessage, videos.isEmpty {
                            Text(errorMessage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        VideoListingView(videos: videos, rowInsets: nil) { _ in
                            EmptyView()
                        }

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if !videos.isEmpty, hasMore {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    Task { await loadMore() }
                                }
                        }
                    }
                    .padding(.horizontal, UIStyle.listRowInsets.leading)
                    .padding(.vertical, UIStyle.listRowInsets.top)
                }
            } else {
                List {
                    if let errorMessage, videos.isEmpty {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VideoListingView(videos: videos) { _ in
                        EmptyView()
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if !videos.isEmpty, hasMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await loadMore() }
                            }
                    }
                }
            }
        }
        .navigationTitle("#\(keyword)")
        .task {
            guard videos.isEmpty else { return }
            await loadMore()
        }
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await apiBackend.searchVideos(keyword: keyword, page: page, order: "totalrank")
            hasMore = !fetched.isEmpty
            page += 1
            videos.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
