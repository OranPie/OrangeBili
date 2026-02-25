import Compression
import Foundation

final class DanmakuService {
    static let shared = DanmakuService()

    private let parser = DanmakuParser()

    func fetchDanmaku(cid: Int) async throws -> [DanmakuItem] {
        if let cached = await DanmakuCacheStore.shared.loadXML(for: cid) {
            return parser.parse(data: cached)
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
                await DanmakuCacheStore.shared.saveXML(xmlData, for: cid)
                return parser.parse(data: xmlData)
            } catch {
                lastError = error
                DebugLogStore.shared.log(category: "danmaku", message: "fetch fail url=\(url.absoluteString) err=\(error.localizedDescription)")
            }
        }

        throw lastError
    }

    private func fetchData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Apple Watch; watchOS 11.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
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
}

