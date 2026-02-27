import SwiftUI
import OrangeBiliCore

public struct ToastOverlayView: View {
    @EnvironmentObject private var toastManager: ToastManager

    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            ForEach(toastManager.activeToasts) { toast in
                toastRow(toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.25), value: toastManager.activeToasts.map(\.id))
        .allowsHitTesting(false)
    }

    private func toastRow(_ toast: ToastItem) -> some View {
        HStack(spacing: 6) {
            if let icon = toast.icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tintColor(for: toast.style))
            }
            Text(toast.message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.78), in: Capsule())
    }

    private func tintColor(for style: ToastStyle) -> Color {
        switch style {
        case .success: return .green
        case .error: return .red
        case .info: return .white
        case .warning: return .yellow
        }
    }
}
