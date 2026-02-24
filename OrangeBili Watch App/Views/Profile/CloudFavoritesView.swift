import SwiftUI

struct CloudFavoritesView: View {
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var folders: [CloudFavoriteFolder] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage, folders.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(folders) { folder in
                NavigationLink {
                    CloudFavoriteFolderDetailView(folder: folder)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.title)
                            .font(.caption2)
                            .lineLimit(2)
                        Text("\(folder.mediaCount) 条")
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
        .navigationTitle("云端收藏夹")
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
        List {
            if let errorMessage, videos.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(videos) { video in
                NavigationLink {
                    VideoDetailView(seedVideo: video)
                } label: {
                    VideoRowView(video: video)
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
