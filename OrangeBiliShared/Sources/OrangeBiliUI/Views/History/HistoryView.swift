import SwiftUI
import OrangeBiliCore

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var downloadManager: OfflineDownloadManager
    @EnvironmentObject private var debugLogStore: DebugLogStore
    @EnvironmentObject private var apiBackend: BiliAPIBackend
    @EnvironmentObject private var tabBarState: TabBarState

    @State private var cacheFiles = 0
    @State private var cacheSizeBytes = 0

    var body: some View {
        List {
            Section {
                NavigationLink {
                    JumpToolsView()
                } label: {
                    SummaryCard(L10n.t("tools.jump"), subtitle: L10n.t("tools.jump.subtitle"), systemImage: "arrow.up.right.circle")
                }

                NavigationLink {
                    LocalFavoritesView()
                } label: {
                    SummaryCard(
                        L10n.t("tools.favorites.local"),
                        subtitle: L10n.t("tools.favorites.local.subtitle"),
                        systemImage: "heart.fill",
                        trailing: "\(favoritesStore.records.count)"
                    )
                }

                NavigationLink {
                    HistoryRecordsView()
                } label: {
                    SummaryCard(
                        L10n.t("tools.history"),
                        subtitle: L10n.t("tools.history.subtitle"),
                        systemImage: "clock",
                        trailing: "\(historyStore.records.count)"
                    )
                }
            }

            Section {
                if apiBackend.isLoggedIn {
                    NavigationLink {
                        CloudFavoritesView()
                    } label: {
                        SummaryCard(L10n.t("tools.favorites.cloud"), subtitle: L10n.t("tools.favorites.cloud.subtitle"), systemImage: "icloud.and.arrow.down")
                    }
                } else {
                    EmptyStateView(L10n.t("tools.favorites.cloud.login"), systemImage: "person.crop.circle.badge.exclamationmark")
                }
            } header: {
                Text(L10n.t("tools.cloud.section"))
            }

            Section {
                NavigationLink {
                    OfflineAPICacheView()
                } label: {
                    SummaryCard(
                        L10n.t("tools.cache"),
                        subtitle: L10n.t("tools.cache.subtitle"),
                        systemImage: "archivebox",
                        trailing: "\(cacheFiles)"
                    )
                }

                HStack {
                    Text(L10n.t("tools.cache.size"))
                    Spacer()
                    Text(formatBytes(cacheSizeBytes))
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                Button(L10n.t("tools.cache.refresh")) {
                    Task { await refreshCacheStats() }
                }
                .font(.caption2)

                NavigationLink {
                    ActiveDownloadsView()
                } label: {
                    SummaryCard(
                        L10n.t("tools.downloads.active"),
                        subtitle: L10n.t("tools.downloads.active.subtitle"),
                        systemImage: "arrow.down.circle",
                        trailing: "\(activeDownloads.count)"
                    )
                }

                NavigationLink {
                    CompletedDownloadsView()
                } label: {
                    SummaryCard(
                        L10n.t("tools.downloads.completed"),
                        subtitle: L10n.t("tools.downloads.completed.subtitle"),
                        systemImage: "checkmark.circle",
                        trailing: "\(completedDownloads.count)"
                    )
                }
            } header: {
                Text(L10n.t("tools.offline.section"))
            }

            Section {
                NavigationLink {
                    GlobalLogView()
                } label: {
                    SummaryCard(
                        L10n.t("tools.logs"),
                        subtitle: L10n.t("tools.logs.subtitle"),
                        systemImage: "doc.text.magnifyingglass",
                        trailing: "\(debugLogStore.entries.count)"
                    )
                }

                Button(L10n.t("tools.history.clear"), role: .destructive) {
                    historyStore.clear()
                }
                .font(.caption2)
            }
        }
        .font(.system(size: 11))
        .listStyle(.plain)
        .coordinateSpace(name: "scroll")
        .trackScrollOffset { tabBarState.update(offset: $0) }
        .navigationTitle(L10n.t("tools.title"))
        .task {
            await refreshCacheStats()
        }
    }

    private var activeDownloads: [DownloadStatusItem] {
        downloadManager.items.filter { $0.state != .completed }
    }

    private var completedDownloads: [DownloadStatusItem] {
        downloadManager.items.filter { $0.state == .completed && $0.localFileURL != nil }
    }

    private func refreshCacheStats() async {
        cacheFiles = await OfflineCacheStore.shared.cachedFilesCount()
        cacheSizeBytes = await OfflineCacheStore.shared.totalCacheSizeBytes()
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        if bytes >= 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) B"
    }
}

private struct JumpToolsView: View {
    @State private var jumpBVID = ""
    @State private var jumpVideo: BiliVideo?
    @State private var jumpActive = false
    @State private var jumpUID = ""
    @State private var jumpUploaderMid: Int?
    @State private var jumpUploaderActive = false

