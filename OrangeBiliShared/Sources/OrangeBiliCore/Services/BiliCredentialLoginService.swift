import Foundation

public struct BiliCredentialLoginService {
    public struct PasswordPayload {
        public let username: String
        public let password: String
        public let token: String
        public let challenge: String
        public let validate: String
        public let seccode: String

        public init(username: String, password: String, token: String, challenge: String, validate: String, seccode: String) {
            self.username = username
            self.password = password
            self.token = token
            self.challenge = challenge
            self.validate = validate
            self.seccode = seccode
        }
    }

    public struct SMSPayload {
        public let cid: String
        public let tel: String
        public let code: String
        public let source: String
        public let captchaKey: String

        public init(cid: String, tel: String, code: String, source: String, captchaKey: String) {
            self.cid = cid
            self.tel = tel
            self.code = code
            self.source = source
            self.captchaKey = captchaKey
        }
    }

    public init() {}

    public func loginByPassword(_ payload: PasswordPayload) async throws -> BiliLoginSession {
        let request = try makeRequest(path: "/x/passport-login/web/login", body: [
            "username": payload.username,
            "password": payload.password,
            "keep": "true",
            "token": payload.token,
            "challenge": payload.challenge,
            "validate": payload.validate,
            "seccode": payload.seccode
        ])
        return try await executeLogin(request: request)
    }

    public func loginBySMS(_ payload: SMSPayload) async throws -> BiliLoginSession {
        let request = try makeRequest(path: "/x/passport-login/web/login/sms", body: [
            "cid": payload.cid,
            "tel": payload.tel,
            "code": payload.code,
            "source": payload.source,
            "captcha_key": payload.captchaKey
        ])
        return try await executeLogin(request: request)
    }

    private func makeRequest(path: String, body: [String: String]) throws -> URLRequest {
        var components = URLComponents(string: "https://passport.bilibili.com")
        components?.path = path
        guard let url = components?.url else {
            throw BiliError.invalidURL
        }

        let bodyString = body
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(bodyString.utf8)
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(PlatformInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        return request
    }

    private func executeLogin(request: URLRequest) async throws -> BiliLoginSession {
        let (data, response) = try await URLSession.shared.data(for: request)
        let envelope = try JSONDecoder().decode(LoginEnvelope.self, from: data)
        guard envelope.code == 0 else {
            throw BiliError.apiError(code: envelope.code, message: envelope.message)
        }

        let session = extractLoginSession(from: response)
        guard session.isValid else {
            throw BiliError.badResponse
        }
        return session
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
}

private struct LoginEnvelope: Decodable {
    let code: Int
    let message: String

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(Int.self, forKey: .code)) ?? -1
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? (try? c.decodeIfPresent(String.self, forKey: .msg)) ?? "unknown"
    }
}
