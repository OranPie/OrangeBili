import SwiftUI

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
            Section("原评论") {
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
                    Button(liked ? "取消赞" : "点赞") {
                        Task { await toggleLike() }
                    }
                    .disabled(!apiBackend.isLoggedIn)

                    if canDelete {
                        Button("删除", role: .destructive) {
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

            Section("回复") {
                if replies.isEmpty && !loading {
                    Text("暂无回复")
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
                        Button("回复") {
                            replyTargetRpid = reply.id
                        }
                        .font(.system(size: 8.5 * render.commentTextScale))
                    }
                }

                if loading {
                    ProgressView()
                } else if hasMore {
                    Button("加载更多") {
                        Task { await loadMore() }
                    }
                }
            }

            Section("发送回复") {
                if let replyTargetRpid {
                    Text("回复 ID: \(replyTargetRpid)")
                        .font(.system(size: 8.5 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                } else {
                    Text("回复楼主")
                        .font(.system(size: 8.5 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                }
                TextField("回复内容", text: $replyText)
                Button("发送") {
                    Task { await sendReply() }
                }
                .disabled(!apiBackend.isLoggedIn || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if replyTargetRpid != nil {
                    Button("取消指定回复", role: .cancel) {
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
        .navigationTitle("评论详情")
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
            statusText = target ? "点赞成功" : "取消点赞"
        } catch {
            statusText = "点赞失败：\(error.localizedDescription)"
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
            statusText = "回复成功"
            replies = []
            page = 1
            hasMore = true
            await loadMore()
        } catch {
            statusText = "回复失败：\(error.localizedDescription)"
        }
    }

    private func deleteComment() async {
        do {
            try await apiBackend.deleteComment(aid: comment.oid, rpid: comment.id)
            statusText = "已删除"
        } catch {
            statusText = "删除失败：\(error.localizedDescription)"
        }
    }
}
