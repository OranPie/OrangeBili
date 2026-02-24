import SwiftUI

struct UploaderView: View {
    @StateObject private var viewModel: UploaderViewModel
    @EnvironmentObject private var visitStore: UploaderVisitStore

    init(mid: Int) {
        _viewModel = StateObject(wrappedValue: UploaderViewModel(mid: mid))
    }

    var body: some View {
        List {
            if let uploader = viewModel.uploader {
                Section {
                    HStack(spacing: 8) {
                        AsyncCachedImage(url: uploader.avatarURL) {
                            Circle().fill(.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(uploader.name)
                                .font(.caption)
                                .bold()
                            Text("获赞 \(Formatting.count(uploader.likeCount))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("关注 \(Formatting.count(uploader.followingCount)) · 粉丝 \(Formatting.count(uploader.followerCount))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("UID \(uploader.id)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !uploader.signature.isEmpty {
                        Text(uploader.signature)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Section("内容") {
                    NavigationLink("视频列表") {
                        UploaderVideosView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                    }
                    NavigationLink("专栏列表") {
                        UploaderArticlesView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                    }
                }

                if !viewModel.recentVideos.isEmpty {
                    Section("最新视频预览") {
                        ForEach(viewModel.recentVideos) { video in
                            NavigationLink {
                                VideoDetailView(seedVideo: video)
                            } label: {
                                VideoRowView(video: video)
                            }
                        }
                    }
                }

                if !viewModel.recentArticles.isEmpty {
                    Section("最新专栏预览") {
                        ForEach(viewModel.recentArticles) { article in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(article.title)
                                    .font(.caption2)
                                    .lineLimit(2)
                                if !article.summary.isEmpty {
                                    Text(article.summary)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if let published = article.publishedAt {
                                    Text("发布 \(Formatting.absoluteDate(published))")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
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
        .navigationTitle("UP 主")
        .task {
            await viewModel.load()
            if let uploader = viewModel.uploader {
                visitStore.save(profile: uploader)
            }
        }
    }
}

private struct UploaderVideosView: View {
    let mid: Int
    let uploaderName: String

    @StateObject private var viewModel: UploaderVideosViewModel

    init(mid: Int, uploaderName: String) {
        self.mid = mid
        self.uploaderName = uploaderName
        _viewModel = StateObject(wrappedValue: UploaderVideosViewModel(mid: mid))
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.videos) { video in
                NavigationLink {
                    VideoDetailView(seedVideo: video)
                } label: {
                    VideoRowView(video: video)
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if !viewModel.videos.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }
        .navigationTitle("\(uploaderName) 视频")
        .task {
            await viewModel.loadInitialIfNeeded()
        }
    }
}

private struct UploaderArticlesView: View {
    let mid: Int
    let uploaderName: String

    @StateObject private var viewModel: UploaderArticlesViewModel

    init(mid: Int, uploaderName: String) {
        self.mid = mid
        self.uploaderName = uploaderName
        _viewModel = StateObject(wrappedValue: UploaderArticlesViewModel(mid: mid))
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage, viewModel.articles.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.articles) { article in
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title)
                        .font(.caption2)
                        .lineLimit(2)
                    if !article.summary.isEmpty {
                        Text(article.summary)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack {
                        Text("阅读 \(Formatting.count(article.viewCount))")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let published = article.publishedAt {
                            Text(Formatting.absoluteDate(published))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if !viewModel.articles.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }
        .navigationTitle("\(uploaderName) 专栏")
        .task {
            await viewModel.loadInitialIfNeeded()
        }
    }
}

@MainActor
private final class UploaderVideosViewModel: ObservableObject {
    @Published private(set) var videos: [BiliVideo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let mid: Int
    private let service: BiliServiceProtocol
    private var page = 1
    private var hasMore = true

    init(mid: Int, service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.mid = mid
        self.service = service
    }

    func loadInitialIfNeeded() async {
        guard videos.isEmpty else { return }
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await service.fetchUploaderVideos(mid: mid, page: page)
            hasMore = !fetched.isEmpty
            page += 1
            videos.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private final class UploaderArticlesViewModel: ObservableObject {
    @Published private(set) var articles: [UploaderArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let mid: Int
    private let service: BiliServiceProtocol
    private var page = 1
    private var hasMore = true

    init(mid: Int, service: BiliServiceProtocol = BiliAPIBackend.shared) {
        self.mid = mid
        self.service = service
    }

    func loadInitialIfNeeded() async {
        guard articles.isEmpty else { return }
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await service.fetchUploaderArticles(mid: mid, page: page)
            hasMore = !fetched.isEmpty
            page += 1
            articles.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
