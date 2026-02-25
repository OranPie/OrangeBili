import SwiftUI

@MainActor
final class TabBarState: ObservableObject {
    @Published var isCollapsed = false

    private var lastOffset: CGFloat = 0
    private var lastUpdate = Date()

    func update(offset: CGFloat) {
        let now = Date()
        if now.timeIntervalSince(lastUpdate) < 0.12 {
            return
        }
        let delta = offset - lastOffset
        if abs(delta) < 8 {
            return
        }
        if delta < 0 {
            isCollapsed = true
        } else if delta > 0 {
            isCollapsed = false
        }
        lastOffset = offset
        lastUpdate = now
    }

    func toggle() {
        isCollapsed.toggle()
    }
}
