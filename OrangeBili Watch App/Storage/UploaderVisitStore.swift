import Foundation

struct UploaderVisitRecord: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let avatarURL: URL?
    let signature: String
    let visitedAt: Date
}

final class UploaderVisitStore: ObservableObject {
    @Published private(set) var records: [UploaderVisitRecord] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "uploader.visit.store.queue", qos: .userInitiated)

    init(filename: String = "uploader_visit_history.json") {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = folder.appendingPathComponent(filename)
        records = loadRecords()
    }

    func save(profile: UploaderProfile) {
        let record = UploaderVisitRecord(
            id: profile.id,
            name: profile.name,
            avatarURL: profile.avatarURL,
            signature: profile.signature,
            visitedAt: Date()
        )
        queue.async { [weak self] in
            guard let self else { return }
            var updated = self.records
            updated.removeAll { $0.id == record.id }
            updated.insert(record, at: 0)
            updated = Array(updated.prefix(120))
            self.persist(records: updated)
            DispatchQueue.main.async {
                self.records = updated
            }
        }
    }

    func delete(id: Int) {
        queue.async { [weak self] in
            guard let self else { return }
            let updated = self.records.filter { $0.id != id }
            self.persist(records: updated)
            DispatchQueue.main.async {
                self.records = updated
            }
        }
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

    private func loadRecords() -> [UploaderVisitRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([UploaderVisitRecord].self, from: data)) ?? []
    }

    private func persist(records: [UploaderVisitRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
