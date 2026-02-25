import Foundation
import OrangeBiliCore
import WatchConnectivity

protocol CompanionBridgeProtocol {
    func requestAuthState() async -> CompanionAuthState
    func syncHistory(records: [HistoryRecord]) async
    func syncFavorites(records: [FavoriteRecord]) async
    func syncAccount(session: BiliLoginSession?) async
}

final class CompanionBridge: NSObject, CompanionBridgeProtocol {
    static let shared = CompanionBridge()

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var activationState: WCSessionActivationState = .notActivated
    private var pendingApplicationContext: [String: Any]?

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func requestAuthState() async -> CompanionAuthState {
        guard let session,
              activationState == .activated,
              session.isReachable else {
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
        guard session != nil else { return }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(records) else { return }
        sendOrQueue(message: ["command": "syncHistory", "payload": data])
    }

    func syncFavorites(records: [FavoriteRecord]) async {
        guard session != nil else { return }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(records) else { return }
        sendOrQueue(message: ["command": "syncFavorites", "payload": data])
    }

    func syncAccount(session loginSession: BiliLoginSession?) async {
        guard session != nil else { return }
        let encoder = JSONEncoder()
        let data = try? encoder.encode(loginSession)
        let message: [String: Any] = [
            "command": "syncAccount",
            "payload": data ?? Data(),
            "hasPayload": loginSession != nil
        ]
        sendOrQueue(message: message)
    }

    private func sendOrQueue(message: [String: Any]) {
        guard let session else { return }

        // Avoid WCSessionNotActivated spam at startup; send once activation completes.
        guard activationState == .activated else {
            pendingApplicationContext = message
            return
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                DebugLogStore.shared.log(category: "companion", message: "updateApplicationContext fail: \(error.localizedDescription)")
            }
        }
    }
}

extension CompanionBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.activationState = activationState
        if let error {
            DebugLogStore.shared.log(category: "companion", message: "activation fail: \(error.localizedDescription)")
            return
        }
        guard activationState == .activated,
              let pendingApplicationContext else { return }
        do {
            try session.updateApplicationContext(pendingApplicationContext)
            self.pendingApplicationContext = nil
        } catch {
            DebugLogStore.shared.log(category: "companion", message: "flush context fail: \(error.localizedDescription)")
        }
    }
}
