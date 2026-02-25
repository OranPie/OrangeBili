import SwiftUI

struct UploaderVisitHistoryView: View {
    @EnvironmentObject private var store: UploaderVisitStore

    var body: some View {
        List {
            if store.records.isEmpty {
                EmptyStateView(L10n.t("uploader.visit.empty"), systemImage: "clock")
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
                                Text(L10n.f("label.uid", record.id))
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
                            Label(L10n.t("action.delete"), systemImage: "trash")
                        }
                    }
                }
            }

            if !store.records.isEmpty {
                Button(L10n.t("uploader.visit.clear"), role: .destructive) {
                    store.clear()
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("uploader.visit.title"))
    }
}
