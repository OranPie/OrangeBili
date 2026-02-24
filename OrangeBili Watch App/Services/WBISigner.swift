import CryptoKit
import Foundation

actor WBISigner {
    static let shared = WBISigner()

    private struct WBIKeys {
        let imgKey: String
        let subKey: String
        let fetchedAt: Date

        var isExpired: Bool {
            Date().timeIntervalSince(fetchedAt) > 60 * 10
        }
    }

    private var cachedKeys: WBIKeys?

    private let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32,
        15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19,
        29, 28, 14, 39, 12, 38, 41, 13,
        37, 48, 7, 16, 24, 55, 40, 61,
        26, 17, 0, 1, 60, 51, 30, 4,
        22, 25, 54, 21, 56, 59, 6, 63,
        57, 62, 11, 36, 20, 34, 44, 52
    ]

    func signIfNeeded(endpoint: BiliEndpoint, query: [String: String]) async throws -> [String: String] {
        guard endpoint.requiresWbi else { return query }

        let keys = try await loadKeys()
        let mixinKey = buildMixinKey(imgKey: keys.imgKey, subKey: keys.subKey)

        var signed = query
        signed["wts"] = String(Int(Date().timeIntervalSince1970))

        let sorted = signed.sorted(by: { $0.key < $1.key })
        let encoded = sorted.map { key, value in
            let sanitized = sanitize(value)
            return "\(percentEncode(key))=\(percentEncode(sanitized))"
        }.joined(separator: "&")

        signed["w_rid"] = md5Hex(encoded + mixinKey)
        return signed
    }

    private func loadKeys() async throws -> WBIKeys {
        if let cachedKeys, !cachedKeys.isExpired {
            return cachedKeys
        }

        var request = URLRequest(url: URL(string: "https://api.bilibili.com/x/web-interface/nav")!)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: request)

        let response: NavEnvelope
        do {
            response = try JSONDecoder().decode(NavEnvelope.self, from: data)
        } catch {
            let raw = String(data: data.prefix(280), encoding: .utf8) ?? "<binary>"
            DebugLogStore.shared.log(category: "sign", message: "decode nav fail: \(error.localizedDescription) raw=\(raw)")
            throw error
        }
        guard response.code == 0,
              let wbiImage = response.data?.wbiImage,
              let imgURL = URL(string: wbiImage.imgURL),
              let subURL = URL(string: wbiImage.subURL)
        else {
            let raw = String(data: data.prefix(280), encoding: .utf8) ?? "<binary>"
            DebugLogStore.shared.log(category: "sign", message: "invalid nav payload code=\(response.code) raw=\(raw)")
            throw BiliError.badResponse
        }

        let keys = WBIKeys(
            imgKey: imgURL.deletingPathExtension().lastPathComponent,
            subKey: subURL.deletingPathExtension().lastPathComponent,
            fetchedAt: Date()
        )
        DebugLogStore.shared.log(category: "sign", message: "keys refreshed img=\(keys.imgKey.prefix(8)) sub=\(keys.subKey.prefix(8))")
        cachedKeys = keys
        return keys
    }

    private func buildMixinKey(imgKey: String, subKey: String) -> String {
        let merged = Array(imgKey + subKey)
        let mapped = mixinKeyEncTab.compactMap { index -> Character? in
            guard index < merged.count else { return nil }
            return merged[index]
        }
        return String(mapped.prefix(32))
    }

    private func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "[!'()*]", with: "", options: .regularExpression)
    }

    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func md5Hex(_ value: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct DeviceIdentity {
    static let shared = DeviceIdentity()

    private let key = "orangebili.buvid3"

    var buvid3: String {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let generated = "\(UUID().uuidString.lowercased())infoc"
        defaults.set(generated, forKey: key)
        return generated
    }
}

private struct NavEnvelope: Decodable {
    struct DataBody: Decodable {
        struct WBIImage: Decodable {
            let imgURL: String
            let subURL: String

            private enum CodingKeys: String, CodingKey {
                case imgURL = "img_url"
                case subURL = "sub_url"
                case imgURLCamel = "imgUrl"
                case subURLCamel = "subUrl"
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                imgURL =
                    (try? c.decodeIfPresent(String.self, forKey: .imgURL)) ??
                    (try? c.decodeIfPresent(String.self, forKey: .imgURLCamel)) ??
                    ""
                subURL =
                    (try? c.decodeIfPresent(String.self, forKey: .subURL)) ??
                    (try? c.decodeIfPresent(String.self, forKey: .subURLCamel)) ??
                    ""
            }
        }

        let wbiImage: WBIImage?

        private enum CodingKeys: String, CodingKey {
            case wbiImgSnake = "wbi_img"
            case webImgSnake = "web_img"
            case wbiImgCamel = "wbiImg"
            case webImgCamel = "webImg"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            wbiImage =
                (try? c.decodeIfPresent(WBIImage.self, forKey: .wbiImgSnake)) ??
                (try? c.decodeIfPresent(WBIImage.self, forKey: .webImgSnake)) ??
                (try? c.decodeIfPresent(WBIImage.self, forKey: .wbiImgCamel)) ??
                (try? c.decodeIfPresent(WBIImage.self, forKey: .webImgCamel))
        }
    }

    let code: Int
    let data: DataBody?

    private enum CodingKeys: String, CodingKey {
        case code
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        data = try? c.decodeIfPresent(DataBody.self, forKey: .data)
    }
}
