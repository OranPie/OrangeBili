import SwiftUI

struct CommentsView: View {
    @StateObject private var viewModel: CommentsViewModel
    @EnvironmentObject private var render: RenderSettings

    init(aid: Int) {
        _viewModel = StateObject(wrappedValue: CommentsViewModel(aid: aid))
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage, viewModel.comments.isEmpty {
                EmptyStateView(error, systemImage: "exclamationmark.triangle")
            }

            ForEach(viewModel.comments) { comment in
                NavigationLink {
                    CommentDetailView(comment: comment)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(comment.username)
                                .font(.system(size: 11 * render.commentTextScale, weight: .bold))
                            Spacer()
                            Text(Formatting.time(comment.timestamp))
                                .font(.system(size: 9 * render.commentTextScale))
                                .foregroundStyle(.secondary)
                        }
                        Text(comment.message)
                            .font(.system(size: 10.5 * render.commentTextScale))
                            .lineLimit(5)
                        HStack(spacing: 8) {
                            Label(Formatting.count(comment.likeCount), systemImage: "hand.thumbsup")
                            if comment.replyCount > 0 {
                                Label(Formatting.count(comment.replyCount), systemImage: "arrowshape.turn.up.left")
                            }
                        }
                        .font(.system(size: 8.8 * render.commentTextScale))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if !viewModel.comments.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("comments.title"))
        .task {
            await viewModel.loadInitialIfNeeded()
        }
    }
}
