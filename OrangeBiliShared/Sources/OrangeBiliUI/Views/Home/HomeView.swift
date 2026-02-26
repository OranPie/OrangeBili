import SwiftUI
import OrangeBiliCore

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var tabBarState: TabBarState

    var body: some View {
        Group {
            if case .grid = UIStyle.videoLayout {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                        if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
                            EmptyStateView(error, systemImage: "exclamationmark.triangle") {
                                Task { await viewModel.refresh() }
                            }
                        }

                        if viewModel.isLoading && viewModel.videos.isEmpty {
                            SkeletonVideoList(count: 5)
                        } else {
                            VideoListingView(videos: viewModel.videos, rowInsets: nil) { _ in
                                EmptyView()
                            }
                        }

                        if viewModel.isLoading && !viewModel.videos.isEmpty {
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
                        EmptyStateView(error, systemImage: "exclamationmark.triangle") {
                            Task { await viewModel.refresh() }
                        }
                    }

                    if viewModel.isLoading && viewModel.videos.isEmpty {
                        SkeletonVideoList(count: 5)
                    } else {
                        VideoListingView(videos: viewModel.videos) { _ in
                            EmptyView()
                        }
                    }

                    if viewModel.isLoading && !viewModel.videos.isEmpty {
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
        .coordinateSpace(name: "scroll")
        .trackScrollOffset { tabBarState.update(offset: $0) }
        .navigationTitle(L10n.t("home.title"))
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
