import SwiftUI

struct FollowingListView: View {
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var users: [FollowingUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasMore = true

    var body: some View {
        List {
            if let errorMessage, users.isEmpty {
                EmptyStateView(errorMessage, systemImage: "exclamationmark.triangle")
            }

            ForEach(users) { user in
                NavigationLink {
                    UploaderView(mid: user.id)
                } label: {
                    HStack(spacing: 8) {
                        AsyncCachedImage(url: user.avatarURL) {
                            Circle().fill(.gray.opacity(0.24))
                        }
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(.caption2)
                            Text(L10n.f("label.fans", Formatting.count(user.fans)))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
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

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if !users.isEmpty, hasMore {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await loadMore() }
                    }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("following.title"))
        .task {
            guard users.isEmpty else { return }
            await loadMore()
        }
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await apiBackend.fetchMyFollowings(page: page)
            hasMore = !fetched.isEmpty
            page += 1
            users.append(contentsOf: fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
