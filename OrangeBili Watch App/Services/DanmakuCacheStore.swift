import Foundation

actor DanmakuCacheStore {
    static let shared = DanmakuCacheStore()

    private let folderURL: URL
    private let ttl: TimeInterval = 6 * 60 * 60

    init() {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        folderURL = baseURL.appendingPathComponent("danmaku-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func loadXML(for cid: Int) -> Data? {
        let url = fileURL(for: cid)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date
        else { return nil }
        if Date().timeIntervalSince(modified) > ttl {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    func saveXML(_ data: Data, for cid: Int) {
        let url = fileURL(for: cid)
        try? data.write(to: url, options: [.atomic])
    }

    func clear(for cid: Int) {
        let url = fileURL(for: cid)
        try? FileManager.default.removeItem(at: url)
    }

    private func fileURL(for cid: Int) -> URL {
        folderURL.appendingPathComponent("dm_\(cid).xml")
    }
}

