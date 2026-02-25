import SwiftUI
import OrangeBiliCore

struct MeView: View {
    @EnvironmentObject private var render: RenderSettings
    @EnvironmentObject private var apiBackend: BiliAPIBackend
    @EnvironmentObject private var tabBarState: TabBarState

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AccountView()
                } label: {
                    SummaryCard(
                        L10n.t("me.account"),
                        subtitle: apiBackend.isLoggedIn ? L10n.t("me.status.loggedIn") : L10n.t("me.status.loggedOut"),
                        systemImage: "person.crop.circle"
                    )
                }

                NavigationLink {
                    RenderSettingsView()
                } label: {
                    SummaryCard(
                        L10n.t("me.render"),
                        subtitle: L10n.t("me.render.subtitle"),
                        systemImage: "slider.horizontal.3"
                    )
                }

                NavigationLink {
                    AboutHubView()
                } label: {
                    SummaryCard(
                        L10n.t("me.about"),
                        subtitle: L10n.t("me.about.subtitle"),
                        systemImage: "info.circle"
                    )
                }
            }
        }
        .font(.system(size: UIStyle.fontSize(11)))
        .listStyle(.plain)
        .coordinateSpace(name: "scroll")
        .trackScrollOffset { tabBarState.update(offset: $0) }
        .navigationTitle(L10n.t("me.title"))
        .task {
            await apiBackend.refreshAuthState()
        }
    }
}

private struct AccountView: View {
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    var body: some View {
        List {
            Section {
                NavigationLink(L10n.t("me.account.qrLogin")) {
                    QRLoginExperimentalView()
                }
                if let mid = apiBackend.loggedInMid {
                    NavigationLink(L10n.t("me.account.profile")) {
                        UploaderView(mid: mid)
                    }
                    NavigationLink(L10n.t("me.account.following")) {
                        FollowingListView()
                    }
                    NavigationLink(L10n.t("me.account.cloudFavorites")) {
                        CloudFavoritesView()
                    }
                    Button(L10n.t("me.account.logout"), role: .destructive) {
                        Task { await apiBackend.clearLoginSession() }
                    }
                }
                NavigationLink(L10n.t("me.account.visitHistory")) {
                    UploaderVisitHistoryView()
                }
            }

            Section {
                Text(apiBackend.isLoggedIn ? L10n.t("me.status.loggedIn.detail") : L10n.t("me.status.loggedOut.detail"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(L10n.t("me.status.hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("me.account"))
    }
}

private struct RenderSettingsView: View {
    @EnvironmentObject private var render: RenderSettings

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("render.textScale", String(format: "%.2f", render.textScale)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
#if os(tvOS)
                    HStack(spacing: 12) {
                        Button {
                            render.textScale = max(0.65, render.textScale - 0.05)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                        Text(String(format: "%.2f", render.textScale))
                            .font(.caption2)
                            .frame(minWidth: 40)

                        Button {
                            render.textScale = min(1.35, render.textScale + 0.05)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                    }
#else
                    Slider(value: $render.textScale, in: 0.65 ... 1.35, step: 0.05)
#endif
                }

                Toggle(L10n.t("render.compact"), isOn: $render.compactStats)
                Toggle(L10n.t("render.resume"), isOn: $render.resumeFromLast)

                NavigationLink(L10n.t("danmaku.title")) {
                    DanmakuSettingsView()
                }

                HStack(spacing: 8) {
                    Text(L10n.t("render.descriptionLines"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        if render.detailDescriptionLines > 2 {
                            render.detailDescriptionLines -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                    Text("\(render.detailDescriptionLines)")
                        .font(.caption2)
                        .frame(minWidth: 16)

                    Button {
                        if render.detailDescriptionLines < 8 {
                            render.detailDescriptionLines += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("render.commentScale", String(format: "%.2f", render.commentTextScale)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
#if os(tvOS)
                    HStack(spacing: 12) {
                        Button {
                            render.commentTextScale = max(0.65, render.commentTextScale - 0.05)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                        Text(String(format: "%.2f", render.commentTextScale))
                            .font(.caption2)
                            .frame(minWidth: 40)

                        Button {
                            render.commentTextScale = min(1.4, render.commentTextScale + 0.05)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                    }
#else
                    Slider(value: $render.commentTextScale, in: 0.65 ... 1.4, step: 0.05)
#endif
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("render.cardScale", String(format: "%.2f", render.videoCardScale)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
#if os(tvOS)
                    HStack(spacing: 12) {
                        Button {
                            render.videoCardScale = max(0.75, render.videoCardScale - 0.05)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                        Text(String(format: "%.2f", render.videoCardScale))
                            .font(.caption2)
                            .frame(minWidth: 40)

                        Button {
                            render.videoCardScale = min(1.05, render.videoCardScale + 0.05)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                    }
#else
                    Slider(value: $render.videoCardScale, in: 0.75 ... 1.05, step: 0.05)
#endif
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("me.render"))
    }
}

private struct AboutHubView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(L10n.t("me.about.features")) {
                    VideoFeatureCompactView()
                }
                NavigationLink(L10n.t("me.about.app")) {
                    AboutView()
                }
                Text(L10n.t("me.about.hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("me.about"))
    }
}
