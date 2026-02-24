import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var downloadManager: OfflineDownloadManager
    @EnvironmentObject private var debugLogStore: DebugLogStore
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var cacheFiles = 0
    @State private var cacheSizeBytes = 0

    @State private var jumpBVID = ""
    @State private var jumpVideo: BiliVideo?
    @State private var jumpActive = false
    @State private var jumpUID = ""
    @State private var jumpUploaderMid: Int?
    @State private var jumpUploaderActive = false

    var body: some View {
        List {
            Section("BV / UID 跳转") {
                TextField("输入 BV 号", text: $jumpBVID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 11, design: .monospaced))

                Button("打开视频") {
                    openBV()
                }

                TextField("输入 UID", text: $jumpUID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 11, design: .monospaced))

                Button("打开 UP 主页") {
                    openUID()
                }
            }

            Section("本地收藏") {
                if favoritesStore.records.isEmpty {
                    Text("暂无本地收藏")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("云端收藏") {
                if apiBackend.isLoggedIn {
                    NavigationLink("打开云端收藏夹") {
                        CloudFavoritesView()
                    }
                } else {
                    Text("请先在“我的”中登录后查看云端收藏")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("历史") {
                NavigationLink("打开观看历史") {
                    HistoryRecordsView()
                }
                HStack {
                    Text("历史条目")
                    Spacer()
                    Text("\(historyStore.records.count)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
            }

            Section("离线缓存(API)") {
                NavigationLink("打开缓存管理") {
                    OfflineAPICacheView()
                }

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

            Section("下载任务(视频)") {
                if activeDownloads.isEmpty {
                    Text("暂无下载任务")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

                            Text("\(item.state.rawValue) · \(Int(item.progress * 100))% · \(formatBytes(Int(item.speedBytesPerSec)))/s")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .swipeActions {
                            if item.state == .downloading || item.state == .queued {
                                Button("取消", role: .destructive) {
                                    downloadManager.cancel(itemID: item.id)
                                }
                            }
                            Button(role: .destructive) {
                                downloadManager.remove(itemID: item.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("离线管理(视频)") {
                if completedDownloads.isEmpty {
                    Text("暂无已完成下载")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

            Section("日志") {
                NavigationLink("打开全局日志") {
                    GlobalLogView()
                }
                HStack {
                    Text("当前条数")
                    Spacer()
                    Text("\(debugLogStore.entries.count)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                Button("清空播放历史", role: .destructive) {
                    historyStore.clear()
                }
            }
        }
        .font(.system(size: 11))
        .navigationTitle("工具")
        .task {
            await refreshCacheStats()
        }
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
            author: "BV 跳转",
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
