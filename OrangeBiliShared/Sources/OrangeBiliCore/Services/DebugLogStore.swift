import Foundation

public struct DebugLogEntry: Identifiable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let message: String

    public init(category: String, message: String, timestamp: Date = Date()) {
        id = UUID()
        self.timestamp = timestamp
        self.category = category
        self.message = message
    }
}

public final class DebugLogStore: ObservableObject {
    public static let shared = DebugLogStore()

    @Published public private(set) var entries: [DebugLogEntry] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "debug.log.store", qos: .utility)
    private var persistWorkItem: DispatchWorkItem?

    #if os(watchOS)
    private let maxEntries = 400
    #else
    private let maxEntries = 1200
    #endif

    private init(filename: String = "debug_logs.json") {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = folder.appendingPathComponent(filename)
        entries = loadFromDisk()
    }

    public func log(category: String, message: String) {
        let entry = DebugLogEntry(category: category, message: message)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.insert(entry, at: 0)
            self.entries = Array(self.entries.prefix(self.maxEntries))
            self.schedulePersist()
        }
    }

    public func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries = []
            self?.persist()
        }
    }

    private func schedulePersist() {
        persistWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.persist() }
        persistWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    private func loadFromDisk() -> [DebugLogEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([DebugLogEntry].self, from: data)) ?? []
    }

    private func persist() {
        let snapshot = entries
        queue.async { [fileURL] in
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}
