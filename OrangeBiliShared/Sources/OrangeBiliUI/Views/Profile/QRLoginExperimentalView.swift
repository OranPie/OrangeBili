import SwiftUI
import OrangeBiliCore

struct QRLoginExperimentalView: View {
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var loginMode: LoginMode = .password
    @State private var qrcodeKey = ""
    @State private var qrcodeImageURL: URL?
    @State private var statusText = L10n.t("login.qr.hint")
    @State private var isLoading = false
    @State private var pollTask: Task<Void, Never>?

    @State private var username = ""
    @State private var password = ""
    @State private var token = ""
    @State private var challenge = ""
    @State private var validate = ""
    @State private var seccode = ""

    @State private var smsCid = "86"
    @State private var smsTel = ""
    @State private var smsCode = ""
    @State private var smsCaptchaKey = ""

    private let qrService = BiliQRLoginService()
    private let credentialService = BiliCredentialLoginService()

    private enum LoginMode: CaseIterable, Identifiable {
        case password
        case sms

        var id: String { label }

        var label: String {
            switch self {
            case .password: return L10n.t("login.mode.password")
            case .sms: return L10n.t("login.mode.sms")
            }
        }
    }

    var body: some View {
        List {
            Section(L10n.t("login.status")) {
                Text(apiBackend.isLoggedIn ? L10n.t("login.status.loggedIn") : L10n.t("login.status.loggedOut"))
                    .font(.caption2)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.t("login.qr.section")) {
                if let qrcodeImageURL {
                    HStack {
                        Spacer()
                        AsyncImage(url: qrcodeImageURL) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .renderingMode(.original)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                            case .failure:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.gray.opacity(0.16))
                                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            case .empty:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.gray.opacity(0.16))
                            @unknown default:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.gray.opacity(0.16))
                            }
                        }
                        .frame(width: 132, height: 132)
                        .padding(4)
                        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        Spacer()
                    }
                } else {
                    Text(L10n.t("login.qr.empty"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !qrcodeKey.isEmpty {
                    Text(L10n.f("login.qr.key", String(qrcodeKey.prefix(8))))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.t("login.actions")) {
                Button(isLoading ? L10n.t("action.processing") : L10n.t("login.qr.generate")) {
                    Task { await generateQRCode() }
                }
                .disabled(isLoading)

                Button(L10n.t("login.qr.stop")) {
                    stopPolling(status: L10n.t("login.qr.stopped"))
                }
                .disabled(pollTask == nil)

                Button(L10n.t("me.account.logout"), role: .destructive) {
                    Task {
                        await apiBackend.clearLoginSession()
                        statusText = L10n.t("login.status.cleared")
                    }
                }
            }

            Section(L10n.t("login.experimental.section")) {
                Picker(L10n.t("login.mode"), selection: $loginMode) {
                    ForEach(LoginMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.automatic)

                if loginMode == .password {
                    TextField(L10n.t("login.username"), text: $username)
                    TextField(L10n.t("login.password"), text: $password)
                    TextField(L10n.t("login.token"), text: $token)
                    TextField(L10n.t("login.challenge"), text: $challenge)
                    TextField(L10n.t("login.validate"), text: $validate)
                    TextField(L10n.t("login.seccode"), text: $seccode)

                    Button(isLoading ? L10n.t("action.processing") : L10n.t("login.password.action")) {
                        Task { await loginWithPassword() }
                    }
                    .disabled(isLoading)
                } else {
                    TextField(L10n.t("login.sms.cid"), text: $smsCid)
                    TextField(L10n.t("login.sms.tel"), text: $smsTel)
                    TextField(L10n.t("login.sms.code"), text: $smsCode)
                    TextField(L10n.t("login.sms.captcha"), text: $smsCaptchaKey)

                    Button(isLoading ? L10n.t("action.processing") : L10n.t("login.sms.action")) {
                        Task { await loginWithSMS() }
                    }
                    .disabled(isLoading)
                }

                Text(L10n.t("login.experimental.hint"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("login.qr.title"))
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private func generateQRCode() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await qrService.generate()
            qrcodeKey = result.qrcodeKey
            qrcodeImageURL = makeQRCodeURL(from: result.url)
            statusText = L10n.t("login.qr.scan")
            DebugLogStore.shared.log(category: "login", message: "qrcode generated")
            startPolling()
        } catch {
            statusText = L10n.f("login.qr.generate.fail", error.localizedDescription)
            DebugLogStore.shared.log(category: "login", message: "qrcode generate fail: \(error.localizedDescription)")
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        guard !qrcodeKey.isEmpty else { return }

        pollTask = Task {
            while !Task.isCancelled {
                do {
                    let result = try await qrService.poll(qrcodeKey: qrcodeKey)
                    switch result {
                    case .waiting:
                        statusText = L10n.t("login.qr.waiting")
                    case .scanned:
                        statusText = L10n.t("login.qr.scanned")
                    case .expired:
                        stopPolling(status: L10n.t("login.qr.expired"))
                        DebugLogStore.shared.log(category: "login", message: "qrcode expired")
                        return
                    case let .success(session):
                        await apiBackend.updateLoginSession(
                            sessdata: session.sessdata,
                            biliJct: session.biliJct,
                            dedeUserID: session.dedeUserID,
                            buvid3: session.buvid3,
                            buvid4: session.buvid4
                        )
                        stopPolling(status: L10n.t("login.qr.success"))
                        DebugLogStore.shared.log(category: "login", message: "qrcode login success")
                        return
                    }
                } catch {
                    stopPolling(status: L10n.f("login.qr.poll.fail", error.localizedDescription))
                    DebugLogStore.shared.log(category: "login", message: "qrcode poll fail: \(error.localizedDescription)")
                    return
                }

                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func stopPolling(status: String) {
        pollTask?.cancel()
        pollTask = nil
        statusText = status
    }

    private func loginWithPassword() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await credentialService.loginByPassword(
                .init(
                    username: username,
                    password: password,
                    token: token,
                    challenge: challenge,
                    validate: validate,
                    seccode: seccode
                )
            )
            await apiBackend.updateLoginSession(
                sessdata: session.sessdata,
                biliJct: session.biliJct,
                dedeUserID: session.dedeUserID,
                buvid3: session.buvid3,
                buvid4: session.buvid4
            )
            statusText = L10n.t("login.password.success")
            DebugLogStore.shared.log(category: "login", message: "password login success")
        } catch {
            statusText = L10n.f("login.password.fail", error.localizedDescription)
            DebugLogStore.shared.log(category: "login", message: "password login fail: \(error.localizedDescription)")
        }
    }

    private func loginWithSMS() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await credentialService.loginBySMS(
                .init(
                    cid: smsCid,
                    tel: smsTel,
                    code: smsCode,
                    source: "main_web",
                    captchaKey: smsCaptchaKey
                )
            )
            await apiBackend.updateLoginSession(
                sessdata: session.sessdata,
                biliJct: session.biliJct,
                dedeUserID: session.dedeUserID,
                buvid3: session.buvid3,
                buvid4: session.buvid4
            )
            statusText = L10n.t("login.sms.success")
            DebugLogStore.shared.log(category: "login", message: "sms login success")
        } catch {
            statusText = L10n.f("login.sms.fail", error.localizedDescription)
            DebugLogStore.shared.log(category: "login", message: "sms login fail: \(error.localizedDescription)")
        }
    }

    private func makeQRCodeURL(from value: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=\(encoded)")
    }
}
