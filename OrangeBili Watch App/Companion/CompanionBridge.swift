import Foundation
import OrangeBiliCore
import WatchConnectivity

protocol CompanionBridgeProtocol {
    func requestAuthState() async -> CompanionAuthState
    func syncHistory(records: [HistoryRecord]) async
}

final class CompanionBridge: NSObject, CompanionBridgeProtocol {
    static let shared = CompanionBridge()

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func requestAuthState() async -> CompanionAuthState {
        guard let session, session.isReachable else {
            return CompanionAuthState(isLoggedIn: false, username: nil)
        }

        return await withCheckedContinuation { continuation in
            session.sendMessage(["command": "requestAuthState"], replyHandler: { payload in
                let state = CompanionAuthState(
                    isLoggedIn: payload["isLoggedIn"] as? Bool ?? false,
                    username: payload["username"] as? String
                )
                continuation.resume(returning: state)
            }, errorHandler: { _ in
                continuation.resume(returning: CompanionAuthState(isLoggedIn: false, username: nil))
            })
        }
    }

    func syncHistory(records: [HistoryRecord]) async {
        guard let session else { return }
        let encoder = JSONEncoder()
        let data = try? encoder.encode(records)
        let message: [String: Any] = ["command": "syncHistory", "payload": data ?? Data()]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            try? session.updateApplicationContext(message)
        }
    }
}

extension CompanionBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
