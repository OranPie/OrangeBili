import CryptoKit
import Foundation

public struct OfflineCacheEntry: Identifiable, Hashable {
    public let id: String
    public let key: String
    public let fileSize: Int
    public let updatedAt: Date

    public var shortKey: String {
        if key.count <= 40 { return key }
        return String(key.prefix(40)) + "..."
    }

    public init(id: String, key: String, fileSize: Int, updatedAt: Date) {
        self.id = id
        self.key = key
        self.fileSize = fileSize
        self.updatedAt = updatedAt
    }
}

public actor OfflineCacheStore {
    public static let shared = OfflineCacheStore()

    private struct CacheIndexEntry: Codable {
        let id: String
        let key: String
        let fileName: String
        let fileSize: Int
        let updatedAt: Date
    }

    private let folderURL: URL
    private let indexURL: URL
    private var index: [String: CacheIndexEntry] = [:]

    public init() {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        folderURL = baseURL.appendingPathComponent("offline-api-cache", isDirectory: true)
        indexURL = folderURL.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        loadIndex()
    }

    public func loadData(for key: String) -> Data? {
        if let entry = index[key] {
            let fileURL = folderURL.appendingPathComponent(entry.fileName)
            return try? Data(contentsOf: fileURL)
        }

        let legacyURL = folderURL.appendingPathComponent(legacyFileName(for: key))
        return try? Data(contentsOf: legacyURL)
    }

    public func saveData(_ data: Data, for key: String) {
        let id = makeID(for: key)
        let fileName = id + ".json"
        let fileURL = folderURL.appendingPathComponent(fileName)
        try? data.write(to: fileURL, options: [.atomic])

        index[key] = CacheIndexEntry(
            id: id,
            key: key,
            fileName: fileName,
            fileSize: data.count,
            updatedAt: Date()
        )
        saveIndex()
    }

    public func listEntries() -> [OfflineCacheEntry] {
        index.values
            .map { OfflineCacheEntry(id: $0.id, key: $0.key, fileSize: $0.fileSize, updatedAt: $0.updatedAt) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func removeEntry(id: String) {
        guard let pair = index.first(where: { $0.value.id == id }) else { return }
        let fileURL = folderURL.appendingPathComponent(pair.value.fileName)
        try? FileManager.default.removeItem(at: fileURL)
        index.removeValue(forKey: pair.key)
        saveIndex()
    }

    public func cachedFilesCount() -> Int {
        index.count
    }

    public func totalCacheSizeBytes() -> Int {
        index.values.reduce(0) { $0 + $1.fileSize }
    }

    public func clearAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else { return }
        for url in files {
            try? FileManager.default.removeItem(at: url)
        }
        index = [:]
        saveIndex()
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([String: CacheIndexEntry].self, from: data)
        else { return }
        index = decoded
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }

    private func makeID(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func legacyFileName(for key: String) -> String {
        let safe = key.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
        return safe + ".json"
    }
}
