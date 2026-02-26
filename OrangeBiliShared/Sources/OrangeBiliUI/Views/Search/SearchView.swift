import SwiftUI
import OrangeBiliCore

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @EnvironmentObject private var tabBarState: TabBarState

    private var historyStore: SearchHistoryStore { viewModel.searchHistoryStore }

    var body: some View {
        Group {
            if case .grid = UIStyle.videoLayout {
                gridLayout
            } else {
                listLayout
            }
        }
        .coordinateSpace(name: "scroll")
        .trackScrollOffset { tabBarState.update(offset: $0) }
        .navigationTitle(L10n.t("search.title"))
        .onSubmit {
            Task { await viewModel.search(reset: true) }
        }
        .onChange(of: viewModel.keyword) { value in
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: - Grid Layout (tvOS)

    private var gridLayout: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                searchField
                scopePicker

                if showRecentSearches {
                    recentSearchesSection
                }

                if viewModel.isLoading && !hasAnyResult {
                    SkeletonVideoList(count: 4)
                } else {
                    resultContent(gridMode: true)
                }

                paginationFooter
            }
            .padding(.horizontal, UIStyle.listRowInsets.leading)
            .padding(.vertical, UIStyle.listRowInsets.top)
        }
        .refreshable {
            await viewModel.search(reset: true)
        }
    }

    // MARK: - List Layout (watchOS / iOS)

    private var listLayout: some View {
        List {
            Section {
                searchField
            }

            Section {
                scopePicker
            }

            if showRecentSearches {
                Section {
                    recentSearchesSection
                }
            }

            if viewModel.isLoading && !hasAnyResult {
                SkeletonVideoList(count: 4)
            } else {
                resultContent(gridMode: false)
            }

            paginationFooter
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.search(reset: true)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var searchField: some View {
#if os(macOS)
        TextField(L10n.t("search.placeholder"), text: $viewModel.keyword)
            .autocorrectionDisabled(true)
#else
        TextField(L10n.t("search.placeholder"), text: $viewModel.keyword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
#endif
    }

    @ViewBuilder
    private var scopePicker: some View {
        #if os(watchOS)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SearchViewModel.Scope.allCases) { scope in
                    Button {
                        viewModel.scope = scope
                        Task { await viewModel.search(reset: true) }
                    } label: {
                        Text(scopeTitle(scope))
                            .font(.system(size: 10, weight: viewModel.scope == scope ? .bold : .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.scope == scope ? Theme.accent.opacity(0.25) : Theme.cardBackground,
                                in: Capsule()
                            )
                            .foregroundStyle(viewModel.scope == scope ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if viewModel.scope == .video {
            Picker(L10n.t("search.order"), selection: $viewModel.order) {
                Text(L10n.t("search.order.comprehensive")).tag("totalrank")
                Text(L10n.t("search.order.plays")).tag("click")
                Text(L10n.t("search.order.latest")).tag("pubdate")
            }
            .onChange(of: viewModel.order) { _ in
                Task { await viewModel.search(reset: true) }
            }
        }
        #else
        Picker(L10n.t("search.scope"), selection: $viewModel.scope) {
            ForEach(SearchViewModel.Scope.allCases) { scope in
                Text(scopeTitle(scope)).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.scope) { _ in
            Task { await viewModel.search(reset: true) }
        }

        if viewModel.scope == .video {
            Picker(L10n.t("search.order"), selection: $viewModel.order) {
                Text(L10n.t("search.order.comprehensive")).tag("totalrank")
                Text(L10n.t("search.order.plays")).tag("click")
                Text(L10n.t("search.order.latest")).tag("pubdate")
            }
            .onChange(of: viewModel.order) { _ in
                Task { await viewModel.search(reset: true) }
            }
        }
        #endif
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.t("search.recent"))
                    .font(.system(size: UIStyle.fontSize(10), weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    historyStore.clear()
                } label: {
                    Text(L10n.t("search.recent.clear"))
                        .font(.system(size: UIStyle.fontSize(9)))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if historyStore.recentSearches.isEmpty {
                Text(L10n.t("search.recent.empty"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(historyStore.recentSearches, id: \.self) { keyword in
                        Button {
                            viewModel.keyword = keyword
                            Task { await viewModel.search(reset: true) }
                        } label: {
                            Text(keyword)
                                .font(.system(size: UIStyle.fontSize(9.5)))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.cardBackground, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultContent(gridMode: Bool) -> some View {
        switch viewModel.scope {
        case .video:
            if gridMode {
                VideoListingView(videos: viewModel.videoResults, rowInsets: nil) { _ in EmptyView() }
            } else {
                VideoListingView(videos: viewModel.videoResults) { _ in EmptyView() }
            }
        case .user:
            ForEach(viewModel.userResults) { user in
                NavigationLink {
                    UploaderView(mid: user.id)
                } label: {
                    HStack(spacing: 8) {
                        AsyncCachedImage(url: user.avatarURL) {
                            Circle().fill(Theme.shimmerBase)
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
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.isLoading && hasAnyResult {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 8) {
                EmptyStateView(error, systemImage: "exclamationmark.triangle")
                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    Text(L10n.t("action.retry"))
                        .font(.caption2)
                }
            }
        } else if hasAnyResult && viewModel.hasMore {
            Button {
                Task { await viewModel.loadMore() }
            } label: {
                HStack {
                    Spacer()
                    Text(L10n.t("action.loadMore"))
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var showRecentSearches: Bool {
        viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasAnyResult
    }

    private var hasAnyResult: Bool {
        switch viewModel.scope {
        case .video: return !viewModel.videoResults.isEmpty
        case .user: return !viewModel.userResults.isEmpty
        case .article: return !viewModel.articleResults.isEmpty
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

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
