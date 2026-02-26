import Foundation

@MainActor
public final class SearchHistoryStore: ObservableObject {
    @Published public private(set) var recentSearches: [String] = []

    private let key = "OrangeBili.searchHistory"
    private let maxCount = 20

    public init() {
        recentSearches = (UserDefaults.standard.stringArray(forKey: key)) ?? []
    }

    public func add(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxCount {
            recentSearches = Array(recentSearches.prefix(maxCount))
        }
        save()
    }

    public func remove(_ keyword: String) {
        recentSearches.removeAll { $0 == keyword }
        save()
    }

    public func clear() {
        recentSearches = []
        save()
    }

    private func save() {
        UserDefaults.standard.set(recentSearches, forKey: key)
    }
}
