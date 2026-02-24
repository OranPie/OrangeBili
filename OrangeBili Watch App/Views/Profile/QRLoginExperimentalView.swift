import SwiftUI

struct QRLoginExperimentalView: View {
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var loginMode: LoginMode = .password
    @State private var qrcodeKey = ""
    @State private var qrcodeImageURL: URL?
    @State private var statusText = "点击“生成二维码”开始登录"
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

    private enum LoginMode: String, CaseIterable, Identifiable {
        case password = "账号"
        case sms = "短信"

        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section("状态") {
                Text(apiBackend.isLoggedIn ? "当前已登录" : "当前未登录")
                    .font(.caption2)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("二维码") {
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
                    Text("暂无二维码")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !qrcodeKey.isEmpty {
                    Text("key: \(qrcodeKey.prefix(8))...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section("操作") {
                Button(isLoading ? "处理中..." : "生成二维码") {
                    Task { await generateQRCode() }
                }
                .disabled(isLoading)

                Button("停止轮询") {
                    stopPolling(status: "已停止轮询")
                }
                .disabled(pollTask == nil)

                Button("退出登录", role: .destructive) {
                    Task {
                        await apiBackend.clearLoginSession()
                        statusText = "已清除登录状态"
                    }
                }
            }

            Section("帐密/短信登录(实验)") {
                Picker("模式", selection: $loginMode) {
                    ForEach(LoginMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.automatic)

                if loginMode == .password {
                    TextField("用户名", text: $username)
                    TextField("密码(通常需RSA后值)", text: $password)
                    TextField("token(极验)", text: $token)
                    TextField("challenge", text: $challenge)
                    TextField("validate", text: $validate)
                    TextField("seccode", text: $seccode)

                    Button(isLoading ? "处理中..." : "尝试账号登录") {
                        Task { await loginWithPassword() }
                    }
                    .disabled(isLoading)
                } else {
                    TextField("国家码", text: $smsCid)
                    TextField("手机号", text: $smsTel)
                    TextField("短信验证码", text: $smsCode)
                    TextField("captcha_key", text: $smsCaptchaKey)

                    Button(isLoading ? "处理中..." : "尝试短信登录") {
                        Task { await loginWithSMS() }
                    }
                    .disabled(isLoading)
                }

                Text("提示：Web 帐密/短信登录通常还要求完整风控参数，本页为实验透传。")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Watch 扫码登录")
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
            statusText = "请使用手机哔哩哔哩扫码"
            DebugLogStore.shared.log(category: "login", message: "qrcode generated")
            startPolling()
        } catch {
            statusText = "生成失败：\(error.localizedDescription)"
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
                        statusText = "等待扫码..."
                    case .scanned:
                        statusText = "已扫码，请在手机确认"
                    case .expired:
                        stopPolling(status: "二维码已过期，请重新生成")
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
                        stopPolling(status: "登录成功")
                        DebugLogStore.shared.log(category: "login", message: "qrcode login success")
                        return
                    }
                } catch {
                    stopPolling(status: "轮询失败：\(error.localizedDescription)")
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
            statusText = "账号登录成功"
            DebugLogStore.shared.log(category: "login", message: "password login success")
        } catch {
            statusText = "账号登录失败：\(error.localizedDescription)"
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
            statusText = "短信登录成功"
            DebugLogStore.shared.log(category: "login", message: "sms login success")
        } catch {
            statusText = "短信登录失败：\(error.localizedDescription)"
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
