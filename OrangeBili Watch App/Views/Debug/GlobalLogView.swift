import SwiftUI

struct GlobalLogView: View {
    @EnvironmentObject private var debugLogStore: DebugLogStore

    var body: some View {
        List {
            if debugLogStore.entries.isEmpty {
                Text("暂无日志")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(debugLogStore.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("[\(entry.category)] \(entry.message)")
                            .font(.system(size: 8, design: .monospaced))
                            .lineLimit(6)
                        Text(Formatting.time(entry.timestamp))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("清空全部日志", role: .destructive) {
                    debugLogStore.clear()
                }
            }
        }
        .navigationTitle("全局日志")
    }
}
