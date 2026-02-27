import SwiftUI
import OrangeBiliCore

struct CommentsView: View {
    @StateObject private var viewModel: CommentsViewModel
    @EnvironmentObject private var render: RenderSettings
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var selectedComment: CommentItem?
    @State private var previewReplies: [Int: [CommentItem]] = [:]
    @State private var previewLoading = Set<Int>()

    init(aid: Int64) {
        _viewModel = StateObject(wrappedValue: CommentsViewModel(aid: aid))
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage, viewModel.comments.isEmpty {
                EmptyStateView(error, systemImage: "exclamationmark.triangle")
            }

            if viewModel.isLoading && viewModel.comments.isEmpty {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCommentRow()
                        .listRowInsets(UIStyle.listRowInsets)
                }
            }

            ForEach(viewModel.comments) { comment in
                CommentCardView(
                    comment: comment,
                    previewReplies: previewReplies[comment.id] ?? [],
                    isPreviewLoading: previewLoading.contains(comment.id),
                    commentTextScale: render.commentTextScale,
                    onOpenThread: { selectedComment = comment }
                )
                .listRowInsets(UIStyle.listRowInsets)
                .listRowBackground(Color.clear)
                .task {
                    await prefetchPreviewIfNeeded(comment: comment)
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowInsets(UIStyle.listRowInsets)
            } else if !viewModel.comments.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
                    .listRowInsets(UIStyle.listRowInsets)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("comments.title"))
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
            previewReplies = [:]
            previewLoading = []
        }
        .sheet(item: $selectedComment) { comment in
            CommentThreadSheet(comment: comment)
                .environmentObject(apiBackend)
                .environmentObject(render)
        }
    }

    private func prefetchPreviewIfNeeded(comment: CommentItem) async {
        guard comment.replyCount > 0 else { return }
        guard previewReplies[comment.id] == nil else { return }
        guard !previewLoading.contains(comment.id) else { return }
        previewLoading.insert(comment.id)
        defer { previewLoading.remove(comment.id) }

        do {
            let replies = try await apiBackend.fetchCommentReplies(aid: comment.oid, rootRpid: comment.id, page: 1)
            previewReplies[comment.id] = Array(replies.prefix(2))
        } catch {
            previewReplies[comment.id] = []
        }
    }
}

