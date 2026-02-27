import SwiftUI
import OrangeBiliCore

struct QRLoginExperimentalView: View {
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    @State private var qrcodeKey = ""
    @State private var qrcodeImageURL: URL?
    @State private var isLoading = false
    @State private var pollTask: Task<Void, Never>?

    private let qrService = BiliQRLoginService()

    var body: some View {
        List {
            Section(L10n.t("login.status")) {
                Text(apiBackend.isLoggedIn ? L10n.t("login.status.loggedIn") : L10n.t("login.status.loggedOut"))
                    .font(.caption2)
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
                    stopPolling()
                    ToastManager.shared.show(L10n.t("login.qr.stopped"), icon: "stop.circle", style: .info)
                }
                .disabled(pollTask == nil)

                Button(L10n.t("me.account.logout"), role: .destructive) {
                    Task {
                        await apiBackend.clearLoginSession()
                        ToastManager.shared.show(L10n.t("login.status.cleared"), icon: "person.slash", style: .info)
                    }
                }
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
            ToastManager.shared.show(L10n.t("login.qr.scan"), icon: "qrcode", style: .info)
            DebugLogStore.shared.log(category: "login", message: "qrcode generated")
            startPolling()
        } catch {
            ToastManager.shared.show(L10n.f("login.qr.generate.fail", error.localizedDescription), icon: "xmark.circle", style: .error)
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
                        break
                    case .scanned:
                        ToastManager.shared.show(L10n.t("login.qr.scanned"), icon: "iphone.and.arrow.forward", style: .info)
                    case .expired:
                        stopPolling()
                        ToastManager.shared.show(L10n.t("login.qr.expired"), icon: "clock.badge.exclamationmark", style: .warning)
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
                        stopPolling()
                        ToastManager.shared.show(L10n.t("login.qr.success"), icon: "checkmark.circle", style: .success)
                        DebugLogStore.shared.log(category: "login", message: "qrcode login success")
                        return
                    }
                } catch {
                    stopPolling()
                    ToastManager.shared.show(L10n.f("login.qr.poll.fail", error.localizedDescription), icon: "xmark.circle", style: .error)
                    DebugLogStore.shared.log(category: "login", message: "qrcode poll fail: \(error.localizedDescription)")
                    return
                }

                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func makeQRCodeURL(from value: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=\(encoded)")
    }
}
