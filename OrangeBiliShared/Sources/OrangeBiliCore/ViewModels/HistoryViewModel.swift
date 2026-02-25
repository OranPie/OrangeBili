import Foundation
import Combine

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public private(set) var records: [HistoryRecord] = []

    private let store: HistoryStore

    public init(store: HistoryStore) {
        self.store = store
        self.records = store.records
    }

    public func refresh() {
        records = store.records
    }

    public func clear() {
        store.clear()
        refresh()
    }

    public func delete(id: String) {
        store.delete(id: id)
        refresh()
    }
}
