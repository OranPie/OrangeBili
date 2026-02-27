import Compression
import Foundation

public final class DanmakuService {
    public static let shared = DanmakuService()

    private let xmlParser = DanmakuParser()
    private let pbParser = ProtobufDanmakuParser()

    /// Fetch danmaku with source routing and automatic fallback.
    public func fetchDanmaku(cid: Int64, aid: Int64 = 0, source: DanmakuSource = .protobuf, durationSeconds: Int = 0) async throws -> [DanmakuItem] {
        if source == .protobuf {
            do {
                return try await fetchProtobuf(cid: cid, aid: aid, durationSeconds: durationSeconds)
            } catch {
                DebugLogStore.shared.log(category: "danmaku", message: "protobuf failed, falling back to XML: \(error.localizedDescription)")
                return try await fetchXML(cid: cid)
            }
        }
        return try await fetchXML(cid: cid)
    }

    // MARK: - Protobuf (segmented)

    private func fetchProtobuf(cid: Int64, aid: Int64, durationSeconds: Int) async throws -> [DanmakuItem] {
        let resolvedDuration = await resolveDurationSeconds(cid: cid, aid: aid, fallback: durationSeconds)
        let segmentCount = max(1, resolvedDuration / 360 + 1)

        if let cached = await DanmakuCacheStore.shared.load(for: cid, source: .protobuf) {
            let items = pbParser.parse(data: cached)
            if isLikelyPoisonedCache(itemsCount: items.count, durationSeconds: resolvedDuration) {
                DebugLogStore.shared.log(
                    category: "danmaku.pb",
                    message: "cache bypass cid=\(cid) parsed=\(items.count) dur=\(resolvedDuration)s (likely over-fetched old cache)"
                )
                await DanmakuCacheStore.shared.clear(for: cid, source: .protobuf)
            } else {
                DebugLogStore.shared.log(category: "danmaku.pb", message: "cache hit cid=\(cid) bytes=\(cached.count) parsed=\(items.count)")
                return items
            }
        }

        let pidParam = aid > 0 ? "&pid=\(aid)" : ""
        DebugLogStore.shared.log(category: "danmaku.pb", message: "fetch cid=\(cid) aid=\(aid) dur=\(resolvedDuration)s segs=\(segmentCount)")

        #if os(watchOS)
        // Serial fetch on watchOS to avoid Bluetooth relay congestion
        var allItems: [DanmakuItem] = []
        var allRawData = Data()
        for seg in 1...segmentCount {
            guard let url = URL(string: "https://api.bilibili.com/x/v2/dm/web/seg.so?type=1&oid=\(cid)&segment_index=\(seg)\(pidParam)") else {
                throw BiliError.invalidURL
            }
            let data = try await fetchData(url: url)
            allRawData.append(data)
            allItems.append(contentsOf: pbParser.parse(data: data))
        }
        #else
        let allItems: [DanmakuItem]
        let allRawData: Data
        (allItems, allRawData) = try await withThrowingTaskGroup(of: (Int, [DanmakuItem], Data).self) { group in
            for seg in 1...segmentCount {
                group.addTask { [self] in
                    guard let url = URL(string: "https://api.bilibili.com/x/v2/dm/web/seg.so?type=1&oid=\(cid)&segment_index=\(seg)\(pidParam)") else {
                        throw BiliError.invalidURL
                    }
                    let data = try await self.fetchData(url: url)
                    return (seg, self.pbParser.parse(data: data), data)
                }
            }

            var collected: [(Int, [DanmakuItem], Data)] = []
            for try await result in group {
                collected.append(result)
            }
            collected.sort { $0.0 < $1.0 }
            var items: [DanmakuItem] = []
            var raw = Data()
            for (_, batch, data) in collected {
                items.append(contentsOf: batch)
                raw.append(data)
            }
            return (items, raw)
        }
        #endif

        DebugLogStore.shared.log(category: "danmaku.pb", message: "fetched raw=\(allRawData.count)B items=\(allItems.count)")

        // Deduplicate by id, sort by time
        var seen = Set<String>()
        let unique = allItems.filter { seen.insert($0.id).inserted }
        let sorted = unique.sorted { $0.time < $1.time }

        DebugLogStore.shared.log(category: "danmaku.pb", message: "dedup: \(allItems.count) -> \(unique.count)")

        // Cache concatenated raw protobuf for all segments
        await DanmakuCacheStore.shared.save(allRawData, for: cid, source: .protobuf)

        return sorted
    }

