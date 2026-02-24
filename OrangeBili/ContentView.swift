import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectivity: CompanionConnectivityManager

    var body: some View {
        NavigationStack {
            List {
                Section("Companion Stub") {
                    Text("WatchConnectivity 已激活")
                    Text("Last command: \(connectivity.lastCommand)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("登录") {
                    Text("当前阶段：桩实现（未接入扫码登录）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("OrangeBili")
        }
    }
}
