import Foundation
import WatchConnectivity

final class CompanionConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var lastCommand: String = "-"

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    private func handle(command: String, payload: Any?) -> [String: Any] {
        lastCommand = command

        switch command {
        case "requestAuthState":
            return [
                "isLoggedIn": false,
                "username": NSNull()
            ]
        case "syncHistory":
            return ["ok": true, "count": (payload as? Data).map { _ in 1 } ?? 0]
        default:
            return ["ok": false]
        }
    }
}

extension CompanionConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let command = message["command"] as? String ?? "unknown"
        let payload = message["payload"]
        let response = handle(command: command, payload: payload)
        replyHandler(response)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let command = applicationContext["command"] as? String ?? "unknown"
        _ = handle(command: command, payload: applicationContext["payload"])
    }
}
