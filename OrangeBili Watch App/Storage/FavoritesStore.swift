import Foundation

struct FavoriteRecord: Identifiable, Codable, Hashable {
    let id: String
    let bvid: String
    let aid: Int
    let title: String
    let author: String
    let mid: Int?
    let coverURL: URL?
    let durationText: String
    let savedAt: Date

    init(bvid: String, aid: Int, title: String, author: String, mid: Int?, coverURL: URL?, durationText: String, savedAt: Date = Date()) {
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

    var asVideo: BiliVideo {
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
            sourceTag: "本地收藏"
        )
    }
}

protocol FavoritesStoreProtocol {
    func isFavorite(bvid: String) -> Bool
    func toggle(video: BiliVideo)
    func remove(bvid: String)
    func loadRecords() -> [FavoriteRecord]
}

final class FavoritesStore: ObservableObject, FavoritesStoreProtocol {
    @Published private(set) var records: [FavoriteRecord] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "favorites.store.queue", qos: .userInitiated)

    init(filename: String = "favorites.json") {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = folder.appendingPathComponent(filename)
        records = loadRecords()
    }

    func loadRecords() -> [FavoriteRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([FavoriteRecord].self, from: data)) ?? []
    }

    func isFavorite(bvid: String) -> Bool {
        records.contains { $0.bvid == bvid }
    }

    func toggle(video: BiliVideo) {
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

    func remove(bvid: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let updated = self.records.filter { $0.bvid != bvid }
            self.persist(records: updated)
            DispatchQueue.main.async {
                self.records = updated
            }
        }
    }

    private func persist(records: [FavoriteRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
