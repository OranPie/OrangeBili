import Foundation
import Combine

public struct FavoriteRecord: Identifiable, Codable, Hashable {
    public let id: String
    public let bvid: String
    public let aid: Int64
    public let title: String
    public let author: String
    public let mid: Int?
    public let coverURL: URL?
    public let durationText: String
    public let savedAt: Date

    public init(bvid: String, aid: Int64, title: String, author: String, mid: Int?, coverURL: URL?, durationText: String, savedAt: Date = Date()) {
        id = bvid
        self.bvid = bvid
        self.aid = aid
        self.title = title
        self.author = author
        self.mid = mid
        self.coverURL = coverURL
        self.durationText = durationText
        self.savedAt = savedAt
    }

    public var asVideo: BiliVideo {
        BiliVideo(
            bvid: bvid,
            aid: aid,
            title: title,
            author: author,
            mid: mid,
            coverURL: coverURL,
            viewCount: 0,
            danmakuCount: 0,
            durationText: durationText,
            description: "",
            sourceTag: L10n.t("favorites.local.source")
        )
    }
}

public protocol FavoritesStoreProtocol {
    func isFavorite(bvid: String) -> Bool
    func toggle(video: BiliVideo)
    func remove(bvid: String)
    func loadRecords() -> [FavoriteRecord]
}

public final class FavoritesStore: ObservableObject, FavoritesStoreProtocol {
    @Published public private(set) var records: [FavoriteRecord] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "favorites.store.queue", qos: .userInitiated)

    public init(filename: String = "favorites.json") {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = folder.appendingPathComponent(filename)
        records = loadRecords()
    }

    public func loadRecords() -> [FavoriteRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([FavoriteRecord].self, from: data)) ?? []
    }

    public func isFavorite(bvid: String) -> Bool {
        records.contains { $0.bvid == bvid }
    }

    public func toggle(video: BiliVideo) {
        if isFavorite(bvid: video.bvid) {
            remove(bvid: video.bvid)
        } else {
            let record = FavoriteRecord(
                bvid: video.bvid,
                aid: video.aid,
                title: video.title,
                author: video.author,
                mid: video.mid,
                coverURL: video.coverURL,
                durationText: video.durationText
            )
            queue.async { [weak self] in
                guard let self else { return }
                var updated = self.records
                updated.removeAll { $0.bvid == record.bvid }
                updated.insert(record, at: 0)
                self.persist(records: updated)
                DispatchQueue.main.async {
                    self.records = updated
                }
            }
        }
    }

    public func remove(bvid: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let updated = self.records.filter { $0.bvid != bvid }
            self.persist(records: updated)
            DispatchQueue.main.async {
                self.records = updated
            }
        }
    }

    public func merge(records incoming: [FavoriteRecord]) {
        queue.async { [weak self] in
            guard let self else { return }
            var latestByBvid: [String: FavoriteRecord] = [:]

            for record in self.records + incoming {
                if let existing = latestByBvid[record.bvid] {
                    if record.savedAt > existing.savedAt {
                        latestByBvid[record.bvid] = record
                    }
                } else {
                    latestByBvid[record.bvid] = record
                }
            }

            let merged = latestByBvid.values.sorted { $0.savedAt > $1.savedAt }
            self.persist(records: merged)
            DispatchQueue.main.async {
                self.records = merged
            }
        }
    }

    private func persist(records: [FavoriteRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
