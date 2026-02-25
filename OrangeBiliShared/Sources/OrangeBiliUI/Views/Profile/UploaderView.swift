import SwiftUI
import OrangeBiliCore

struct UploaderView: View {
    @StateObject private var viewModel: UploaderViewModel
    @EnvironmentObject private var visitStore: UploaderVisitStore

    init(mid: Int) {
        _viewModel = StateObject(wrappedValue: UploaderViewModel(mid: mid))
    }

    var body: some View {
        Group {
            if case .grid = UIStyle.videoLayout {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                        if let uploader = viewModel.uploader {
                            VStack(alignment: .leading, spacing: 6) {
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
                                        Text(L10n.f("uploader.likes", Formatting.count(uploader.likeCount)))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(L10n.f("uploader.followingFans", Formatting.count(uploader.followingCount), Formatting.count(uploader.followerCount)))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(L10n.f("label.uid", uploader.id))
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

                            sectionHeader(L10n.t("uploader.content"))
                            NavigationLink(L10n.t("uploader.videos")) {
                                UploaderVideosView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                            }
                            NavigationLink(L10n.t("uploader.articles")) {
                                UploaderArticlesView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                            }

                            if !viewModel.recentVideos.isEmpty {
                                sectionHeader(L10n.t("uploader.latestVideos"))
                                VideoListingView(videos: viewModel.recentVideos, rowInsets: nil) { _ in
                                    EmptyView()
                                }
                            }

                            if !viewModel.recentArticles.isEmpty {
                                sectionHeader(L10n.t("uploader.latestArticles"))
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
                                            Text(L10n.f("label.published", Formatting.absoluteDate(published)))
                                                .font(.system(size: 8))
                                                .foregroundStyle(.secondary)
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
                            EmptyStateView(viewModel.errorMessage ?? L10n.t("error.loadFailed"), systemImage: "exclamationmark.triangle")
                        }
                    }
                    .padding(.horizontal, UIStyle.listRowInsets.leading)
                    .padding(.vertical, UIStyle.listRowInsets.top)
                }
            } else {
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
                                    Text(L10n.f("uploader.likes", Formatting.count(uploader.likeCount)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(L10n.f("uploader.followingFans", Formatting.count(uploader.followingCount), Formatting.count(uploader.followerCount)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(L10n.f("label.uid", uploader.id))
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

                        Section(L10n.t("uploader.content")) {
                            NavigationLink(L10n.t("uploader.videos")) {
                                UploaderVideosView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                            }
                            NavigationLink(L10n.t("uploader.articles")) {
                                UploaderArticlesView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                            }
                        }

                        if !viewModel.recentVideos.isEmpty {
                            Section(L10n.t("uploader.latestVideos")) {
                                VideoListingView(videos: viewModel.recentVideos) { _ in
                                    EmptyView()
                                }
                            }
                        }

                        if !viewModel.recentArticles.isEmpty {
                            Section(L10n.t("uploader.latestArticles")) {
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
                                            Text(L10n.f("label.published", Formatting.absoluteDate(published)))
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
                        EmptyStateView(viewModel.errorMessage ?? L10n.t("error.loadFailed"), systemImage: "exclamationmark.triangle")
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(L10n.t("uploader.title"))
        .task {
            await viewModel.load()
            if let uploader = viewModel.uploader {
                visitStore.save(profile: uploader)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
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
        Group {
            if case .grid = UIStyle.videoLayout {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                        if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
                            EmptyStateView(error, systemImage: "exclamationmark.triangle")
                        }

                        VideoListingView(videos: viewModel.videos, rowInsets: nil) { _ in
                            EmptyView()
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
                    .padding(.horizontal, UIStyle.listRowInsets.leading)
                    .padding(.vertical, UIStyle.listRowInsets.top)
                }
            } else {
                List {
                    if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
                        EmptyStateView(error, systemImage: "exclamationmark.triangle")
                    }

                    VideoListingView(videos: viewModel.videos) { _ in
                        EmptyView()
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
                .listStyle(.plain)
            }
        }
        .navigationTitle(L10n.f("uploader.videos.title", uploaderName))
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
                EmptyStateView(error, systemImage: "exclamationmark.triangle")
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
                        Text(L10n.f("label.reads", Formatting.count(article.viewCount)))
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
        .listStyle(.plain)
        .navigationTitle(L10n.f("uploader.articles.title", uploaderName))
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
