import Foundation

public struct QRLoginGenerateResult {
    public let url: String
    public let qrcodeKey: String

    public init(url: String, qrcodeKey: String) {
        self.url = url
        self.qrcodeKey = qrcodeKey
    }
}

public enum QRLoginPollResult {
    case waiting
    case scanned
    case expired
    case success(BiliLoginSession)
}

public struct BiliQRLoginService {
    public init() {}

    public func generate() async throws -> QRLoginGenerateResult {
        let request = try makeRequest(path: "/x/passport-login/web/qrcode/generate", query: [:])
        let (data, _) = try await fetchData(for: request)
        let envelope = try JSONDecoder().decode(GenerateEnvelope.self, from: data)
        guard envelope.code == 0, let body = envelope.data else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }
        return QRLoginGenerateResult(url: body.url, qrcodeKey: body.qrcodeKey)
    }

    public func poll(qrcodeKey: String) async throws -> QRLoginPollResult {
        let request = try makeRequest(path: "/x/passport-login/web/qrcode/poll", query: ["qrcode_key": qrcodeKey])
        let (data, response) = try await fetchData(for: request)
        let envelope = try JSONDecoder().decode(PollEnvelope.self, from: data)
        guard envelope.code == 0, let body = envelope.data else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }

        switch body.code {
        case 86101:
            return .waiting
        case 86090:
            return .scanned
        case 86038:
            return .expired
        case 0:
            let session = extractLoginSession(from: response)
            guard session.isValid else {
                throw BiliError.badResponse
            }
            return .success(session)
        default:
            throw BiliError.apiError(code: body.code, message: body.message)
        }
    }

    private func makeRequest(path: String, query: [String: String]) throws -> URLRequest {
        var components = URLComponents(string: "https://passport.bilibili.com")
        components?.path = path
        components?.queryItems = query.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components?.url else {
            throw BiliError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        return request
    }

    private func extractLoginSession(from response: URLResponse) -> BiliLoginSession {
        guard let http = response as? HTTPURLResponse else {
            return BiliLoginSession(sessdata: "", biliJct: nil, dedeUserID: nil, buvid3: nil, buvid4: nil)
        }

        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            guard let keyString = key as? String, let valueString = value as? String else { continue }
            headers[keyString] = valueString
        }

        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: http.url ?? URL(string: "https://passport.bilibili.com")!)
        let cookieMap = Dictionary(uniqueKeysWithValues: cookies.map { ($0.name, $0.value) })

        return BiliLoginSession(
            sessdata: cookieMap["SESSDATA"] ?? "",
            biliJct: cookieMap["bili_jct"],
            dedeUserID: cookieMap["DedeUserID"],
            buvid3: cookieMap["buvid3"],
            buvid4: cookieMap["buvid4"]
        )
    }

    private func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}

private struct GenerateEnvelope: Decodable {
    struct DataBody: Decodable {
        let url: String
        let qrcodeKey: String

        private enum CodingKeys: String, CodingKey {
            case url
            case qrcodeKey = "qrcode_key"
        }
    }

    let code: Int
    let message: String
    let data: DataBody?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        data = try? c.decodeIfPresent(DataBody.self, forKey: .data)
        message =
            (try? c.decodeIfPresent(String.self, forKey: .message)) ??
            (try? c.decodeIfPresent(String.self, forKey: .msg)) ??
            "unknown"
    }
}

private struct PollEnvelope: Decodable {
    struct DataBody: Decodable {
        let code: Int
        let message: String
    }

    let code: Int
    let message: String
    let data: DataBody?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        data = try? c.decodeIfPresent(DataBody.self, forKey: .data)
        message =
            (try? c.decodeIfPresent(String.self, forKey: .message)) ??
            (try? c.decodeIfPresent(String.self, forKey: .msg)) ??
            "unknown"
    }
}
