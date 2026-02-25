import Foundation

protocol HistoryStoreProtocol {
    func loadRecords() -> [HistoryRecord]
    func savePlayback(video: BiliVideo, progressSeconds: Int)
    func progressSeconds(for bvid: String) -> Int?
    func clear()
    func delete(id: String)
}

final class HistoryStore: ObservableObject, HistoryStoreProtocol {
    @Published private(set) var records: [HistoryRecord] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "history.store.queue", qos: .userInitiated)

    init(filename: String = "history.json") {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = folder.appendingPathComponent(filename)
        records = loadRecords()
    }

    func loadRecords() -> [HistoryRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([HistoryRecord].self, from: data)) ?? []
    }

    func savePlayback(video: BiliVideo, progressSeconds: Int) {
        queue.async { [weak self] in
            guard let self else { return }
            var mutable = self.records
            let newRecord = HistoryRecord(
                bvid: video.bvid,
                title: video.title,
                coverURL: video.coverURL,
                watchedAt: Date(),
                progressSeconds: progressSeconds
            )
            mutable.removeAll { $0.bvid == video.bvid }
            mutable.insert(newRecord, at: 0)
            mutable = Array(mutable.prefix(200))
            self.persist(records: mutable)
            DispatchQueue.main.async {
                self.records = mutable
            }
        }
    }

    func progressSeconds(for bvid: String) -> Int? {
        records.first(where: { $0.bvid == bvid })?.progressSeconds
    }

    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            self.persist(records: [])
            DispatchQueue.main.async {
                self.records = []
            }
        }
    }

    func delete(id: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let filtered = self.records.filter { $0.id != id }
            self.persist(records: filtered)
            DispatchQueue.main.async {
                self.records = filtered
            }
        }
    }

    private func persist(records: [HistoryRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
