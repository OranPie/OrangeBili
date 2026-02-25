import Foundation

public enum BiliError: LocalizedError {
    case invalidURL
    case apiError(code: Int, message: String)
    case badResponse
    case httpStatus(Int)
    case noStream
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.t("error.invalidUrl")
        case let .apiError(code, message):
            return L10n.f("error.api", code, message)
        case .badResponse:
            return L10n.t("error.badResponse")
        case let .httpStatus(statusCode):
            return L10n.f("error.http", statusCode)
        case .noStream:
            return L10n.t("error.noStream")
        case .unauthorized:
            return L10n.t("error.unauthorized")
        }
    }
}