    var body: some View {
        List {
            Section {
                TextField(L10n.t("tools.jump.bvid"), text: $jumpBVID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 11, design: .monospaced))

                Button(L10n.t("tools.jump.openVideo")) {
                    openBV()
                }

                TextField(L10n.t("tools.jump.uid"), text: $jumpUID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 11, design: .monospaced))

                Button(L10n.t("tools.jump.openUploader")) {
                    openUID()
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("tools.jump"))
        .background(
            Group {
                NavigationLink(isActive: $jumpActive) {
                    if let jumpVideo {
                        VideoDetailView(seedVideo: jumpVideo)
                    }
                } label: {
                    EmptyView()
                }
                .hidden()

                NavigationLink(isActive: $jumpUploaderActive) {
                    if let jumpUploaderMid {
                        UploaderView(mid: jumpUploaderMid)
                    }
                } label: {
                    EmptyView()
                }
                .hidden()
            }
        )
    }

    private func openBV() {
        let cleaned = jumpBVID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isValidBVID(cleaned) else { return }
        jumpVideo = BiliVideo(
            bvid: cleaned,
            aid: 0,
            title: cleaned,
            author: L10n.t("tools.jump.bvAuthor"),
            mid: nil,
            coverURL: nil,
            viewCount: 0,
            danmakuCount: 0,
            durationText: "00:00",
            description: ""
        )
        jumpActive = true
    }

    private func isValidBVID(_ text: String) -> Bool {
        let pattern = "^BV[0-9A-Za-z]{10}$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private func openUID() {
        let cleaned = jumpUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let normalized = cleaned
            .replacingOccurrences(of: "UID", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mid = Int(normalized), mid > 0 else { return }
        jumpUploaderMid = mid
        jumpUploaderActive = true
    }
}

private struct LocalFavoritesView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore

    var body: some View {
        List {
            if favoritesStore.records.isEmpty {
                EmptyStateView(L10n.t("favorites.empty"), systemImage: "heart")
            } else {
                ForEach(favoritesStore.records) { record in
                    NavigationLink {
                        VideoDetailView(seedVideo: record.asVideo)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title)
                                .font(.caption2)
                                .lineLimit(2)
                            Text("\(record.author) · \(record.bvid)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            favoritesStore.remove(bvid: record.bvid)
                        } label: {
                            Label(L10n.t("action.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("favorites.local.title"))
    }
}

private struct ActiveDownloadsView: View {
    @EnvironmentObject private var downloadManager: OfflineDownloadManager

    var body: some View {
        List {
            if activeDownloads.isEmpty {
                EmptyStateView(L10n.t("downloads.active.empty"), systemImage: "arrow.down.circle")
            } else {
                ForEach(activeDownloads) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.caption2)
                            .lineLimit(2)
                        Text(item.bvid)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(L10n.f("downloads.active.status", stateText(item.state), Int(item.progress * 100), formatBytes(Int(item.speedBytesPerSec))))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .swipeActions {
                        if item.state == .downloading || item.state == .queued {
                            Button(L10n.t("action.cancel"), role: .destructive) {
                                downloadManager.cancel(itemID: item.id)
                            }
                        }
                        Button(role: .destructive) {
                            downloadManager.remove(itemID: item.id)
                        } label: {
                            Label(L10n.t("action.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("downloads.active.title"))
    }

    private var activeDownloads: [DownloadStatusItem] {
        downloadManager.items.filter { $0.state != .completed }
    }

    private func stateText(_ state: DownloadStatusItem.State) -> String {
        switch state {
        case .queued: return L10n.t("downloads.state.queued")
        case .downloading: return L10n.t("downloads.state.downloading")
        case .completed: return L10n.t("downloads.state.completed")
        case .failed: return L10n.t("downloads.state.failed")
        case .canceled: return L10n.t("downloads.state.canceled")
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        if bytes >= 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) B"
    }
}

private struct CompletedDownloadsView: View {
    @EnvironmentObject private var downloadManager: OfflineDownloadManager

    var body: some View {
        List {
            if completedDownloads.isEmpty {
                EmptyStateView(L10n.t("downloads.completed.empty"), systemImage: "checkmark.circle")
            } else {
                ForEach(completedDownloads) { item in
                    NavigationLink {
                        OfflineVideoManageView(itemID: item.id)
                    } label: {
                        HStack(spacing: 8) {
                            AsyncCachedImage(url: item.localCoverURL ?? item.coverURL) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.gray.opacity(0.24))
                            }
                            .frame(width: 60, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.caption2)
                                    .lineLimit(2)
                                Text(item.bvid)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("downloads.completed.title"))
    }

    private var completedDownloads: [DownloadStatusItem] {
        downloadManager.items.filter { $0.state == .completed && $0.localFileURL != nil }
    }
}
