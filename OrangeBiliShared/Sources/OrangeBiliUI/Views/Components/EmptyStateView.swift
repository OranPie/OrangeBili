import SwiftUI
import OrangeBiliCore

struct EmptyStateView: View {
    let text: String
    let systemImage: String?
    let retryAction: (() -> Void)?

    init(_ text: String, systemImage: String? = nil, retryAction: (() -> Void)? = nil) {
        self.text = text
        self.systemImage = systemImage
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
            if let retryAction {
                Button(L10n.t("action.retry")) {
                    retryAction()
                }
                .font(.caption2)
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .transition(.opacity)
    }
}
