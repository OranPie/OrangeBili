import Foundation
import OrangeBiliCore
import WatchConnectivity

final class CompanionConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var lastCommand: String = "-"

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let historyStore: HistoryStore
    private let favoritesStore: FavoritesStore
    private let apiBackend: BiliAPIBackend

    private enum Command {
        static let requestAuthState = "requestAuthState"
        static let syncHistory = "syncHistory"
        static let syncFavorites = "syncFavorites"
        static let syncAccount = "syncAccount"
    }

    init(historyStore: HistoryStore, favoritesStore: FavoritesStore, apiBackend: BiliAPIBackend) {
        self.historyStore = historyStore
        self.favoritesStore = favoritesStore
        self.apiBackend = apiBackend
        super.init()
        session?.delegate = self
        session?.activate()
    }

    private func handle(command: String, payload: Any?, hasPayload: Bool?) -> [String: Any] {
        lastCommand = command

        switch command {
        case Command.syncHistory:
            if let data = payload as? Data,
               let records = try? JSONDecoder().decode([HistoryRecord].self, from: data) {
                historyStore.merge(records: records)
                return ["ok": true, "count": records.count]
            }
            return ["ok": false, "count": 0]
        case Command.syncFavorites:
            if let data = payload as? Data,
               let records = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
                favoritesStore.merge(records: records)
                return ["ok": true, "count": records.count]
            }
            return ["ok": false, "count": 0]
        case Command.syncAccount:
            let hasPayload = hasPayload == true
            Task {
                if hasPayload, let data = payload as? Data,
                   let session = try? JSONDecoder().decode(BiliLoginSession.self, from: data) {
                    await BiliAuthStore.shared.update(session: session)
                } else {
                    await BiliAuthStore.shared.update(session: nil)
                }
                await apiBackend.refreshAuthState()
            }
            return ["ok": true]
        default:
            return ["ok": false]
        }
    }

    private func handleAuthStateRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        Task {
            let isLoggedIn = await BiliAuthStore.shared.isLoggedIn()
            replyHandler([
                "isLoggedIn": isLoggedIn,
                "username": NSNull()
            ])
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
        let hasPayload = message["hasPayload"] as? Bool

        if command == Command.requestAuthState {
            handleAuthStateRequest(replyHandler: replyHandler)
        } else {
            let response = handle(command: command, payload: payload, hasPayload: hasPayload)
            replyHandler(response)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let command = applicationContext["command"] as? String ?? "unknown"
        let hasPayload = applicationContext["hasPayload"] as? Bool
        _ = handle(command: command, payload: applicationContext["payload"], hasPayload: hasPayload)
    }
}
