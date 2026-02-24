import SwiftUI

struct OfflineAPICacheView: View {
    @State private var cacheFiles = 0
    @State private var cacheSizeBytes = 0
    @State private var cacheEntries: [OfflineCacheEntry] = []

    var body: some View {
        List {
            Section("统计") {
                HStack {
                    Text("缓存条目")
                    Spacer()
                    Text("\(cacheFiles)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                HStack {
                    Text("缓存大小")
                    Spacer()
                    Text(formatBytes(cacheSizeBytes))
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                Button("刷新缓存") {
                    Task { await refreshCacheStats() }
                }
            }

            Section("缓存列表") {
                if cacheEntries.isEmpty {
                    Text("暂无离线缓存")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }

                Button("清空离线缓存", role: .destructive) {
                    Task {
                        await OfflineCacheStore.shared.clearAll()
                        DebugLogStore.shared.log(category: "cache", message: "clear all offline api cache")
                        await refreshCacheStats()
                    }
                }
            }
        }
        .navigationTitle("API 离线缓存")
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
