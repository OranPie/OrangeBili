import Foundation

public struct BiliLoginSession: Codable, Sendable {
    public let sessdata: String
    public let biliJct: String?
    public let dedeUserID: String?
    public let buvid3: String?
    public let buvid4: String?

    public var isValid: Bool {
        !sessdata.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(sessdata: String, biliJct: String?, dedeUserID: String?, buvid3: String?, buvid4: String?) {
        self.sessdata = sessdata
        self.biliJct = biliJct
        self.dedeUserID = dedeUserID
        self.buvid3 = buvid3
        self.buvid4 = buvid4
    }
}

public actor BiliAuthStore {
    public static let shared = BiliAuthStore()

    private let defaultsKey = "orangebili.login.session"
    private var session: BiliLoginSession?

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            session = try? JSONDecoder().decode(BiliLoginSession.self, from: data)
        }
        DebugLogStore.shared.log(category: "auth", message: "session loaded loggedIn=\(session?.isValid == true)")
    }

    public func update(session: BiliLoginSession?) {
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

    public func isLoggedIn() -> Bool {
        session?.isValid == true
    }

    public func loggedInMid() -> Int? {
        guard let raw = session?.dedeUserID?.nonEmpty else { return nil }
        return raw.boundedIntValue
    }

    public func currentSession() -> BiliLoginSession? {
        session
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

    var boundedIntValue: Int? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let parsed = Int(trimmed) {
            return parsed
        }
        if let parsed64 = Int64(trimmed),
           let exact = Int(exactly: parsed64) {
            return exact
        }
        return nil
    }
}
