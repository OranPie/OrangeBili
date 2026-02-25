import SwiftUI

struct DanmakuSettingsView: View {
    @EnvironmentObject private var render: RenderSettings

    var body: some View {
        List {
            Section(L10n.t("danmaku.section.basic")) {
                Toggle(L10n.t("danmaku.enable"), isOn: $render.danmakuEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("danmaku.opacity", String(format: "%.2f", render.danmakuOpacity)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $render.danmakuOpacity, in: 0.2 ... 1.0, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("danmaku.scale", String(format: "%.2f", render.danmakuScale)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $render.danmakuScale, in: 0.6 ... 1.6, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("danmaku.speed", String(format: "%.2f", render.danmakuSpeed)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $render.danmakuSpeed, in: 0.5 ... 2.0, step: 0.05)
                }
            }

            Section(L10n.t("danmaku.section.position")) {
                Picker(L10n.t("danmaku.area"), selection: $render.danmakuAreaRaw) {
                    ForEach(DanmakuArea.allCases, id: \.rawValue) { area in
                        Text(areaTitle(area)).tag(area.rawValue)
                    }
                }

                Toggle(L10n.t("danmaku.allow.scroll"), isOn: $render.danmakuAllowScroll)
                Toggle(L10n.t("danmaku.allow.top"), isOn: $render.danmakuAllowTop)
                Toggle(L10n.t("danmaku.allow.bottom"), isOn: $render.danmakuAllowBottom)
            }

            Section(L10n.t("danmaku.section.display")) {
                Toggle(L10n.t("danmaku.color.original"), isOn: $render.danmakuUseOriginalColor)

                HStack {
                    Text(L10n.t("danmaku.density"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(render.danmakuDensity)")
                        .font(.caption2)
                }
                Slider(value: Binding(
                    get: { Double(render.danmakuDensity) },
                    set: { render.danmakuDensity = Int($0.rounded()) }
                ), in: 1 ... 5, step: 1)

                HStack {
                    Text(L10n.t("danmaku.maxLines"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(render.danmakuMaxLines)")
                        .font(.caption2)
                }
                Slider(value: Binding(
                    get: { Double(render.danmakuMaxLines) },
                    set: { render.danmakuMaxLines = Int($0.rounded()) }
                ), in: 1 ... 6, step: 1)
            }

            Section(L10n.t("danmaku.section.filter")) {
                TextField(L10n.t("danmaku.block.keywords"), text: $render.danmakuKeywordBlocklist)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                TextField(L10n.t("danmaku.block.users"), text: $render.danmakuUserHashBlocklist)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                TextField(L10n.t("danmaku.search.query"), text: $render.danmakuSearchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                Toggle(L10n.t("danmaku.search.only"), isOn: $render.danmakuSearchOnly)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("danmaku.title"))
    }

    private func areaTitle(_ area: DanmakuArea) -> String {
        switch area {
        case .full: return L10n.t("danmaku.area.full")
        case .top: return L10n.t("danmaku.area.top")
        case .bottom: return L10n.t("danmaku.area.bottom")
        }
    }
}

