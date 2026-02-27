import SwiftUI
import OrangeBiliCore

struct MeView: View {
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
                            SummaryCard(
                                L10n.t("me.account.following"),
                                subtitle: L10n.t("me.account.following.subtitle"),
                                systemImage: "person.2"
                            )
                        }

                        NavigationLink {
                            FriendsListView()
                        } label: {
                            SummaryCard(
                                L10n.t("me.account.friends"),
                                subtitle: L10n.t("me.account.friends.subtitle"),
                                systemImage: "person.2.circle"
                            )
                        }

                        NavigationLink {
                            UploaderVideosView(mid: mid, uploaderName: profile?.name ?? "")
                        } label: {
                            SummaryCard(
                                L10n.t("me.account.submissions"),
                                subtitle: L10n.t("me.account.submissions.subtitle"),
                                systemImage: "play.rectangle"
                            )
                        }

                        NavigationLink {
                            DynamicsView(scope: .mine)
                        } label: {
                            SummaryCard(
                                L10n.t("me.account.dynamics"),
                                subtitle: L10n.t("me.account.dynamics.subtitle"),
                                systemImage: "bolt.horizontal"
                            )
                        }

                        NavigationLink {
                            DynamicsView(scope: .following)
                        } label: {
                            SummaryCard(
                                L10n.t("dynamic.scope.following"),
                                subtitle: L10n.t("me.account.dynamics.subtitle"),
                                systemImage: "person.3"
                            )
                        }
                    }
                }
            }

            // MARK: - Content
            Section {
                NavigationLink {
                    HistoryRecordsView()
                } label: {
                    SummaryCard(
                        L10n.t("me.account.history"),
                        subtitle: L10n.t("tools.history.subtitle"),
                        systemImage: "clock",
                        trailing: "\(historyStore.records.count)"
                    )
                }

                NavigationLink {
                    CloudFavoritesView()
                } label: {
                    SummaryCard(
                        L10n.t("me.account.cloudFavorites"),
                        subtitle: L10n.t("tools.favorites.cloud.subtitle"),
                        systemImage: "icloud.and.arrow.down",
                        trailing: "\(favoritesStore.records.count)"
                    )
                }

                NavigationLink {
                    UploaderVisitHistoryView()
                } label: {
                    SummaryCard(
                        L10n.t("me.account.visitHistory"),
                        subtitle: L10n.t("me.account.visitHistory.subtitle"),
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                    )
                }

                NavigationLink {
                    DownloadsCenterView()
                } label: {
                    SummaryCard(
                        L10n.t("downloads.center.title"),
                        subtitle: L10n.t("me.account.downloads.subtitle"),
                        systemImage: "arrow.down.circle",
                        trailing: "\(downloadManager.items.count)"
                    )
                }
            }

            // MARK: - Logout
            if apiBackend.isLoggedIn {
                Section {
                    Button(L10n.t("me.account.logout"), role: .destructive) {
                        Task {
                            await apiBackend.clearLoginSession()
                            ToastManager.shared.show(L10n.t("login.status.cleared"), icon: "person.slash", style: .info)
                        }
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
