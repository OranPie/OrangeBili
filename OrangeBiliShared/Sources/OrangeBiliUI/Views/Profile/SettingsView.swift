import SwiftUI
import OrangeBiliCore

public struct SettingsView: View {
    @EnvironmentObject private var render: RenderSettings

    private let languageOptions: [(id: String, label: String)] = [
        ("system", L10n.t("settings.language.system")),
        ("en", L10n.t("settings.language.en")),
        ("zh-Hans", L10n.t("settings.language.zhHans")),
    ]

    public init() {}

    public var body: some View {
        List {
            // MARK: - General
            Section(L10n.t("settings.section.general")) {
                pickerRow(L10n.t("settings.language"), selection: $render.languageOverride, options: languageOptions)
                Toggle(L10n.t("render.compact"), isOn: $render.compactStats)
            }

            // MARK: - Playback
            Section(L10n.t("settings.section.playback")) {
                Toggle(L10n.t("render.resume"), isOn: $render.resumeFromLast)
                pickerRow(L10n.t("render.quality"), selection: $render.preferredQuality, options: RenderSettings.qualityOptions.map { ($0.id, $0.label) })
                pickerRow(L10n.t("settings.codec"), selection: $render.preferredCodecRaw, options: PreferredCodec.allCases.map { ($0.rawValue, L10n.t("settings.codec.\($0.rawValue)")) })
                #if os(watchOS)
                pickerRow(L10n.t("settings.vendor"), selection: $render.watchPlayerVendorRaw, options: [
                    (WatchPlayerVendor.videoPlayer.rawValue, L10n.t("settings.vendor.videoPlayer")),
                    (WatchPlayerVendor.ffmpegMinimal.rawValue, L10n.t("settings.vendor.ffmpegMinimal")),
                ])
                #endif
            }

            // MARK: - Appearance
            Section(L10n.t("settings.section.appearance")) {
                scaleRow(L10n.f("render.textScale", String(format: "%.2f", render.textScale)),
                         value: $render.textScale, range: 0.65...1.35)
                scaleRow(L10n.f("render.commentScale", String(format: "%.2f", render.commentTextScale)),
                         value: $render.commentTextScale, range: 0.65...1.4)
                scaleRow(L10n.f("render.cardScale", String(format: "%.2f", render.videoCardScale)),
                         value: $render.videoCardScale, range: 0.75...1.05)
                stepperRow(L10n.t("render.descriptionLines"), value: $render.detailDescriptionLines, range: 2...20)
            }

            // MARK: - Danmaku
            Section(L10n.t("danmaku.title")) {
                NavigationLink(L10n.t("danmaku.title")) {
                    DanmakuSettingsView()
                }
            }

            // MARK: - Advanced
            Section(L10n.t("settings.section.advanced")) {
                Toggle(L10n.t("settings.debugInfo"), isOn: $render.showVideoDebugInfo)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("settings.title"))
    }

    // MARK: - Row Helpers

    private func pickerRow(_ label: String, selection: Binding<String>, options: [(id: String, label: String)]) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .labelsHidden()
            #if os(iOS) || os(macOS)
            .pickerStyle(.menu)
            #endif
        }
    }

    private func pickerRow(_ label: String, selection: Binding<Int>, options: [(id: Int, label: String)]) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .labelsHidden()
            #if os(iOS) || os(macOS)
            .pickerStyle(.menu)
            #endif
        }
    }

    private func scaleRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            #if os(tvOS)
            HStack(spacing: 12) {
                Button {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 0.05)
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)

                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption2)
                    .frame(minWidth: 40)

                Button {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 0.05)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
            }
            #else
            Slider(value: value, in: range, step: 0.05)
            #endif
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            #if os(tvOS)
            .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
            #endif

            Text("\(value.wrappedValue)")
                .font(.caption2)
                .frame(minWidth: 16)

            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            #if os(tvOS)
            .frame(minWidth: UIStyle.buttonMinSize, minHeight: UIStyle.buttonMinSize)
            #endif
        }
    }
}
