import Foundation

enum BiliError: LocalizedError {
    case invalidURL
    case apiError(code: Int, message: String)
    case badResponse
    case httpStatus(Int)
    case noStream
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case let .apiError(code, message):
            return "接口错误(\(code)): \(message)"
        case .badResponse:
            return "服务响应异常"
        case let .httpStatus(statusCode):
            return "服务返回 HTTP \(statusCode)"
        case .noStream:
            return "未找到可播放视频流"
        case .unauthorized:
            return "当前请求需要登录"
        }
    }
}
