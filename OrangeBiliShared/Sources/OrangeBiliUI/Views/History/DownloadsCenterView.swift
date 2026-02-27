import SwiftUI
import OrangeBiliCore

struct DownloadsCenterView: View {
    @EnvironmentObject private var downloadManager: OfflineDownloadManager
    @EnvironmentObject private var render: RenderSettings

    @State private var selectedTab: DownloadsTab = .completed
    @State private var didLoadInitialTab = false

    var body: some View {
        VStack(spacing: 0) {
            tabSelector
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)

            List {
                if filteredItems.isEmpty {
                    EmptyStateView(emptyText, systemImage: emptyIcon)
                } else {
                    ForEach(filteredItems) { item in
                        row(for: item)
                            .listRowInsets(UIStyle.listRowInsets)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(L10n.t("downloads.center.title"))
        .onAppear {
            guard !didLoadInitialTab else { return }
            selectedTab = render.downloadsDefaultTab
            didLoadInitialTab = true
        }
        .onChange(of: selectedTab) { newValue in
            render.downloadsDefaultTab = newValue
        }
    }

    @ViewBuilder
    private var tabSelector: some View {
#if os(watchOS)
        HStack(spacing: 6) {
            tabButton(title: L10n.t("downloads.tab.completed"), tab: .completed)
            tabButton(title: L10n.t("downloads.tab.active"), tab: .active)
            tabButton(title: L10n.t("downloads.tab.issues"), tab: .issues)
        }
#else
        Picker(L10n.t("downloads.center.title"), selection: $selectedTab) {
            Text(L10n.t("downloads.tab.completed")).tag(DownloadsTab.completed)
            Text(L10n.t("downloads.tab.active")).tag(DownloadsTab.active)
            Text(L10n.t("downloads.tab.issues")).tag(DownloadsTab.issues)
        }
        .pickerStyle(.segmented)
#endif
    }

#if os(watchOS)
    private func tabButton(title: String, tab: DownloadsTab) -> some View {
        Button(title) {
            selectedTab = tab
        }
        .buttonStyle(.plain)
        .font(.system(size: UIStyle.fontSize(8.5), weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            (selectedTab == tab ? Theme.accent.opacity(0.28) : Theme.cardBackground),
            in: Capsule()
        )
    }
#endif

    @ViewBuilder
    private func row(for item: DownloadStatusItem) -> some View {
        switch selectedTab {
        case .completed:
            NavigationLink {
                OfflineVideoManageView(itemID: item.id)
            } label: {
                DownloadItemCard(item: item, mode: .completed)
            }
            .buttonStyle(.plain)
            #if !os(tvOS)
            .swipeActions {
                Button(role: .destructive) {
                    downloadManager.remove(itemID: item.id)
                } label: {
                    Label(L10n.t("action.delete"), systemImage: "trash")
                }
            }
            #endif
        case .active:
            DownloadItemCard(item: item, mode: .active)
                #if !os(tvOS)
                .swipeActions {
                    if item.state == .downloading || item.state == .queued {
                        Button(L10n.t("action.cancel"), role: .destructive) {
                            downloadManager.cancel(itemID: item.id)
                        }
                    }
                    Button(role: .destructive) {
                        downloadManager.remove(itemID: item.id)
                    } label: {
                        Label(L10n.t("action.delete"), systemImage: "trash")
                    }
                }
                #endif
        case .issues:
            DownloadItemCard(item: item, mode: .issues)
                #if !os(tvOS)
                .swipeActions {
                    Button(L10n.t("downloads.issue.retry")) {
                        downloadManager.retry(itemID: item.id)
                    }
                    .tint(.blue)
                    Button(role: .destructive) {
                        downloadManager.remove(itemID: item.id)
                    } label: {
                        Label(L10n.t("action.delete"), systemImage: "trash")
                    }
                }
                #endif
        }
    }

    private var filteredItems: [DownloadStatusItem] {
        switch selectedTab {
        case .completed:
            return downloadManager.items.filter { $0.state == .completed && $0.localFileURL != nil }
        case .active:
            return downloadManager.items.filter { $0.state == .queued || $0.state == .downloading }
        case .issues:
            return downloadManager.items.filter { $0.state == .failed || $0.state == .canceled }
        }
    }

    private var emptyText: String {
        switch selectedTab {
        case .completed:
            return L10n.t("downloads.completed.empty")
        case .active:
            return L10n.t("downloads.active.empty")
        case .issues:
            return L10n.t("downloads.issues.empty")
        }
    }

    private var emptyIcon: String {
        switch selectedTab {
        case .completed: return "checkmark.circle"
        case .active: return "arrow.down.circle"
        case .issues: return "exclamationmark.triangle"
        }
    }
}

private struct DownloadItemCard: View {
    enum Mode {
        case completed
        case active
        case issues
    }

    let item: DownloadStatusItem
    let mode: Mode

    var body: some View {
        HStack(spacing: 8) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: UIStyle.fontSize(11), weight: .semibold))
                    .lineLimit(2)

                Text(item.bvid)
                    .font(.system(size: UIStyle.fontSize(8.5), design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if mode == .active {
                    ProgressView(value: item.progress)
                        .tint(.accentColor)
                    Text(progressMeta)
                        .font(.system(size: UIStyle.fontSize(8)))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if mode == .issues, let error = item.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.system(size: UIStyle.fontSize(8)))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                statusChip
                if mode == .completed {
                    Image(systemName: "chevron.right")
                        .font(.system(size: UIStyle.fontSize(8), weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(UIStyle.cardPadding)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if mode == .completed || item.localCoverURL != nil || item.coverURL != nil {
            AsyncCachedImage(url: item.localCoverURL ?? item.coverURL) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.gray.opacity(0.24))
            }
            .frame(width: 60, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var progressMeta: String {
        let percent = Int(item.progress * 100)
        let speed = formatBytes(Int(item.speedBytesPerSec))
        let received = formatBytes(Int(item.receivedBytes))
        let total = item.totalBytes > 0 ? formatBytes(Int(item.totalBytes)) : "?"
        return "\(percent)% · \(received)/\(total) · \(speed)/s"
    }

    private var statusChip: some View {
        Text(stateText(item.state))
            .font(.system(size: UIStyle.fontSize(8), weight: .semibold))
            .foregroundStyle(chipColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chipColor.opacity(0.14), in: Capsule())
    }

    private var chipColor: Color {
        switch item.state {
        case .queued: return .orange
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .canceled: return .secondary
        }
    }

    private func stateText(_ state: DownloadStatusItem.State) -> String {
        switch state {
        case .queued: return L10n.t("downloads.state.queued")
        case .downloading: return L10n.t("downloads.state.downloading")
        case .completed: return L10n.t("downloads.state.completed")
        case .failed: return L10n.t("downloads.state.failed")
        case .canceled: return L10n.t("downloads.state.canceled")
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        if bytes >= 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) B"
    }
}
