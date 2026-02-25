import Foundation
import Combine

@MainActor
open class HistorySyncer: ObservableObject {
    public init() {}

    open func syncHistory(records: [HistoryRecord]) async {
        // default no-op
    }
}
