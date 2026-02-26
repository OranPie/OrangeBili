import SwiftUI
import OrangeBiliCore

struct GlobalLogView: View {
    @EnvironmentObject private var debugLogStore: DebugLogStore

    var body: some View {
        List {
            if debugLogStore.entries.isEmpty {
                EmptyStateView(L10n.t("logs.empty"), systemImage: "doc.text")
            } else {
                ForEach(debugLogStore.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        #if os(tvOS)
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text("[\(entry.category)] \(entry.message)")
                                .font(.system(size: 18, design: .monospaced))
                                .lineLimit(20)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(Formatting.time(entry.timestamp))
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        #else
                        Text("[\(entry.category)] \(entry.message)")
                            .font(.system(size: 8, design: .monospaced))
                            .lineLimit(6)
                        Text(Formatting.time(entry.timestamp))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        #endif
                    }
                }
            }

            Section {
                Button(L10n.t("logs.clear"), role: .destructive) {
                    debugLogStore.clear()
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("logs.title"))
    }
}
