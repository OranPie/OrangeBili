import Foundation

protocol NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: BiliEndpoint, as type: T.Type) async throws -> T
}

private struct FriendlyNetworkError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct NetworkClient: NetworkClientProtocol {
    struct RetryPolicy {
        let maxAttempts: Int
        let baseDelayNanoseconds: UInt64

        static let `default` = RetryPolicy(maxAttempts: 3, baseDelayNanoseconds: 350_000_000)
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let retryPolicy: RetryPolicy
    private let authStore: BiliAuthStore

    init(retryPolicy: RetryPolicy = .default, authStore: BiliAuthStore = .shared) {
        self.retryPolicy = retryPolicy
        self.authStore = authStore
    }

    func request<T: Decodable>(_ endpoint: BiliEndpoint, as type: T.Type) async throws -> T {
        let debugCategory = "api"
        let loggedIn = await authStore.isLoggedIn()
        let candidates = endpoint.candidates(preferLoggedIn: loggedIn)
        log(debugCategory, "begin op=\(endpoint.path) loggedIn=\(loggedIn) candidates=\(candidates.map { $0.path }.joined(separator: ","))")

        var lastError: Error = BiliError.badResponse

        for candidate in candidates {
            log(debugCategory, "try endpoint=\(candidate.path) key=\(candidate.cacheKey)")

            if candidate.supportsOfflineCache,
               let cachedData = await OfflineCacheStore.shared.loadData(for: candidate.cacheKey) {
                do {
                    let cachedDecoded = try decode(data: cachedData, as: type, debugCategory: debugCategory, context: "cache")
                    log(debugCategory, "cache hit bytes=\(cachedData.count)")
                    return cachedDecoded
                } catch {
                    log(debugCategory, "cache decode fail: \(describe(error))")
                }
            }

            var query = candidate.query
            do {
                query = try await WBISigner.shared.signIfNeeded(endpoint: candidate, query: query)
            } catch {
                log(debugCategory, "sign fail endpoint=\(candidate.path): \(describe(error))")
                lastError = error
                continue
            }

            if let result: T = try await requestCandidate(candidate, query: query, as: type, debugCategory: debugCategory) {
                return result
            }
        }

        throw lastError
    }

    private func requestCandidate<T: Decodable>(
        _ endpoint: BiliEndpoint,
        query: [String: String],
        as type: T.Type,
        debugCategory: String
    ) async throws -> T? {
        var lastError: Error?

        for attempt in 1 ... retryPolicy.maxAttempts {
            var request = try endpoint.makeRequest(with: query)
            let timeout = min(45.0, 15.0 + Double(attempt - 1) * 10.0)
            request.timeoutInterval = timeout

            if let cookie = await authStore.cookieHeader(for: endpoint) {
                request.setValue(cookie, forHTTPHeaderField: "Cookie")
            } else if endpoint.authPolicy == .required {
                throw BiliError.unauthorized
            }

            log(debugCategory, "attempt=\(attempt) timeout=\(Int(timeout))s request=\(request.url?.absoluteString ?? endpoint.cacheKey)")

            do {
                let (data, decoded) = try await executeWithData(request: request, as: type, debugCategory: debugCategory)
                if endpoint.supportsOfflineCache {
                    await OfflineCacheStore.shared.saveData(data, for: endpoint.cacheKey)
                }
                log(debugCategory, "network ok endpoint=\(endpoint.path) attempt=\(attempt), bytes=\(data.count)")
                return decoded
            } catch {
                if let tlsMessage = tlsFriendlyMessage(from: error) {
                    lastError = FriendlyNetworkError(message: tlsMessage)
                } else {
                    lastError = error
                }
                log(debugCategory, "attempt=\(attempt) fail endpoint=\(endpoint.path): \(describe(error))")
                if attempt < retryPolicy.maxAttempts, shouldRetry(error: error) {
                    let delay = retryDelay(forAttempt: attempt)
                    log(debugCategory, "retry in \(Int(Double(delay) / 1_000_000))ms")
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                break
            }
        }

        if let lastError {
            if isUnauthorized(lastError), endpoint.authPolicy == .optional {
                log(debugCategory, "endpoint unauthorized, switch candidate endpoint")
            } else {
                log(debugCategory, "endpoint exhausted, switch candidate endpoint")
            }
        }
        return nil
    }

    private func executeWithData<T: Decodable>(request: URLRequest, as type: T.Type, debugCategory: String) async throws -> (Data, T) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BiliError.badResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let snippet = String(data: data.prefix(220), encoding: .utf8) ?? "<binary>"
            log(debugCategory, "http \(httpResponse.statusCode), raw=\(snippet)")
            throw BiliError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try decode(data: data, as: type, debugCategory: debugCategory, context: "network")
        return (data, decoded)
    }