private struct CommentCardView: View {
    let comment: CommentItem
    let previewReplies: [CommentItem]
    let isPreviewLoading: Bool
    let commentTextScale: Double
    let onOpenThread: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            bodyText
            previewSection
            actionRow
        }
        .padding(UIStyle.cardPadding)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
        .onTapGesture { onOpenThread() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let mid = comment.mid, mid > 0 {
                NavigationLink {
                    UploaderView(mid: mid)
                } label: {
                    Text(comment.username)
                        .font(.system(size: 11.5 * commentTextScale, weight: .semibold))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(comment.username)
                    .font(.system(size: 11.5 * commentTextScale, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(Formatting.time(comment.timestamp))
                .font(.system(size: 9 * commentTextScale))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var bodyText: some View {
        Text(comment.message)
            .font(.system(size: 10.5 * commentTextScale))
            .lineLimit(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var previewSection: some View {
        if isPreviewLoading && comment.replyCount > 0 {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.75)
                Text(L10n.t("action.loadMore"))
                    .font(.system(size: 8.5 * commentTextScale))
                    .foregroundStyle(.secondary)
            }
        } else if !previewReplies.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(previewReplies) { reply in
                    HStack(alignment: .top, spacing: 6) {
                        Text(reply.username)
                            .font(.system(size: 8.8 * commentTextScale, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(reply.message)
                            .font(.system(size: 8.8 * commentTextScale))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                if comment.replyCount > previewReplies.count {
                    Text(L10n.f("comments.thread.more", comment.replyCount))
                        .font(.system(size: 8.6 * commentTextScale, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Label(Formatting.count(comment.likeCount), systemImage: "hand.thumbsup")
                .font(.system(size: 8.8 * commentTextScale))
                .foregroundStyle(.secondary)

            Button {
                onOpenThread()
            } label: {
                Label(Formatting.count(comment.replyCount), systemImage: "arrowshape.turn.up.left")
                    .font(.system(size: 8.8 * commentTextScale))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            #if os(watchOS)
            Button {
                onOpenThread()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12 * commentTextScale))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            #else
            Menu {
                Button(L10n.t("comment.detail.title")) { onOpenThread() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12 * commentTextScale))
                    .foregroundStyle(.secondary)
            }
            #endif
        }
    }
}

private struct CommentThreadSheet: View {
    let comment: CommentItem

    @EnvironmentObject private var apiBackend: BiliAPIBackend
    @EnvironmentObject private var render: RenderSettings
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = CommentThreadViewModel()
    @State private var replyText = ""
    @State private var replyTargetRpid: Int?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            content
            Divider()
            composer
        }
        .background(Color.black)
        .task {
            await viewModel.prepareIfNeeded(comment: comment, backend: apiBackend)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Text(comment.username)
                .font(.system(size: 11 * render.commentTextScale, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                threadRootCard
                repliesSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var threadRootCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(comment.message)
                .font(.system(size: 10.5 * render.commentTextScale))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text(Formatting.time(comment.timestamp))
                Label(Formatting.count(comment.likeCount), systemImage: "hand.thumbsup")
                Label(Formatting.count(comment.replyCount), systemImage: "arrowshape.turn.up.left")
            }
            .font(.system(size: 8.6 * render.commentTextScale))
            .foregroundStyle(.secondary)
        }
        .padding(UIStyle.cardPadding)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
    }

    @ViewBuilder
    private var repliesSection: some View {
        if let error = viewModel.errorMessage, viewModel.replies.isEmpty {
            Text(error)
                .font(.system(size: 9 * render.commentTextScale))
                .foregroundStyle(.secondary)
        } else if viewModel.isLoading && viewModel.replies.isEmpty {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCommentRow()
            }
        } else {
            ForEach(viewModel.replies) { reply in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(reply.username)
                            .font(.system(size: 9.8 * render.commentTextScale, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(Formatting.time(reply.timestamp))
                            .font(.system(size: 8 * render.commentTextScale))
                            .foregroundStyle(.secondary)
                    }
                    Text(reply.message)
                        .font(.system(size: 9.8 * render.commentTextScale))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Label(Formatting.count(reply.likeCount), systemImage: "hand.thumbsup")
                            .font(.system(size: 8 * render.commentTextScale))
                            .foregroundStyle(.secondary)
                        Button(L10n.t("comment.detail.reply")) {
                            replyTargetRpid = reply.id
                            inputFocused = true
                        }
                        .font(.system(size: 8.5 * render.commentTextScale))
                    }
                }
                .padding(UIStyle.cardPadding)
                .background(Theme.cardBackground.opacity(0.8), in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.hasMore {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let target = replyTargetRpid {
                HStack {
                    Text(L10n.f("comment.detail.replyId", target))
                        .font(.system(size: 8.5 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.t("comment.detail.reply.cancel")) {
                        replyTargetRpid = nil
                    }
                    .font(.system(size: 8.5 * render.commentTextScale))
                }
            }
            HStack(spacing: 8) {
                TextField(L10n.t("comment.detail.placeholder"), text: $replyText)
                    #if os(watchOS)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                    #else
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .focused($inputFocused)
                Button(L10n.t("action.send")) {
                    Task {
                        let parent = replyTargetRpid ?? comment.id
                        await viewModel.sendReply(message: replyText, parentRpid: parent)
                        if viewModel.sendError == nil {
                            replyText = ""
                            replyTargetRpid = nil
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!apiBackend.isLoggedIn || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            if let error = viewModel.sendError {
                Text(error)
                    .font(.system(size: 8.5 * render.commentTextScale))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

@MainActor
private final class CommentThreadViewModel: ObservableObject {
    @Published private(set) var replies: [CommentItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSending = false
    @Published var sendError: String?

    private var backend: BiliAPIBackend?
    private var rootComment: CommentItem?
    private var page = 1

    func prepareIfNeeded(comment: CommentItem, backend: BiliAPIBackend) async {
        if rootComment?.id == comment.id, self.backend != nil { return }
        self.rootComment = comment
        self.backend = backend
        page = 1
        hasMore = true
        replies = []
        errorMessage = nil
        sendError = nil
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        guard let backend, let comment = rootComment else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await backend.fetchCommentReplies(aid: comment.oid, rootRpid: comment.id, page: page)
            hasMore = !fetched.isEmpty
            page += 1
            replies.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendReply(message: String, parentRpid: Int) async {
        guard let backend, let comment = rootComment else { return }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await backend.replyComment(aid: comment.oid, rootRpid: comment.id, parentRpid: parentRpid, message: text)
            sendError = nil
            page = 1
            hasMore = true
            replies = []
            await loadMore()
        } catch {
            sendError = L10n.f("comment.detail.reply.fail", error.localizedDescription)
        }
    }
}
