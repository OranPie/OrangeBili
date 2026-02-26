import SwiftUI
import OrangeBiliCore

struct DanmakuSettingsView: View {
    @EnvironmentObject private var render: RenderSettings

    var body: some View {
        List {
            Section(L10n.t("danmaku.section.basic")) {
                Picker(L10n.t("danmaku.source"), selection: $render.danmakuSourceRaw) {
                    Text(L10n.t("danmaku.source.protobuf")).tag(DanmakuSource.protobuf.rawValue)
                    Text(L10n.t("danmaku.source.xml")).tag(DanmakuSource.xml.rawValue)
                }

                Toggle(L10n.t("danmaku.enable"), isOn: $render.danmakuEnabled)

                sliderRow(L10n.f("danmaku.opacity", formatted(render.danmakuOpacity)),
                          value: $render.danmakuOpacity, range: 0.2...1.0, step: 0.05)

                sliderRow(L10n.f("danmaku.scale", formatted(render.danmakuScale)),
                          value: $render.danmakuScale, range: 0.6...1.6, step: 0.05)

                sliderRow(L10n.f("danmaku.advancedScale", formatted(render.danmakuAdvancedScale)),
                          value: $render.danmakuAdvancedScale, range: 0.6...2.4, step: 0.05)

                sliderRow(L10n.f("danmaku.speed", formatted(render.danmakuSpeed)),
                          value: $render.danmakuSpeed, range: 0.5...2.0, step: 0.05)
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

                Toggle(L10n.t("danmaku.stroke.enable"), isOn: $render.danmakuStrokeEnabled)

                if render.danmakuStrokeEnabled {
                    sliderRow(L10n.f("danmaku.stroke.width", formatted(render.danmakuStrokeWidth)),
                              value: $render.danmakuStrokeWidth, range: 0.3...2.0, step: 0.1)
                }

                intSliderRow(L10n.t("danmaku.density"),
                             value: $render.danmakuDensity, range: 1...8)

                intSliderRow(L10n.t("danmaku.maxLines"),
                             value: $render.danmakuMaxLines, range: 1...12)
            }

            Section(L10n.t("danmaku.section.filter")) {
                Toggle(L10n.t("danmaku.advancedOnly"), isOn: $render.danmakuAdvancedOnly)
                filterField(L10n.t("danmaku.block.keywords"), text: $render.danmakuKeywordBlocklist)
                filterField(L10n.t("danmaku.block.users"), text: $render.danmakuUserHashBlocklist)
                filterField(L10n.t("danmaku.search.query"), text: $render.danmakuSearchQuery)
                Toggle(L10n.t("danmaku.search.only"), isOn: $render.danmakuSearchOnly)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("danmaku.title"))
    }

    // MARK: - Reusable Rows

    @ViewBuilder
    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            #if os(tvOS)
            tvStepper(display: formatted(value.wrappedValue)) {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            } onPlus: {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            }
            #else
            Slider(value: value, in: range, step: step)
            #endif
        }
    }

    @ViewBuilder
    private func intSliderRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value.wrappedValue)")
                .font(.caption2)
        }
        #if os(tvOS)
        tvStepper(display: "\(value.wrappedValue)") {
            value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
        } onPlus: {
            value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
        }
        #else
        Slider(value: Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        #endif
    }

    #if os(tvOS)
    @ViewBuilder
    private func tvStepper(display: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: onMinus) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)

            Text(display)
                .font(.caption2)
                .frame(minWidth: 40)

            Button(action: onPlus) {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
        }
    }
    #endif

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

    // MARK: - Helpers

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func areaTitle(_ area: DanmakuArea) -> String {
        switch area {
        case .full: return L10n.t("danmaku.area.full")
        case .top: return L10n.t("danmaku.area.top")
        case .bottom: return L10n.t("danmaku.area.bottom")
        }
    }
}
