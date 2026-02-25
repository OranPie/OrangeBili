import Foundation
import Combine

public protocol HistoryStoreProtocol {
    func loadRecords() -> [HistoryRecord]
    func savePlayback(video: BiliVideo, progressSeconds: Int)
    func progressSeconds(for bvid: String) -> Int?
    func clear()
    func delete(id: String)
}

public final class HistoryStore: ObservableObject, HistoryStoreProtocol {
    @Published public private(set) var records: [HistoryRecord] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "history.store.queue", qos: .userInitiated)

    public init(filename: String = "history.json") {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = folder.appendingPathComponent(filename)
        records = loadRecords()
    }

    public func loadRecords() -> [HistoryRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([HistoryRecord].self, from: data)) ?? []
    }

    public func savePlayback(video: BiliVideo, progressSeconds: Int) {
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

    public func progressSeconds(for bvid: String) -> Int? {
        records.first(where: { $0.bvid == bvid })?.progressSeconds
    }

    public func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            self.persist(records: [])
            DispatchQueue.main.async {
                self.records = []
            }
        }
    }

    public func delete(id: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let filtered = self.records.filter { $0.id != id }
            self.persist(records: filtered)
            DispatchQueue.main.async {
                self.records = filtered
            }
        }
    }

    public func merge(records incoming: [HistoryRecord]) {
        queue.async { [weak self] in
            guard let self else { return }
            var latestByBvid: [String: HistoryRecord] = [:]

            for record in self.records + incoming {
                if let existing = latestByBvid[record.bvid] {
                    if record.watchedAt > existing.watchedAt {
                        latestByBvid[record.bvid] = record
                    }
                } else {
                    latestByBvid[record.bvid] = record
                }
            }

            let merged = latestByBvid.values.sorted { $0.watchedAt > $1.watchedAt }
            let trimmed = Array(merged.prefix(200))
            self.persist(records: trimmed)
            DispatchQueue.main.async {
                self.records = trimmed
            }
        }
    }

    private func persist(records: [HistoryRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