    private func decode<T: Decodable>(data: Data, as type: T.Type, debugCategory: String, context: String) throws -> T {
        do {
            let wrapped = try decoder.decode(BiliEnvelope<T>.self, from: data)
            guard wrapped.code == 0 else {
                if wrapped.code == -101 {
                    throw BiliError.unauthorized
                }
                throw BiliError.apiError(code: wrapped.code, message: wrapped.message)
            }

            guard let decoded = wrapped.data else {
                let raw = String(data: data.prefix(260), encoding: .utf8) ?? "<binary>"
                log(debugCategory, "envelope missing data (\(context)), raw=\(raw)")
                throw BiliError.badResponse
            }
            return decoded
        } catch {
            if let wrappedError = error as? BiliError {
                log(debugCategory, "bili error (\(context)): \(wrappedError.localizedDescription)")
                throw wrappedError
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                let raw = String(data: data.prefix(300), encoding: .utf8) ?? "<binary>"
                log("api.decode", "decode fail (\(context)): \(describe(error)) | raw=\(raw)")
                throw error
            }
        }
    }

    private func shouldRetry(error: Error) -> Bool {
        if let bili = error as? BiliError {
            switch bili {
            case let .httpStatus(statusCode):
                return statusCode == 408 || statusCode == 429 || (500 ... 599).contains(statusCode)
            case .badResponse:
                return true
            case .unauthorized, .invalidURL, .apiError, .noStream:
                return false
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            // Offline/DNS failures should surface immediately instead of feeling "stuck" in retries.
            case .notConnectedToInternet, .cannotFindHost, .dnsLookupFailed:
                return false
            // TLS certificate/handshake failures are deterministic in current environment.
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .serverCertificateUntrusted, .clientCertificateRejected, .clientCertificateRequired:
                return false
            case .timedOut, .cannotConnectToHost, .networkConnectionLost:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func retryDelay(forAttempt attempt: Int) -> UInt64 {
        let multiplier = UInt64(1 << max(0, attempt - 1))
        return retryPolicy.baseDelayNanoseconds * multiplier
    }

    private func log(_ category: String, _ message: String) {
        DebugLogStore.shared.log(category: category, message: message)
    }

    private func describe(_ error: Error) -> String {
        if let decoding = error as? DecodingError {
            return String(describing: decoding)
        }
        if let urlError = error as? URLError {
            return "URLError(\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        }
        return error.localizedDescription
    }

    private func tlsFriendlyMessage(from error: Error) -> String? {
        guard let urlError = error as? URLError else { return nil }
        switch urlError.code {
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .serverCertificateUntrusted, .clientCertificateRejected, .clientCertificateRequired:
            return "TLS 握手失败（证书不被当前设备信任）。请检查系统时间、VPN/代理抓包证书，或先在同设备 Safari 打开 https://api.bilibili.com 验证证书链。"
        default:
            return nil
        }
    }

    private func isUnauthorized(_ error: Error) -> Bool {
        if let bili = error as? BiliError {
            if case .unauthorized = bili {
                return true
            }
            if case let .apiError(code, _) = bili, code == -101 {
                return true
            }
        }
        return false
    }
}

struct BiliEnvelope<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? -1
        data = try container.decodeIfPresent(T.self, forKey: .data)
        message =
            (try? container.decode(String.self, forKey: .message)) ??
            (try? container.decode(String.self, forKey: .msg)) ??
            "unknown"
    }
}
