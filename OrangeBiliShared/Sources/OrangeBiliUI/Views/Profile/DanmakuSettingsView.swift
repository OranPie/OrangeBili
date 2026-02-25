import SwiftUI
import OrangeBiliCore

struct DanmakuSettingsView: View {
    @EnvironmentObject private var render: RenderSettings


    @ViewBuilder
    private func filterField(_ title: String, text: Binding<String>) -> some View {
#if os(macOS)
        TextField(title, text: text)
            .autocorrectionDisabled(true)
#else
        TextField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
#endif
    }

    var body: some View {

        List {
            Section(L10n.t("danmaku.section.basic")) {
                Toggle(L10n.t("danmaku.enable"), isOn: $render.danmakuEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("danmaku.opacity", String(format: "%.2f", render.danmakuOpacity)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
#if os(tvOS)
                    HStack(spacing: 12) {
                        Button {
                            render.danmakuOpacity = max(0.2, render.danmakuOpacity - 0.05)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                        Text(String(format: "%.2f", render.danmakuOpacity))
                            .font(.caption2)
                            .frame(minWidth: 40)

                        Button {
                            render.danmakuOpacity = min(1.0, render.danmakuOpacity + 0.05)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                    }
#else
                    Slider(value: $render.danmakuOpacity, in: 0.2 ... 1.0, step: 0.05)
#endif
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("danmaku.scale", String(format: "%.2f", render.danmakuScale)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
#if os(tvOS)
                    HStack(spacing: 12) {
                        Button {
                            render.danmakuScale = max(0.6, render.danmakuScale - 0.05)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                        Text(String(format: "%.2f", render.danmakuScale))
                            .font(.caption2)
                            .frame(minWidth: 40)

                        Button {
                            render.danmakuScale = min(1.6, render.danmakuScale + 0.05)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                    }
#else
                    Slider(value: $render.danmakuScale, in: 0.6 ... 1.6, step: 0.05)
#endif
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.f("danmaku.speed", String(format: "%.2f", render.danmakuSpeed)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
#if os(tvOS)
                    HStack(spacing: 12) {
                        Button {
                            render.danmakuSpeed = max(0.5, render.danmakuSpeed - 0.05)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                        Text(String(format: "%.2f", render.danmakuSpeed))
                            .font(.caption2)
                            .frame(minWidth: 40)

                        Button {
                            render.danmakuSpeed = min(2.0, render.danmakuSpeed + 0.05)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                    }
#else
                    Slider(value: $render.danmakuSpeed, in: 0.5 ... 2.0, step: 0.05)
#endif
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
#if os(tvOS)
                HStack(spacing: 12) {
                    Button {
                        render.danmakuDensity = max(1, render.danmakuDensity - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                    Text("\(render.danmakuDensity)")
                        .font(.caption2)
                        .frame(minWidth: 24)

                    Button {
                        render.danmakuDensity = min(5, render.danmakuDensity + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                }
#else
                Slider(value: Binding(
                    get: { Double(render.danmakuDensity) },
                    set: { render.danmakuDensity = Int($0.rounded()) }
                ), in: 1 ... 5, step: 1)
#endif

                HStack {
                    Text(L10n.t("danmaku.maxLines"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(render.danmakuMaxLines)")
                        .font(.caption2)
                }
#if os(tvOS)
                HStack(spacing: 12) {
                    Button {
                        render.danmakuMaxLines = max(1, render.danmakuMaxLines - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif

                    Text("\(render.danmakuMaxLines)")
                        .font(.caption2)
                        .frame(minWidth: 24)

                    Button {
                        render.danmakuMaxLines = min(6, render.danmakuMaxLines + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
#if os(tvOS)
                        .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
#endif
                }
#else
                Slider(value: Binding(
                    get: { Double(render.danmakuMaxLines) },
                    set: { render.danmakuMaxLines = Int($0.rounded()) }
                ), in: 1 ... 6, step: 1)
#endif
            }

            Section(L10n.t("danmaku.section.filter")) {
                filterField(L10n.t("danmaku.block.keywords"), text: $render.danmakuKeywordBlocklist)

                filterField(L10n.t("danmaku.block.users"), text: $render.danmakuUserHashBlocklist)

                filterField(L10n.t("danmaku.search.query"), text: $render.danmakuSearchQuery)

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

