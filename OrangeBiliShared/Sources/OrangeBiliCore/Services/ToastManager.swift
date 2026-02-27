import Foundation
import Combine

public enum ToastStyle {
    case success
    case error
    case info
    case warning
}

public struct ToastItem: Identifiable {
    public let id: UUID
    public let message: String
    public let icon: String?
    public let style: ToastStyle
    public let duration: TimeInterval
    public let createdAt: Date
}

@MainActor
public final class ToastManager: ObservableObject {
    public static let shared = ToastManager()

    @Published public private(set) var activeToasts: [ToastItem] = []

    private var dismissTasks: [UUID: Task<Void, Never>] = [:]
    private let maxVisible = 3

    private init() {}

    public func show(
        _ message: String,
        icon: String? = nil,
        style: ToastStyle = .info,
        duration: TimeInterval = 2.0
    ) {
        let item = ToastItem(
            id: UUID(),
            message: message,
            icon: icon,
            style: style,
            duration: duration,
            createdAt: Date()
        )

        activeToasts.append(item)

        // Trim oldest when exceeding max
        while activeToasts.count > maxVisible {
            let removed = activeToasts.removeFirst()
            dismissTasks[removed.id]?.cancel()
            dismissTasks.removeValue(forKey: removed.id)
        }

        // Schedule auto-dismiss
        let id = item.id
        dismissTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss(id: id)
        }
    }

    public func dismiss(id: UUID) {
        activeToasts.removeAll { $0.id == id }
        dismissTasks[id]?.cancel()
        dismissTasks.removeValue(forKey: id)
    }
}
