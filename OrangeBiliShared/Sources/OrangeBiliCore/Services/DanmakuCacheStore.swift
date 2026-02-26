import Foundation

public struct DanmakuCacheEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let cid: Int
    public let source: DanmakuSource
    public let fileSize: Int
    public let updatedAt: Date

    public init(id: String, cid: Int, source: DanmakuSource, fileSize: Int, updatedAt: Date) {
        self.id = id
        self.cid = cid
        self.source = source
        self.fileSize = fileSize
        self.updatedAt = updatedAt
    }
}

public actor DanmakuCacheStore {
    public static let shared = DanmakuCacheStore()

    private let folderURL: URL
    private let ttl: TimeInterval = 6 * 60 * 60

    init() {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        folderURL = baseURL.appendingPathComponent("danmaku-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    // MARK: - Source-aware API

    public func load(for cid: Int, source: DanmakuSource) -> Data? {
        let url = fileURL(for: cid, source: source)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date
        else { return nil }
        if Date().timeIntervalSince(modified) > ttl {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    public func save(_ data: Data, for cid: Int, source: DanmakuSource) {
        let url = fileURL(for: cid, source: source)
        try? data.write(to: url, options: [.atomic])
    }

    // MARK: - Legacy compat

    public func loadXML(for cid: Int) -> Data? {
        load(for: cid, source: .xml)
    }

    public func saveXML(_ data: Data, for cid: Int) {
        save(data, for: cid, source: .xml)
    }

    public func clear(for cid: Int) {
        for source in DanmakuSource.allCases {
            let url = fileURL(for: cid, source: source)
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func clear(for cid: Int, source: DanmakuSource) {
        let url = fileURL(for: cid, source: source)
        try? FileManager.default.removeItem(at: url)
    }

    public func clearAll() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func removeEntry(id: String) {
        guard let entry = listEntries().first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: fileURL(for: entry.cid, source: entry.source))
    }

    public func listEntries() -> [DanmakuCacheEntry] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: Array(keys))) ?? []
        return urls.compactMap { url in
            let name = url.lastPathComponent
            guard name.hasPrefix("dm_") else { return nil }
            let stem = url.deletingPathExtension().lastPathComponent
            guard let cid = Int(stem.replacingOccurrences(of: "dm_", with: "")) else { return nil }
            let ext = url.pathExtension.lowercased()
            let source: DanmakuSource = (ext == "xml") ? .xml : .protobuf
            let rv = try? url.resourceValues(forKeys: keys)
            let size = rv?.fileSize ?? ((try? Data(contentsOf: url).count) ?? 0)
            let updated = rv?.contentModificationDate ?? .distantPast
            return DanmakuCacheEntry(id: "\(cid)-\(source.rawValue)", cid: cid, source: source, fileSize: size, updatedAt: updated)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func cachedFilesCount() -> Int {
        listEntries().count
    }

    public func totalCacheSizeBytes() -> Int {
        listEntries().reduce(0) { $0 + $1.fileSize }
    }

    private func fileURL(for cid: Int, source: DanmakuSource) -> URL {
        let ext = source == .xml ? "xml" : "pb"
        return folderURL.appendingPathComponent("dm_\(cid).\(ext)")
    }
}
