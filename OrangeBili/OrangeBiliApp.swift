import SwiftUI

@main
struct OrangeBiliApp: App {
    @StateObject private var connectivity = CompanionConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
    }
}
