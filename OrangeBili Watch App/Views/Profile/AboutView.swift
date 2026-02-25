import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section(L10n.t("about.appInfo")) {
                infoRow(L10n.t("about.appName"), "OrangeBili")
                infoRow(L10n.t("about.platform"), "watchOS")
                infoRow(L10n.t("about.version"), appVersionText)
                infoRow(L10n.t("about.build"), buildText)
            }

            Section {
                CompactDisclosure {
                    Text(L10n.t("about.features"))
                } content: {
                    bullet(L10n.t("about.features.1"))
                    bullet(L10n.t("about.features.2"))
                    bullet(L10n.t("about.features.3"))
                    bullet(L10n.t("about.features.4"))
                    bullet(L10n.t("about.features.5"))
                }

                CompactDisclosure {
                    Text(L10n.t("about.data"))
                } content: {
                    bullet(L10n.t("about.data.1"))
                    bullet(L10n.t("about.data.2"))
                    bullet(L10n.t("about.data.3"))
                }

                CompactDisclosure {
                    Text(L10n.t("about.troubleshoot"))
                } content: {
                    bullet(L10n.t("about.troubleshoot.1"))
                    bullet(L10n.t("about.troubleshoot.2"))
                    bullet(L10n.t("about.troubleshoot.3"))
                }

                CompactDisclosure {
                    Text(L10n.t("about.notes"))
                } content: {
                    Text(L10n.t("about.notes.1"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(L10n.t("about.notes.2"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("about.title"))
    }

    private var appVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildText: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundStyle(.secondary)
                .padding(.top, 5)
            Text(text)
                .font(.caption2)
        }
    }
}
