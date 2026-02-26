import SwiftUI
import OrangeBiliCore

struct MeView: View {
    @EnvironmentObject private var render: RenderSettings
    @EnvironmentObject private var apiBackend: BiliAPIBackend
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var downloadManager: OfflineDownloadManager
    @EnvironmentObject private var tabBarState: TabBarState

    @State private var profile: UploaderProfile?
    @State private var loadingProfile = false

    var body: some View {
        List {
            // MARK: - Profile header
            Section {
                profileHeader
            }

            // MARK: - Account items (login required)
            if apiBackend.isLoggedIn {
                Section {
                    if let mid = apiBackend.loggedInMid {
                        NavigationLink {
                            FollowingListView()
                        } label: {
                            Label(L10n.t("me.account.following"), systemImage: "person.2")
                        }

                        NavigationLink {
                            UploaderVisitHistoryView()
                        } label: {
                            Label(L10n.t("me.account.friends"), systemImage: "person.2.circle")
                        }

                        NavigationLink {
                            UploaderVideosView(mid: mid, uploaderName: profile?.name ?? "")
                        } label: {
                            Label(L10n.t("me.account.submissions"), systemImage: "play.rectangle")
                        }

                        NavigationLink {
                            DynamicsPlaceholderView()
                        } label: {
                            Label(L10n.t("me.account.dynamics"), systemImage: "bolt.horizontal")
                        }
                    }
                }
            }

            // MARK: - Content
            Section {
                NavigationLink {
                    HistoryRecordsView()
                } label: {
                    Label(L10n.t("me.account.history"), systemImage: "clock")
                }

                NavigationLink {
                    CloudFavoritesView()
                } label: {
                    Label(L10n.t("me.account.cloudFavorites"), systemImage: "icloud.and.arrow.down")
                }

                NavigationLink {
                    OfflineDownloadsHubView()
                } label: {
                    Label(L10n.t("me.account.downloads"), systemImage: "arrow.down.circle")
                }
            }

            // MARK: - Logout
            if apiBackend.isLoggedIn {
                Section {
                    Button(L10n.t("me.account.logout"), role: .destructive) {
                        Task { await apiBackend.clearLoginSession() }
                    }
                }
            }
        }
        .font(.system(size: UIStyle.fontSize(11)))
        .listStyle(.plain)
        .coordinateSpace(name: "scroll")
        .trackScrollOffset { tabBarState.update(offset: $0) }
        .navigationTitle(L10n.t("me.title"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task {
            await apiBackend.refreshAuthState()
            await loadProfile()
        }
    }

    // MARK: - Profile Header

    @ViewBuilder
    private var profileHeader: some View {
        if apiBackend.isLoggedIn, let profile {
            HStack(spacing: 10) {
                AsyncCachedImage(url: profile.avatarURL) {
                    Circle().fill(.gray.opacity(0.2))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: UIStyle.fontSize(13), weight: .medium))
                    if !profile.signature.isEmpty {
                        Text(profile.signature)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)
        } else {
            NavigationLink {
                QRLoginExperimentalView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("me.account.notLoggedIn"))
                            .font(.system(size: UIStyle.fontSize(13), weight: .medium))
                        Text(L10n.t("me.account.tapToLogin"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func loadProfile() async {
        guard apiBackend.isLoggedIn, profile == nil, !loadingProfile else { return }
        loadingProfile = true
        defer { loadingProfile = false }
        if let (p, _) = try? await apiBackend.fetchMyUploader() {
            profile = p
        }
    }
}

// MARK: - Downloads Hub (combines active + completed)

private struct OfflineDownloadsHubView: View {
    @EnvironmentObject private var downloadManager: OfflineDownloadManager

    var body: some View {
        List {
            if !activeDownloads.isEmpty {
                Section(L10n.t("tools.downloads.active")) {
                    ForEach(activeDownloads) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.caption2)
                                .lineLimit(2)
                            Text(item.bvid)
                                .font(.system(size: UIStyle.fontSize(8), design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Section(L10n.t("tools.downloads.completed")) {
                if completedDownloads.isEmpty {
                    EmptyStateView(L10n.t("downloads.completed.empty"), systemImage: "checkmark.circle")
                } else {
                    ForEach(completedDownloads) { item in
                        NavigationLink {
                            OfflineVideoManageView(itemID: item.id)
                        } label: {
                            HStack(spacing: 8) {
                                AsyncCachedImage(url: item.localCoverURL ?? item.coverURL) {
                                    RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.24))
                                }
                                .frame(width: 60, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.caption2).lineLimit(2)
                                    Text(item.bvid)
                                        .font(.system(size: UIStyle.fontSize(8), design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("me.account.downloads"))
    }

    private var activeDownloads: [DownloadStatusItem] {
        downloadManager.items.filter { $0.state != .completed }
    }

    private var completedDownloads: [DownloadStatusItem] {
        downloadManager.items.filter { $0.state == .completed && $0.localFileURL != nil }
    }
}

// MARK: - Dynamics Placeholder

private struct DynamicsPlaceholderView: View {
    var body: some View {
        EmptyStateView(L10n.t("me.account.dynamics"), systemImage: "bolt.horizontal")
            .navigationTitle(L10n.t("me.account.dynamics"))
    }
}