    // MARK: - XML (legacy)

    private func fetchXML(cid: Int64) async throws -> [DanmakuItem] {
        if let cached = await DanmakuCacheStore.shared.load(for: cid, source: .xml) {
            return xmlParser.parse(data: cached)
        }

        let urls = [
            URL(string: "https://api.bilibili.com/x/v1/dm/list.so?oid=\(cid)"),
            URL(string: "https://comment.bilibili.com/\(cid).xml")
        ].compactMap { $0 }

        var lastError: Error = BiliError.badResponse
        for url in urls {
            do {
                let data = try await fetchData(url: url)
                let xmlData = decodeIfNeeded(data: data)
                await DanmakuCacheStore.shared.save(xmlData, for: cid, source: .xml)
                return xmlParser.parse(data: xmlData)
            } catch {
                lastError = error
                DebugLogStore.shared.log(category: "danmaku", message: "fetch fail url=\(url.absoluteString) err=\(error.localizedDescription)")
            }
        }

        throw lastError
    }

    // MARK: - Network

    private func fetchData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            DebugLogStore.shared.log(category: "danmaku.net", message: "HTTP \(code) for \(url.absoluteString)")
            throw BiliError.badResponse
        }
        return data
    }

    private func decodeIfNeeded(data: Data) -> Data {
        if let text = String(data: data, encoding: .utf8),
           text.contains("<i>") || text.contains("<d ") {
            return data
        }
        if let decompressed = decompressZlib(data) {
            return decompressed
        }
        return data
    }

    private func decompressZlib(_ data: Data) -> Data? {
        let bufferSize = max(4096, data.count * 4)
        var output = Data(count: bufferSize)
        let result = output.withUnsafeMutableBytes { outBuf in
            data.withUnsafeBytes { inBuf in
                compression_decode_buffer(
                    outBuf.bindMemory(to: UInt8.self).baseAddress!,
                    bufferSize,
                    inBuf.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        if result == 0 {
            return nil
        }
        output.count = result
        return output
    }

    // MARK: - Duration Resolve (avoid loading only segment 1 when runtime duration is still 0)

    private func resolveDurationSeconds(cid: Int64, aid: Int64, fallback: Int) async -> Int {
        // Prefer authoritative page duration when aid/cid are available.
        if aid > 0 {
            do {
                if let value = try await fetchDurationSecondsFromView(aid: aid, cid: cid), value > 0 {
                    return value
                }
            } catch {
                DebugLogStore.shared.log(category: "danmaku.pb", message: "resolve duration from view failed: \(error.localizedDescription)")
            }
        }

        if fallback > 0 {
            // Runtime player durations (especially composed DASH) can be inflated.
            if fallback > 12 * 3600 {
                DebugLogStore.shared.log(category: "danmaku.pb", message: "ignore suspicious fallback duration=\(fallback)s cid=\(cid)")
                return 0
            }
            return fallback
        }

        return 0
    }

    private func isLikelyPoisonedCache(itemsCount: Int, durationSeconds: Int) -> Bool {
        guard durationSeconds > 0 else { return false }
        let shortVideo = durationSeconds <= 15 * 60
        return shortVideo && itemsCount > 4000
    }

    private func fetchDurationSecondsFromView(aid: Int64, cid: Int64) async throws -> Int? {
        guard let url = URL(string: "https://api.bilibili.com/x/web-interface/view?aid=\(aid)") else {
            throw BiliError.invalidURL
        }
        let data = try await fetchData(url: url)
        let payload = try JSONDecoder().decode(ViewEnvelope.self, from: data)
        guard payload.code == 0 else { return nil }
        return payload.data?.pages.first(where: { $0.cid == cid })?.duration
    }

    private struct ViewEnvelope: Decodable {
        let code: Int
        let data: ViewData?
    }

    private struct ViewData: Decodable {
        let pages: [ViewPage]
    }

    private struct ViewPage: Decodable {
        let cid: Int64
        let duration: Int
    }
}
