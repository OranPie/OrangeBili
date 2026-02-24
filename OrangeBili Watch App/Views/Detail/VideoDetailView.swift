import SwiftUI

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
        List {
            if let detail = viewModel.detail {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        AsyncCachedImage(url: detail.coverURL) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.3))
                        }
                        .frame(height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(detail.title)
                            .font(.system(size: 11.5 * render.textScale, weight: .semibold))
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            metaChip(label: "UP", value: detail.owner.name, monospaced: false)
                            metaChip(label: "BV", value: detail.bvid, monospaced: true)
                        }

                        if !detail.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(detail.description)
                                .font(.system(size: 9 * render.textScale))
                                .foregroundStyle(.secondary)
                                .lineLimit(min(render.detailDescriptionLines, 4))
                        }
                    }
                }

                Section("数据") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            statChip(icon: "play.fill", text: Formatting.count(detail.stats.views))
                            statChip(icon: "message", text: Formatting.count(detail.stats.danmaku))
                            statChip(icon: "text.bubble", text: Formatting.count(detail.stats.replies))
                        }
                        HStack(spacing: 6) {
                            statChip(icon: "star.fill", text: Formatting.count(detail.stats.favorites))
                            statChip(icon: "centsign.circle", text: Formatting.count(detail.stats.coins))
                            statChip(icon: "square.and.arrow.up", text: Formatting.count(detail.stats.shares))
                        }
                    }
                }

                if !tags.isEmpty {
                    Section("标签") {
                        let firstLine = Array(tags.prefix(4))
                        let secondLine = Array(tags.dropFirst(4).prefix(4))
                        compactTagLine(firstLine)
                        if !secondLine.isEmpty {
                            compactTagLine(secondLine)
                        }
                    }
                }

                Section {
                    let downloadedItem = localDownloadedItem(for: detail.bvid)
                    let activeStatus = activeDownloadStatus(for: detail.bvid)

                    HStack(spacing: 6) {
                        Button {
                            favoritesStore.toggle(video: seedVideo.with(cid: detail.cid))
                        } label: {
                            compactActionTile(
                                title: favoritesStore.isFavorite(bvid: seedVideo.bvid) ? "取消" : "收藏",
                                systemImage: favoritesStore.isFavorite(bvid: seedVideo.bvid) ? "heart.slash.fill" : "heart.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await startOfflineDownload(detail: detail) }
                        } label: {
                            compactActionTile(
                                title: downloadedItem != nil ? "已下载" : "下载",
                                systemImage: downloadedItem != nil ? "checkmark.circle.fill" : "arrow.down.circle"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(downloadedItem != nil || activeStatus != nil)

                        if let local = downloadedItem {
                            NavigationLink {
                                VideoPlayerView(video: seedVideo.with(cid: detail.cid), cid: detail.cid, localFileURL: local.localFileURL)
                            } label: {
                                compactActionTile(title: "离线播", systemImage: "play.circle.fill")
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                VideoPlayerView(video: seedVideo.with(cid: detail.cid), cid: detail.cid)
                            } label: {
                                compactActionTile(title: "播放", systemImage: "play.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 6) {
                        Button {
                            destination = .comments(detail.aid)
                        } label: {
                            compactActionTile(title: "评论", systemImage: "text.bubble")
                        }
                        .buttonStyle(.plain)

                        if let mid = seedVideo.mid ?? viewModel.detail?.owner.id {
                            Button {
                                destination = .uploader(mid)
                            } label: {
                                compactActionTile(title: "UP主", systemImage: "person.crop.circle")
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
                                compactActionTile(title: liked ? "取消赞" : "点赞", systemImage: liked ? "hand.thumbsup.slash.fill" : "hand.thumbsup.fill")
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await sendCoin(aid: detail.aid) }
                            } label: {
                                compactActionTile(title: "投币", systemImage: "centsign.circle.fill")
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
                        .font(.system(size: 8.5 * render.textScale))
                        .foregroundStyle(.secondary)
                    } else if downloadedItem != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("已下载到本地")
                                .lineLimit(1)
                        }
                        .font(.system(size: 8.5 * render.textScale))
                        .foregroundStyle(.secondary)
                    }

                    if let actionStatus {
                        Text(actionStatus)
                            .font(.system(size: 8.5 * render.textScale))
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
                Text(viewModel.errorMessage ?? "加载失败")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("详情")
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
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7.5 * render.textScale, weight: .bold))
            Text(value)
                .font(.system(size: 7.5 * render.textScale, weight: .medium, design: monospaced ? .monospaced : .default))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(Color.gray.opacity(0.14), in: Capsule())
    }

    @ViewBuilder
    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 8.5 * render.textScale, weight: .medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.15), in: Capsule())
    }

    private func startOfflineDownload(detail: VideoDetail) async {
        do {
            let stream = try await BiliAPIBackend.shared.fetchPlayURL(bvid: detail.bvid, cid: detail.cid, quality: 32)
            let headers = [
                "Referer": "https://www.bilibili.com",
                "User-Agent": "Mozilla/5.0 (Apple Watch; watchOS 11.0)"
            ]
            downloadManager.startDownload(
                bvid: detail.bvid,
                title: detail.title,
                url: stream.url,
                headers: headers,
                coverURL: detail.coverURL
            )
        } catch {
            DebugLogStore.shared.log(category: "download", message: "start fail \(detail.bvid): \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func compactActionTile(title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.system(size: 8.8 * render.textScale, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 24)
        .padding(.horizontal, 4)
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
            actionStatus = target ? "点赞成功" : "已取消点赞"
        } catch {
            actionStatus = "点赞失败：\(error.localizedDescription)"
        }
    }

    private func sendCoin(aid: Int) async {
        do {
            try await apiBackend.coinVideo(aid: aid, count: 1, alsoLike: false)
            actionStatus = "投币成功"
        } catch {
            actionStatus = "投币失败：\(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func compactTagLine(_ keywords: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(keywords, id: \.self) { keyword in
                Button {
                    destination = .tag(keyword)
                } label: {
                    Text("#\(keyword)")
                        .font(.system(size: 8.2 * render.textScale, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
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
        List {
            if let errorMessage, videos.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(videos) { video in
                NavigationLink {
                    VideoDetailView(seedVideo: video)
                } label: {
                    VideoRowView(video: video)
                }
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
