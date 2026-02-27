import SwiftUI
import OrangeBiliCore

struct DynamicsView: View {
    @StateObject private var viewModel: DynamicsViewModel
    @State private var repostTarget: DynamicItem?
    @State private var repostText = ""

    private let initialScope: DynamicsScope

    init(scope: DynamicsScope) {
        self.initialScope = scope
        _viewModel = StateObject(wrappedValue: DynamicsViewModel(scope: scope))
    }

    var body: some View {
        List {
            if supportsScopeToggle {
                Section {
                    scopeSelector
                }
                .listRowInsets(UIStyle.listRowInsets)
            }

            if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                EmptyStateView(error, systemImage: "exclamationmark.triangle")
                    .listRowInsets(UIStyle.listRowInsets)
            } else if viewModel.isLoading, viewModel.items.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowInsets(UIStyle.listRowInsets)
            }

            ForEach(viewModel.items) { item in
                DynamicCardView(
                    item: item,
                    onLike: { Task { await viewModel.toggleLike(itemID: item.id) } },
                    onRepost: { repostTarget = item },
                    makeDetail: makeVideoDetail(for:)
                )
                .listRowInsets(UIStyle.listRowInsets)
                .listRowBackground(Color.clear)
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowInsets(UIStyle.listRowInsets)
            } else if !viewModel.items.isEmpty, viewModel.hasMore {
                Color.clear
                    .frame(height: 1)
                    .onAppear { Task { await viewModel.loadMore() } }
                    .listRowInsets(UIStyle.listRowInsets)
            }
        }
        .listStyle(.plain)
        .navigationTitle(navigationTitle)
        .task { await viewModel.loadInitialIfNeeded() }
        .refreshable { await viewModel.reload() }
        .sheet(item: $repostTarget) { item in
            NavigationStack {
                Form {
                    TextField(L10n.t("dynamic.repost.placeholder"), text: $repostText, axis: .vertical)
                        .lineLimit(3...6)
                }
                .navigationTitle(L10n.t("dynamic.repost"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("action.cancel")) {
                            repostTarget = nil
                            repostText = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("action.send")) {
                            Task {
                                let ok = await viewModel.repost(itemID: item.id, text: repostText)
                                if ok {
                                    repostTarget = nil
                                    repostText = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var supportsScopeToggle: Bool {
        switch initialScope {
        case .mine, .following:
            return true
        case .user:
            return false
        }
    }

    @ViewBuilder
    private var scopeSelector: some View {
#if os(watchOS)
        HStack(spacing: 8) {
            scopeButton(L10n.t("dynamic.scope.mine"), scope: .mine)
            scopeButton(L10n.t("dynamic.scope.following"), scope: .following)
        }
#else
        Picker("", selection: Binding(
            get: {
                switch viewModel.scope {
                case .mine: return 0
                case .following: return 1
                case .user: return 2
                }
            },
            set: { newValue in
                Task {
                    if newValue == 0 {
                        await viewModel.switchScope(.mine)
                    } else if newValue == 1 {
                        await viewModel.switchScope(.following)
                    }
                }
            }
        )) {
            Text(L10n.t("dynamic.scope.mine")).tag(0)
            Text(L10n.t("dynamic.scope.following")).tag(1)
        }
        .pickerStyle(.segmented)
#endif
    }

    @ViewBuilder
    private func scopeButton(_ title: String, scope: DynamicsScope) -> some View {
        let isActive = scope == viewModel.scope
        Button(title) {
            Task { await viewModel.switchScope(scope) }
        }
        .buttonStyle(.plain)
        .font(.caption2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(isActive ? Theme.accent.opacity(0.18) : Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var navigationTitle: String {
        switch initialScope {
        case .mine:
            return L10n.t("dynamic.scope.mine")
        case .following:
            return L10n.t("dynamic.scope.following")
        case let .user(_, name):
            return L10n.f("dynamic.scope.user.title", name ?? L10n.t("label.uploader"))
        }
    }

    @ViewBuilder
    private func makeVideoDetail(for item: DynamicItem) -> some View {
        if let video = item.video, !video.bvid.isEmpty {
            VideoDetailView(seedVideo: BiliVideo(
                bvid: video.bvid,
                aid: video.aid,
                cid: video.cid,
                title: video.title,
                author: item.authorName,
                mid: item.authorMid,
                coverURL: video.coverURL,
                viewCount: 0,
                danmakuCount: 0,
                durationText: "00:00",
                description: item.text
            ))
        } else {
            EmptyStateView(L10n.t("dynamic.video.unavailable"), systemImage: "play.slash")
        }
    }
}

private struct DynamicCardView<Detail: View>: View {
    let item: DynamicItem
    let onLike: () -> Void
    let onRepost: () -> Void
    let makeDetail: (DynamicItem) -> Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AsyncCachedImage(url: item.authorAvatarURL) {
                    Circle().fill(.gray.opacity(0.24))
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    if item.authorMid > 0 {
                        NavigationLink {
                            UploaderView(mid: item.authorMid)
                        } label: {
                            Text(item.authorName).font(.caption2).bold()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(item.authorName).font(.caption2).bold()
                    }

                    if let date = item.publishedAt {
                        Text(Formatting.time(date))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !item.text.isEmpty {
                Text(item.text)
                    .font(.system(size: 10.5))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let video = item.video, !video.title.isEmpty {
                NavigationLink {
                    makeDetail(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        AsyncCachedImage(url: video.coverURL) {
                            RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.2))
                        }
                        .frame(height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(video.title)
                            .font(.system(size: 9.5, weight: .medium))
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
            } else if let opus = item.opus, !opus.imageURLs.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(Array(opus.imageURLs.prefix(4)), id: \.self) { url in
                        AsyncCachedImage(url: url) {
                            RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.2))
                        }
                        .frame(height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if let forwardedTextPreview = item.forwardedTextPreview, !forwardedTextPreview.isEmpty {
                Text(forwardedTextPreview)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Button {
                    onLike()
                } label: {
                    Label(Formatting.count(item.stats.likeCount), systemImage: item.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .buttonStyle(.plain)
                .foregroundStyle(item.isLiked ? Theme.accent : .secondary)

                NavigationLink {
                    DynamicCommentsView(resource: item.commentResource)
                } label: {
                    Label(Formatting.count(item.stats.commentCount), systemImage: "text.bubble")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onRepost()
                } label: {
                    Label(Formatting.count(item.stats.repostCount), systemImage: "arrow.2.squarepath")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .font(.system(size: 9))
        }
        .padding(UIStyle.cardPadding)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
    }
}

private struct DynamicCommentsView: View {
    @StateObject private var viewModel: DynamicCommentsViewModel
    @EnvironmentObject private var apiBackend: BiliAPIBackend
    @State private var draft = ""
    @State private var liked = Set<Int64>()

    init(resource: DynamicCommentResource) {
        _viewModel = StateObject(wrappedValue: DynamicCommentsViewModel(resource: resource))
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage, viewModel.comments.isEmpty {
                EmptyStateView(error, systemImage: "exclamationmark.triangle")
            }

            ForEach(viewModel.comments) { comment in
                VStack(alignment: .leading, spacing: 6) {
                    Text(comment.username)
                        .font(.caption2).bold()
                    Text(comment.message)
                        .font(.system(size: 10))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button {
                            Task {
                                let current = liked.contains(comment.id)
                                let ok = await viewModel.toggleLike(comment, currentlyLiked: current)
                                if ok {
                                    if current { liked.remove(comment.id) } else { liked.insert(comment.id) }
                                }
                            }
                        } label: {
                            Label(Formatting.count(comment.likeCount + (liked.contains(comment.id) ? 1 : 0)), systemImage: liked.contains(comment.id) ? "hand.thumbsup.fill" : "hand.thumbsup")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        Spacer()
                        Text(Formatting.time(comment.timestamp))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(UIStyle.cardPadding)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
                .listRowInsets(UIStyle.listRowInsets)
                .listRowBackground(Color.clear)
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.hasMore && !viewModel.comments.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear { Task { await viewModel.loadMore() } }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("comments.title"))
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                TextField(L10n.t("comment.input.placeholder"), text: $draft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                Button(L10n.t("action.send")) {
                    Task {
                        let ok = await viewModel.sendComment(draft)
                        if ok { draft = "" }
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !apiBackend.isLoggedIn)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background(Color.clear)
        }
        .task { await viewModel.loadInitialIfNeeded() }
    }
}
