import SwiftUI
import OrangeBiliCore

struct CommentDetailView: View {
    let comment: CommentItem

    @EnvironmentObject private var apiBackend: BiliAPIBackend
    @EnvironmentObject private var render: RenderSettings

    @State private var replies: [CommentItem] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasMore = true
    @State private var replyText = ""
    @State private var replyTargetRpid: Int?
    @State private var statusText: String?
    @State private var liked = false

    var body: some View {
        List {
            Section(L10n.t("comment.detail.original")) {
                NavigationLink {
                    UploaderView(mid: comment.mid ?? 0)
                } label: {
                    HStack {
                        Text(comment.username)
                            .font(.system(size: 11 * render.commentTextScale, weight: .bold))
                        Spacer()
                        Text(Formatting.time(comment.timestamp))
                            .font(.system(size: 9 * render.commentTextScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(comment.mid == nil)
                Text(comment.message)
                    .font(.system(size: 11 * render.commentTextScale))
                HStack(spacing: 8) {
                    Button(liked ? L10n.t("action.unlike") : L10n.t("action.like")) {
                        Task { await toggleLike() }
                    }
                    .disabled(!apiBackend.isLoggedIn)

                    if canDelete {
                        Button(L10n.t("action.delete"), role: .destructive) {
                            Task { await deleteComment() }
                        }
                    }
                }
                if let statusText {
                    Text(statusText)
                        .font(.system(size: 8 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.t("comment.detail.replies")) {
                if replies.isEmpty && !loading {
                    Text(L10n.t("comment.detail.replies.empty"))
                        .font(.system(size: 10 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                }

                ForEach(replies) { reply in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            NavigationLink(reply.username) {
                                UploaderView(mid: reply.mid ?? 0)
                            }
                            .font(.system(size: 10 * render.commentTextScale, weight: .semibold))
                            .disabled(reply.mid == nil)
                            Spacer()
                            Text(Formatting.time(reply.timestamp))
                                .font(.system(size: 8 * render.commentTextScale))
                                .foregroundStyle(.secondary)
                        }
                        Text(reply.message)
                            .font(.system(size: 10 * render.commentTextScale))
                            .lineLimit(6)
                        Button(L10n.t("comment.detail.reply")) {
                            replyTargetRpid = reply.id
                        }
                        .font(.system(size: 8.5 * render.commentTextScale))
                    }
                }

                if loading {
                    ProgressView()
                } else if hasMore {
                    Button(L10n.t("action.loadMore")) {
                        Task { await loadMore() }
                    }
                }
            }

            Section(L10n.t("comment.detail.send")) {
                if let replyTargetRpid {
                    Text(L10n.f("comment.detail.replyId", replyTargetRpid))
                        .font(.system(size: 8.5 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.t("comment.detail.replyRoot"))
                        .font(.system(size: 8.5 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                }
                TextField(L10n.t("comment.detail.placeholder"), text: $replyText)
                Button(L10n.t("action.send")) {
                    Task { await sendReply() }
                }
                .disabled(!apiBackend.isLoggedIn || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if replyTargetRpid != nil {
                    Button(L10n.t("comment.detail.reply.cancel"), role: .cancel) {
                        replyTargetRpid = nil
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.system(size: 8.5 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("comment.detail.title"))
        .task {
            await loadMore()
        }
    }

    private var canDelete: Bool {
        apiBackend.loggedInMid != nil && apiBackend.loggedInMid == comment.mid
    }

    private func loadMore() async {
        guard !loading, hasMore else { return }
        loading = true
        defer { loading = false }
        do {
            let fetched = try await apiBackend.fetchCommentReplies(aid: comment.oid, rootRpid: comment.id, page: page)
            hasMore = !fetched.isEmpty
            page += 1
            replies.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleLike() async {
        do {
            let target = !liked
            try await apiBackend.likeComment(aid: comment.oid, rpid: comment.id, liked: target)
            liked = target
            statusText = target ? L10n.t("action.like.success") : L10n.t("action.like.cancel")
        } catch {
            statusText = L10n.f("action.like.fail", error.localizedDescription)
        }
    }

    private func sendReply() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let parent = replyTargetRpid ?? comment.id
            try await apiBackend.replyComment(aid: comment.oid, rootRpid: comment.id, parentRpid: parent, message: text)
            replyText = ""
            replyTargetRpid = nil
            statusText = L10n.t("comment.detail.reply.success")
            replies = []
            page = 1
            hasMore = true
            await loadMore()
        } catch {
            statusText = L10n.f("comment.detail.reply.fail", error.localizedDescription)
        }
    }

    private func deleteComment() async {
        do {
            try await apiBackend.deleteComment(aid: comment.oid, rpid: comment.id)
            statusText = L10n.t("comment.detail.delete.success")
        } catch {
            statusText = L10n.f("comment.detail.delete.fail", error.localizedDescription)
        }
    }
}
