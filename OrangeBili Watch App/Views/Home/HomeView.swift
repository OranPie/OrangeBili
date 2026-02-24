import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.videos) { video in
                NavigationLink {
                    VideoDetailView(seedVideo: video)
                } label: {
                    VideoRowView(video: video)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
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
        .navigationTitle("推荐")
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
