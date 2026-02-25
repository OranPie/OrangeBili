import Foundation
import OrangeBiliCore

@MainActor
final class WatchHistorySyncer: HistorySyncer {
    override func syncHistory(records: [HistoryRecord]) async {
        await CompanionBridge.shared.syncHistory(records: records)
    }
}
