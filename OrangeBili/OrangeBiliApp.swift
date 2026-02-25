import SwiftUI
import OrangeBiliCore
import OrangeBiliUI

@main
struct OrangeBiliApp: App {
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var renderSettings = RenderSettings()
    @StateObject private var favoritesStore = FavoritesStore()
    @StateObject private var uploaderVisitStore = UploaderVisitStore()
    @StateObject private var downloadManager = OfflineDownloadManager.shared
    @StateObject private var debugLogStore = DebugLogStore.shared
    @StateObject private var apiBackend = BiliAPIBackend.shared
    @StateObject private var historySyncer = HistorySyncer()

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
        }
    }
}
