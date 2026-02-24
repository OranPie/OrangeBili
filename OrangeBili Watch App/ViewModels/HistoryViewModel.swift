import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []

    private let store: HistoryStore

    init(store: HistoryStore) {
        self.store = store
        self.records = store.records
    }

    func refresh() {
        records = store.records
    }

    func clear() {
        store.clear()
        refresh()
    }

    func delete(id: String) {
        store.delete(id: id)
        refresh()
    }
}
