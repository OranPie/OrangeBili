import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        List {
            Section {
                TextField("搜索内容", text: $viewModel.keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section("类型") {
                Picker("类型", selection: $viewModel.scope) {
                    ForEach(SearchViewModel.Scope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .onChange(of: viewModel.scope) { _, _ in
                    Task { await viewModel.search(reset: true) }
                }
            }

            if viewModel.scope == .video {
                Section("排序") {
                    Picker("排序", selection: $viewModel.order) {
                        Text("综合").tag("totalrank")
                        Text("播放").tag("click")
                        Text("最新").tag("pubdate")
                    }
                    .onChange(of: viewModel.order) { _, _ in
                        Task { await viewModel.search(reset: true) }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                Text("粉丝 \(Formatting.count(user.fans))")
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
        .navigationTitle("搜索")
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
}
