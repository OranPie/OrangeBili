import SwiftUI
import OrangeBiliCore

struct OfflineAPICacheView: View {
    @State private var cacheFiles = 0
    @State private var cacheSizeBytes = 0
    @State private var cacheEntries: [OfflineCacheEntry] = []

    var body: some View {
        List {
            Section(L10n.t("cache.stats")) {
                HStack {
                    Text(L10n.t("cache.items"))
                    Spacer()
                    Text("\(cacheFiles)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                HStack {
                    Text(L10n.t("cache.size"))
                    Spacer()
                    Text(formatBytes(cacheSizeBytes))
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                Button(L10n.t("cache.refresh")) {
                    Task { await refreshCacheStats() }
                }
            }

            Section(L10n.t("cache.list")) {
                if cacheEntries.isEmpty {
                    EmptyStateView(L10n.t("cache.empty"), systemImage: "archivebox")
                } else {
                    ForEach(cacheEntries) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.shortKey)
                                .font(.system(size: 8, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(formatBytes(entry.fileSize)) · \(Formatting.time(entry.updatedAt))")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await OfflineCacheStore.shared.removeEntry(id: entry.id)
                                    DebugLogStore.shared.log(category: "cache", message: "remove cache entry id=\(entry.id.prefix(8))")
                                    await refreshCacheStats()
                                }
                            } label: {
                                Label(L10n.t("action.delete"), systemImage: "trash")
                            }
                        }
                    }
                }

                Button(L10n.t("cache.clear"), role: .destructive) {
                    Task {
                        await OfflineCacheStore.shared.clearAll()
                        DebugLogStore.shared.log(category: "cache", message: "clear all offline api cache")
                        await refreshCacheStats()
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("cache.title"))
        .task {
            await refreshCacheStats()
        }
    }

    private func refreshCacheStats() async {
        cacheFiles = await OfflineCacheStore.shared.cachedFilesCount()
        cacheSizeBytes = await OfflineCacheStore.shared.totalCacheSizeBytes()
        cacheEntries = await OfflineCacheStore.shared.listEntries()
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
