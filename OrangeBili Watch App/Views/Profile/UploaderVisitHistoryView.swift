import SwiftUI

struct UploaderVisitHistoryView: View {
    @EnvironmentObject private var store: UploaderVisitStore

    var body: some View {
        List {
            if store.records.isEmpty {
                Text("暂无主页浏览历史")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.records) { record in
                    NavigationLink {
                        UploaderView(mid: record.id)
                    } label: {
                        HStack(spacing: 8) {
                            AsyncCachedImage(url: record.avatarURL) {
                                Circle().fill(.gray.opacity(0.24))
                            }
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.name)
                                    .font(.caption2)
                                Text("UID \(record.id)")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(Formatting.time(record.visitedAt))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.delete(id: record.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }

            if !store.records.isEmpty {
                Button("清空主页历史", role: .destructive) {
                    store.clear()
                }
            }
        }
        .navigationTitle("主页浏览历史")
    }
}
