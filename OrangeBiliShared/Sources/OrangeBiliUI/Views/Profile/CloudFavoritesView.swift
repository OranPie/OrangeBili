import SwiftUI
import OrangeBiliCore

struct CloudFavoritesView: View {
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var folders: [CloudFavoriteFolder] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage, folders.isEmpty {
                EmptyStateView(errorMessage, systemImage: "exclamationmark.triangle")
            }

            ForEach(folders) { folder in
                NavigationLink {
                    CloudFavoriteFolderDetailView(folder: folder)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.title)
                            .font(.caption2)
                            .lineLimit(2)
                        Text(L10n.f("label.items", folder.mediaCount))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("favorites.cloud.title"))
        .task {
            await loadFolders()
        }
    }

    private func loadFolders() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            folders = try await apiBackend.fetchCloudFavoriteFolders()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CloudFavoriteFolderDetailView: View {
    let folder: CloudFavoriteFolder

    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var videos: [BiliVideo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if case .grid = UIStyle.videoLayout {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIStyle.videoGridSpacing) {
                        if let errorMessage, videos.isEmpty {
                            EmptyStateView(errorMessage, systemImage: "exclamationmark.triangle")
                        }

                        VideoListingView(videos: videos, rowInsets: nil) { _ in
                            EmptyView()
                        }

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, UIStyle.listRowInsets.leading)
                    .padding(.vertical, UIStyle.listRowInsets.top)
                }
            } else {
                List {
                    if let errorMessage, videos.isEmpty {
                        EmptyStateView(errorMessage, systemImage: "exclamationmark.triangle")
                    }

                    VideoListingView(videos: videos) { _ in
                        EmptyView()
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(folder.title)
        .task {
            await loadVideos()
        }
    }

    private func loadVideos() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            videos = try await apiBackend.fetchCloudFavoriteVideos(mediaID: folder.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
