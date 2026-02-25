import SwiftUI
import OrangeBiliCore
import OrangeBiliUI

@main
struct OrangeBili_Watch_AppApp: App {
    @StateObject private var historyStore: HistoryStore
    @StateObject private var renderSettings: RenderSettings
    @StateObject private var favoritesStore: FavoritesStore
    @StateObject private var uploaderVisitStore: UploaderVisitStore
    @StateObject private var downloadManager: OfflineDownloadManager
    @StateObject private var debugLogStore: DebugLogStore
    @StateObject private var apiBackend: BiliAPIBackend
    @StateObject private var historySyncer: WatchHistorySyncer
    @StateObject private var companionSyncer: WatchCompanionSyncer

    init() {
        let historyStore = HistoryStore()
        let renderSettings = RenderSettings()
        let favoritesStore = FavoritesStore()
        let uploaderVisitStore = UploaderVisitStore()
        let downloadManager = OfflineDownloadManager.shared
        let debugLogStore = DebugLogStore.shared
        let apiBackend = BiliAPIBackend.shared
        let historySyncer = WatchHistorySyncer()

        _historyStore = StateObject(wrappedValue: historyStore)
        _renderSettings = StateObject(wrappedValue: renderSettings)
        _favoritesStore = StateObject(wrappedValue: favoritesStore)
        _uploaderVisitStore = StateObject(wrappedValue: uploaderVisitStore)
        _downloadManager = StateObject(wrappedValue: downloadManager)
        _debugLogStore = StateObject(wrappedValue: debugLogStore)
        _apiBackend = StateObject(wrappedValue: apiBackend)
        _historySyncer = StateObject(wrappedValue: historySyncer)
        _companionSyncer = StateObject(wrappedValue: WatchCompanionSyncer(
            historyStore: historyStore,
            favoritesStore: favoritesStore,
            apiBackend: apiBackend
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(historyStore)
                .environmentObject(renderSettings)
                .environmentObject(favoritesStore)
                .environmentObject(uploaderVisitStore)
                .environmentObject(downloadManager)
                .environmentObject(debugLogStore)
                .environmentObject(apiBackend)
                .environmentObject(historySyncer)
                .environmentObject(companionSyncer)
        }
    }
}
