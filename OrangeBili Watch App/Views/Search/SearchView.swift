import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @EnvironmentObject private var tabBarState: TabBarState

    var body: some View {
        List {
            Section {
                TextField(L10n.t("search.placeholder"), text: $viewModel.keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section {
                CompactDisclosure {
                    Text(L10n.t("search.filters"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } content: {
                    Picker(L10n.t("search.scope"), selection: $viewModel.scope) {
                        ForEach(SearchViewModel.Scope.allCases) { scope in
                            Text(scopeTitle(scope)).tag(scope)
                        }
                    }
                    .onChange(of: viewModel.scope) { _, _ in
                        Task { await viewModel.search(reset: true) }
                    }

                    if viewModel.scope == .video {
                        Picker(L10n.t("search.order"), selection: $viewModel.order) {
                            Text(L10n.t("search.order.comprehensive")).tag("totalrank")
                            Text(L10n.t("search.order.plays")).tag("click")
                            Text(L10n.t("search.order.latest")).tag("pubdate")
                        }
                        .onChange(of: viewModel.order) { _, _ in
                            Task { await viewModel.search(reset: true) }
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                EmptyStateView(error, systemImage: "exclamationmark.triangle")
            }

            switch viewModel.scope {
            case .video:
                ForEach(viewModel.videoResults) { video in
                    NavigationLink {
                        VideoDetailView(seedVideo: video)
                    } label: {
                        VideoRowView(video: video)
                    }
                }
            case .user:
                ForEach(viewModel.userResults) { user in
                    NavigationLink {
                        UploaderView(mid: user.id)
                    } label: {
                        HStack(spacing: 8) {
                            AsyncCachedImage(url: user.avatarURL) {
                                Circle().fill(.gray.opacity(0.24))
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.caption2)
                                Text(L10n.f("label.fans", Formatting.count(user.fans)))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                if !user.sign.isEmpty {
                                    Text(user.sign)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            case .article:
                ForEach(viewModel.articleResults) { article in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.caption2)
                            .lineLimit(2)
                        Text(article.author)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        if !article.summary.isEmpty {
                            Text(article.summary)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
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
            } else if hasAnyResult {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }
        .listStyle(.plain)
        .coordinateSpace(name: "scroll")
        .trackScrollOffset { tabBarState.update(offset: $0) }
        .navigationTitle(L10n.t("search.title"))
        .onSubmit {
            Task { await viewModel.search(reset: true) }
        }
        .onChange(of: viewModel.keyword) { _, value in
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.errorMessage = nil
            }
        }
    }

    private var hasAnyResult: Bool {
        switch viewModel.scope {
        case .video:
            return !viewModel.videoResults.isEmpty
        case .user:
            return !viewModel.userResults.isEmpty
        case .article:
            return !viewModel.articleResults.isEmpty
        }
    }

    private func scopeTitle(_ scope: SearchViewModel.Scope) -> String {
        switch scope {
        case .video: return L10n.t("search.scope.video")
        case .user: return L10n.t("search.scope.user")
        case .article: return L10n.t("search.scope.article")
        }
    }
}
