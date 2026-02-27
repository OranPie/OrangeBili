import SwiftUI
import OrangeBiliCore

struct UploaderView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case overview
        case videos
        case dynamics
        case articles

        var id: String { rawValue }
    }

    @StateObject private var viewModel: UploaderViewModel
    @EnvironmentObject private var visitStore: UploaderVisitStore
    @State private var selectedSection: Section = .overview

    init(mid: Int) {
        _viewModel = StateObject(wrappedValue: UploaderViewModel(mid: mid))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                if let uploader = viewModel.uploader {
                    header(uploader)
                    sectionTabs
                    sectionContent(for: uploader)
                } else if viewModel.isLoading {
                    SkeletonUploaderView()
                } else {
                    EmptyStateView(viewModel.errorMessage ?? L10n.t("error.loadFailed"), systemImage: "exclamationmark.triangle")
                }
            }
            .padding(.horizontal, UIStyle.listRowInsets.leading)
            .padding(.vertical, UIStyle.listRowInsets.top)
        }
        .navigationTitle(L10n.t("uploader.title"))
        .task {
            await viewModel.load()
            if let uploader = viewModel.uploader {
                visitStore.save(profile: uploader)
            }
        }
    }

    private func sectionTitle(for section: Section) -> String {
        switch section {
        case .overview:
            return L10n.t("uploader.section.overview")
        case .videos:
            return L10n.t("uploader.videos")
        case .dynamics:
            return L10n.t("uploader.dynamics")
        case .articles:
            return L10n.t("uploader.articles")
        }
    }

    @ViewBuilder
    private func header(_ uploader: UploaderProfile) -> some View {
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
                        .font(.system(size: UIStyle.fontSize(8)))
                        .foregroundStyle(.secondary)
                    Text(L10n.f("uploader.followingFans", Formatting.count(uploader.followingCount), Formatting.count(uploader.followerCount)))
                        .font(.system(size: UIStyle.fontSize(8)))
                        .foregroundStyle(.secondary)
                    Text(L10n.f("label.uid", uploader.id))
                        .font(.system(size: UIStyle.fontSize(7.5), design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    Task { await viewModel.toggleFollow() }
                } label: {
                    Text((viewModel.relation?.isFollowing ?? false) ? L10n.t("uploader.following.action") : L10n.t("uploader.follow.action"))
                        .font(.system(size: UIStyle.fontSize(9), weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((viewModel.relation?.isFollowing ?? false) ? Theme.cardBackground : Theme.accent.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isMutatingFollow)
            }

            if !uploader.signature.isEmpty {
                Text(uploader.signature)
                    .font(.system(size: UIStyle.fontSize(8)))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var sectionTabs: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Text(sectionTitle(for: section))
                        .font(.system(size: UIStyle.fontSize(8.5), weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedSection == section ? Theme.accent.opacity(0.22) : Theme.cardBackground,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func sectionContent(for uploader: UploaderProfile) -> some View {
        switch selectedSection {
        case .overview:
            overviewContent(for: uploader)
        case .videos:
            UploaderVideosView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                .frame(minHeight: 320)
        case .dynamics:
            dynamicsContent(for: uploader)
        case .articles:
            UploaderArticlesView(mid: viewModel.uploaderMid, uploaderName: uploader.name)
                .frame(minHeight: 320)
        }
    }

    @ViewBuilder
    private func overviewContent(for uploader: UploaderProfile) -> some View {
        if let topVideo = viewModel.topVideo {
            sectionHeader(L10n.t("uploader.topVideo"))
            VideoListingView(videos: [topVideo], rowInsets: nil) { _ in
                EmptyView()
            }
        }

        if !viewModel.masterpieces.isEmpty {
            sectionHeader(L10n.t("uploader.masterpieces"))
            VideoListingView(videos: Array(viewModel.masterpieces.prefix(3)), rowInsets: nil) { _ in
                EmptyView()
            }
        }

        if !viewModel.recentVideos.isEmpty {
            sectionHeader(L10n.t("uploader.latestVideos"))
            VideoListingView(videos: viewModel.recentVideos, rowInsets: nil) { _ in
                EmptyView()
            }
        }

        if !viewModel.recentDynamics.isEmpty {
            sectionHeader(L10n.t("uploader.dynamics"))
            ForEach(viewModel.recentDynamics.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.authorName).font(.caption2).bold()
                        if let date = item.publishedAt {
                            Text(Formatting.time(date))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(item.text.isEmpty ? L10n.t("dynamic.video.unavailable") : item.text)
                        .font(.system(size: 10))
                        .lineLimit(3)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                DynamicsView(scope: .user(mid: viewModel.uploaderMid, name: uploader.name))
            } label: {
                Text(L10n.t("uploader.dynamics"))
                    .font(.system(size: UIStyle.fontSize(9), weight: .semibold))
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
    }

    @ViewBuilder
    private func dynamicsContent(for uploader: UploaderProfile) -> some View {
        if viewModel.recentDynamics.isEmpty {
            EmptyStateView(L10n.t("dynamic.scope.user"), systemImage: "bolt.horizontal")
        } else {
            ForEach(viewModel.recentDynamics) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.authorName).font(.caption2).bold()
                        if let date = item.publishedAt {
                            Text(Formatting.time(date))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Label("\(item.stats.likeCount)", systemImage: item.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 8))
                            .foregroundStyle(item.isLiked ? .red : .secondary)
                    }
                    Text(item.text.isEmpty ? L10n.t("dynamic.video.unavailable") : item.text)
                        .font(.system(size: 10))
                        .lineLimit(4)
                }
            }
        }
        NavigationLink {
            DynamicsView(scope: .user(mid: viewModel.uploaderMid, name: uploader.name))
        } label: {
            SummaryCard(
                L10n.t("uploader.dynamics"),
                subtitle: L10n.t("dynamic.scope.user"),
                systemImage: "bolt.horizontal"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}

struct UploaderVideosView: View {
    let mid: Int
    let uploaderName: String

    @StateObject private var viewModel: UploaderVideosViewModel
    @State private var selectedOrder = "pubdate"

    private let orders: [(id: String, label: String)] = [
        ("pubdate", L10n.t("uploader.order.pubdate")),
        ("click", L10n.t("uploader.order.click")),
        ("stow", L10n.t("uploader.order.stow")),
    ]

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
                        } else if !viewModel.isLoading, viewModel.videos.isEmpty {
                            EmptyStateView(L10n.t("uploader.videos.empty"), systemImage: "play.slash")
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
                    } else if !viewModel.isLoading, viewModel.videos.isEmpty {
                        EmptyStateView(L10n.t("uploader.videos.empty"), systemImage: "play.slash")
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("", selection: $selectedOrder) {
                    ForEach(orders, id: \.id) { order in
                        Text(order.label).tag(order.id)
                    }
                }
                .labelsHidden()
                #if os(iOS) || os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        }
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .onChange(of: selectedOrder) { _, newOrder in
            Task { await viewModel.changeOrder(newOrder) }
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
    private var order = "pubdate"

    init(mid: Int, service: BiliServiceProtocol? = nil) {
        self.mid = mid
        self.service = service ?? BiliAPIBackend.shared
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
            let fetched = try await service.fetchUploaderVideos(mid: mid, page: page, order: order)
            hasMore = !fetched.isEmpty
            page += 1
            videos.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.show(
                L10n.f("uploader.videos.load.failed", error.localizedDescription),
                icon: "xmark.circle",
                style: .error
            )
        }
    }

    func changeOrder(_ newOrder: String) async {
        guard newOrder != order else { return }
        order = newOrder
        page = 1
        hasMore = true
        videos = []
        errorMessage = nil
        await loadMore()
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

    init(mid: Int, service: BiliServiceProtocol? = nil) {
        self.mid = mid
        self.service = service ?? BiliAPIBackend.shared
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
            ToastManager.shared.show(
                L10n.f("uploader.articles.load.failed", error.localizedDescription),
                icon: "xmark.circle",
                style: .error
            )
        }
    }
}
