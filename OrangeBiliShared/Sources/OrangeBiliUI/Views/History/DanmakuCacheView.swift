import SwiftUI
import OrangeBiliCore

struct DanmakuCacheView: View {
    @State private var cacheFiles = 0
    @State private var cacheSizeBytes = 0
    @State private var cacheEntries: [DanmakuCacheEntry] = []

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

            Section(L10n.t("tools.danmakuCache.section")) {
                if cacheEntries.isEmpty {
                    EmptyStateView(L10n.t("cache.empty"), systemImage: "text.bubble")
                } else {
                    ForEach(cacheEntries) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("CID \(entry.cid)")
                                    .font(.system(size: UIStyle.fontSize(8), design: .monospaced))
                                Text(entry.source == .protobuf ? "PB" : "XML")
                                    .font(.system(size: UIStyle.fontSize(7), weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(formatBytes(entry.fileSize)) · \(Formatting.time(entry.updatedAt))")
                                .font(.system(size: UIStyle.fontSize(8)))
                                .foregroundStyle(.secondary)
                        }
#if !os(tvOS)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await DanmakuCacheStore.shared.removeEntry(id: entry.id)
                                    DebugLogStore.shared.log(category: "danmaku.cache", message: "remove entry id=\(entry.id)")
                                    await refreshCacheStats()
                                }
                            } label: {
                                Label(L10n.t("action.delete"), systemImage: "trash")
                            }
                        }
#endif
                    }
                }

                Button(L10n.t("cache.clear"), role: .destructive) {
                    Task {
                        await DanmakuCacheStore.shared.clearAll()
                        DebugLogStore.shared.log(category: "danmaku.cache", message: "clear all")
                        await refreshCacheStats()
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("tools.danmakuCache"))
        .task {
            await refreshCacheStats()
        }
    }

    private func refreshCacheStats() async {
        cacheFiles = await DanmakuCacheStore.shared.cachedFilesCount()
        cacheSizeBytes = await DanmakuCacheStore.shared.totalCacheSizeBytes()
        cacheEntries = await DanmakuCacheStore.shared.listEntries()
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
