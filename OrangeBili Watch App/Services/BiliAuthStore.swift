import Foundation

struct BiliLoginSession: Codable, Sendable {
    let sessdata: String
    let biliJct: String?
    let dedeUserID: String?
    let buvid3: String?
    let buvid4: String?

    var isValid: Bool {
        !sessdata.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

actor BiliAuthStore {
    static let shared = BiliAuthStore()

    private let defaultsKey = "orangebili.login.session"
    private var session: BiliLoginSession?

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            session = try? JSONDecoder().decode(BiliLoginSession.self, from: data)
        }
        DebugLogStore.shared.log(category: "auth", message: "session loaded loggedIn=\(session?.isValid == true)")
    }

    func update(session: BiliLoginSession?) {
        self.session = session?.isValid == true ? session : nil

        let defaults = UserDefaults.standard
        if let stored = self.session, let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: defaultsKey)
            DebugLogStore.shared.log(category: "auth", message: "session updated loggedIn=true")
        } else {
            defaults.removeObject(forKey: defaultsKey)
            DebugLogStore.shared.log(category: "auth", message: "session cleared loggedIn=false")
        }
    }

    func isLoggedIn() -> Bool {
        session?.isValid == true
    }

    func loggedInMid() -> Int? {
        guard let raw = session?.dedeUserID?.nonEmpty else { return nil }
        return Int(raw)
    }

    func cookieHeader(for endpoint: BiliEndpoint) -> String? {
        var items: [String] = []

        if endpoint.requiresBuvidCookie {
            let buvid = session?.buvid3?.nonEmpty ?? DeviceIdentity.shared.buvid3
            items.append("buvid3=\(buvid)")
            if let buvid4 = session?.buvid4?.nonEmpty {
                items.append("buvid4=\(buvid4)")
            }
        }

        if endpoint.authPolicy != .none,
           let session,
           session.isValid {
            items.append("SESSDATA=\(session.sessdata)")
            if let biliJct = session.biliJct?.nonEmpty {
                items.append("bili_jct=\(biliJct)")
            }
            if let dedeUserID = session.dedeUserID?.nonEmpty {
                items.append("DedeUserID=\(dedeUserID)")
            }
        }

        return items.isEmpty ? nil : items.joined(separator: "; ")
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
