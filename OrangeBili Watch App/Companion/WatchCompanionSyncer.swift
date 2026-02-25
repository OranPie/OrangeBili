import Combine
import Foundation
import OrangeBiliCore

@MainActor
final class WatchCompanionSyncer: ObservableObject {
    private var favoritesCancellable: AnyCancellable?
    private var historyCancellable: AnyCancellable?
    private var authCancellable: AnyCancellable?

    init(historyStore: HistoryStore, favoritesStore: FavoritesStore, apiBackend: BiliAPIBackend) {
        historyCancellable = historyStore.$records
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { records in
                Task {
                    await CompanionBridge.shared.syncHistory(records: records)
                }
            }

        favoritesCancellable = favoritesStore.$records
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { records in
                Task {
                    await CompanionBridge.shared.syncFavorites(records: records)
                }
            }

        authCancellable = apiBackend.$isLoggedIn
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in
                Task {
                    let session = await BiliAuthStore.shared.currentSession()
                    await CompanionBridge.shared.syncAccount(session: session)
                }
            }

        Task {
            await CompanionBridge.shared.syncHistory(records: historyStore.records)
            await CompanionBridge.shared.syncFavorites(records: favoritesStore.records)
            let session = await BiliAuthStore.shared.currentSession()
            await CompanionBridge.shared.syncAccount(session: session)
        }
    }
}
