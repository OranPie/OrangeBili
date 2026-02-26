import Foundation
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
public final class DanmakuViewModel: ObservableObject {
    public struct RenderDanmaku: Identifiable {
        public let id: String
        public let text: String
        public let mode: DanmakuMode
        public let startTime: Double
        public let duration: Double
        public let lane: Int
        public let y: CGFloat
        public let fontSize: CGFloat
        public let color: Color
        public let textWidth: CGFloat
        public let advancedParams: AdvancedDanmakuParams?
    }

    @Published public private(set) var active: [RenderDanmaku] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    /// Set by the view layer from PlayerViewModel.currentTime
    public var currentVideoTime: Double = 0

    // Separated item lists after loading
    private var normalItems: [DanmakuItem] = []    // scroll, reverse, top, bottom — sorted by time
    private var advancedItems: [DanmakuItem] = []   // advanced — sorted by time

    // Cursor for normal items (monotonically increasing)
    private var normalNextIndex = 0
    private var lastTime: Double = 0

    // Cursor for advanced items
    private var advancedNextIndex = 0

    // Collision-aware lane state
    private struct LaneState {
        var lastTextWidth: CGFloat = 0
        var lastStartTime: Double = 0
        var lastDuration: Double = 0
        var lastSpeed: CGFloat = 0
    }

    private var scrollLanes: [LaneState] = []
    private var reverseLanes: [LaneState] = []
    private var topLanes: [LaneState] = []
    private var bottomLanes: [LaneState] = []

    // Text measurement cache
    private static let measureCache = NSCache<NSString, NSNumber>()

    private let service: DanmakuService

    public init(service: DanmakuService = .shared) {
        self.service = service
    }

    public func reset() {
        normalItems = []
        advancedItems = []
        normalNextIndex = 0
        advancedNextIndex = 0
        lastTime = 0
        active = []
        scrollLanes = []
        reverseLanes = []
        topLanes = []
        bottomLanes = []
        errorMessage = nil
    }

    public func load(cid: Int, aid: Int = 0, durationSeconds: Int = 0, source: DanmakuSource = .protobuf) async {
        guard cid > 0 else {
            DebugLogStore.shared.log(category: "danmaku.vm", message: "skip load: cid=0")
            return
        }
        isLoading = true
        errorMessage = nil
        DebugLogStore.shared.log(category: "danmaku.vm", message: "load start cid=\(cid) aid=\(aid) dur=\(durationSeconds)s source=\(source)")
        do {
            let items = try await service.fetchDanmaku(cid: cid, aid: aid, source: source, durationSeconds: durationSeconds)

            // Separate by mode: advanced items get independent processing
            var normal: [DanmakuItem] = []
            var advanced: [DanmakuItem] = []
            for item in items {
                if item.mode == .advanced {
                    advanced.append(item)
                } else {
                    normal.append(item)
                }
            }
            normalItems = normal.sorted { $0.time < $1.time }
            advancedItems = advanced.sorted { $0.time < $1.time }
            normalNextIndex = 0
            advancedNextIndex = 0
            lastTime = 0

            DebugLogStore.shared.log(category: "danmaku.vm", message: "load ok: \(normal.count) normal + \(advanced.count) advanced = \(items.count) total")
        } catch {
            errorMessage = error.localizedDescription
            DebugLogStore.shared.log(category: "danmaku.vm", message: "load fail: \(error.localizedDescription)")
        }
        isLoading = false
    }

    // MARK: - Frame Update

    public func update(time: Double, size: CGSize, settings: RenderSettings) {
        guard settings.danmakuEnabled else {
            if !active.isEmpty { active = [] }
            return
        }

        // Seek backward detection
        if time + 0.1 < lastTime {
            normalNextIndex = 0
            advancedNextIndex = 0
            active = []
            resetLanes()
        }

        let laneConfig = laneLayout(size: size, settings: settings)
        ensureLaneCapacity(layout: laneConfig)

        // --- Process normal danmaku (scroll, reverse, top, bottom) ---
        let allowedPerTick = densityLimit(settings.danmakuDensity)
        var addedThisTick = 0

        while normalNextIndex < normalItems.count, normalItems[normalNextIndex].time <= time {
            let item = normalItems[normalNextIndex]
            normalNextIndex += 1

            // Skip expired items (display window already passed)
            let dur = normalDuration(mode: item.mode, settings: settings)
            if time - item.time > dur { continue }

            if addedThisTick >= allowedPerTick { continue }
            if !filterAllows(item: item, settings: settings) { continue }

            if let rendered = makeNormalRender(item: item, time: time, size: size, layout: laneConfig, settings: settings) {
                active.append(rendered)
                addedThisTick += 1
            }
        }

        // --- Process advanced danmaku (absolute positioning, no density limit) ---
        // Advanced danmaku use item.time as startTime so animations are video-synced.
        // Scan from cursor forward; also check active window.
        while advancedNextIndex < advancedItems.count, advancedItems[advancedNextIndex].time <= time {
            let item = advancedItems[advancedNextIndex]
            advancedNextIndex += 1

            let dur = item.advancedParams?.duration ?? 10.0
            if time - item.time > dur { continue }
            if !filterAllows(item: item, settings: settings) { continue }

            if let rendered = makeAdvancedRender(item: item, settings: settings) {
                active.append(rendered)
            }
        }

        // --- Expire finished danmaku ---
        active.removeAll {
            (time - $0.startTime > $0.duration) || !activeRenderStillAllowed(item: $0, settings: settings)
        }
        lastTime = time
    }

    // MARK: - Density

    private func densityLimit(_ density: Int) -> Int {
        switch density {
        case 1: return 1
        case 2: return 2
        case 3: return 4
        case 4: return 6
        case 5: return 10
        case 6: return 16
        case 7: return 24
        case 8: return Int.max
        default: return 6
        }
    }

    private func normalDuration(mode: DanmakuMode, settings: RenderSettings) -> Double {
        switch mode {
        case .scroll, .reverse: return max(3.5, 6.0 / settings.danmakuSpeed)
        case .top, .bottom:     return max(2.8, 4.0 / settings.danmakuSpeed)
        case .advanced:         return 10.0
        }
    }

    // MARK: - Text Measurement

    private func measureWidth(text: String, fontSize: CGFloat) -> CGFloat {
        let key = "\(text)-\(fontSize)" as NSString
        if let cached = Self.measureCache.object(forKey: key) {
            return CGFloat(cached.doubleValue)
        }
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let size = (text as NSString).size(withAttributes: [.font: font])
        #elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let size = (text as NSString).size(withAttributes: [.font: font])
        #endif
        let width = ceil(size.width)
        Self.measureCache.setObject(NSNumber(value: Double(width)), forKey: key)
        return width
    }

    // MARK: - Collision-Aware Lane Allocation

    private func allocateScrollLane(textWidth: CGFloat, duration: Double, screenWidth: CGFloat, time: Double, lanes: inout [LaneState]) -> Int? {
        let newSpeed = (screenWidth + textWidth + 12) / CGFloat(duration)
        let gap: CGFloat = 12

        for i in 0..<lanes.count {
            let state = lanes[i]
            if state.lastSpeed == 0 {
                lanes[i] = LaneState(lastTextWidth: textWidth, lastStartTime: time, lastDuration: duration, lastSpeed: newSpeed)
                return i
            }

            let tailClearTime = state.lastStartTime + Double((state.lastTextWidth + gap) / state.lastSpeed)
            if time >= tailClearTime {
                if newSpeed <= state.lastSpeed || !willCollide(state: state, newSpeed: newSpeed, newTextWidth: textWidth, screenWidth: screenWidth, time: time) {
                    lanes[i] = LaneState(lastTextWidth: textWidth, lastStartTime: time, lastDuration: duration, lastSpeed: newSpeed)
                    return i
                }
            }
        }
        return nil
    }

    private func willCollide(state: LaneState, newSpeed: CGFloat, newTextWidth: CGFloat, screenWidth: CGFloat, time: Double) -> Bool {
        let oldExitTime = state.lastStartTime + state.lastDuration
        let remainingOldTime = oldExitTime - time
        guard remainingOldTime > 0 else { return false }
        let oldElapsed = CGFloat(time - state.lastStartTime)
        let oldLeftEdgeNow = screenWidth - state.lastSpeed * oldElapsed
        let timeToReach = oldLeftEdgeNow / (newSpeed - state.lastSpeed)
        return timeToReach > 0 && timeToReach < CGFloat(remainingOldTime)
    }

    private func allocateFixedLane(time: Double, lanes: inout [LaneState], duration: Double) -> Int? {
        for i in 0..<lanes.count {
            let state = lanes[i]
            if state.lastSpeed == 0 || time >= state.lastStartTime + state.lastDuration {
                lanes[i] = LaneState(lastTextWidth: 0, lastStartTime: time, lastDuration: duration, lastSpeed: 1)
                return i
            }
        }
        return nil
    }

    // MARK: - Render Construction

    private func makeNormalRender(item: DanmakuItem, time: Double, size: CGSize, layout: LaneLayout, settings: RenderSettings) -> RenderDanmaku? {
        let fontSize = danmakuFontSize(itemSize: item.size, mode: item.mode, settings: settings)
        let textWidth = measureWidth(text: item.text, fontSize: fontSize)
        let color: Color = settings.danmakuUseOriginalColor ? colorFromInt(item.color) : .white

        let duration: Double
        switch item.mode {
        case .scroll, .reverse: duration = max(3.5, 6.0 / settings.danmakuSpeed)
        case .top, .bottom:     duration = max(2.8, 4.0 / settings.danmakuSpeed)
        case .advanced:         return nil
        }

        var lane = 0
        var y: CGFloat = 0

        switch item.mode {
        case .scroll:
            let info = layout.scroll
            guard info.count > 0 else { return nil }
            guard let allocated = allocateScrollLane(textWidth: textWidth, duration: duration, screenWidth: size.width, time: time, lanes: &scrollLanes) else { return nil }
            lane = allocated
            y = info.originY + CGFloat(lane) * info.lineHeight + info.lineHeight / 2

        case .reverse:
            let info = layout.scroll
            guard info.count > 0 else { return nil }
            guard let allocated = allocateScrollLane(textWidth: textWidth, duration: duration, screenWidth: size.width, time: time, lanes: &reverseLanes) else { return nil }
            lane = allocated
            y = info.originY + CGFloat(lane) * info.lineHeight + info.lineHeight / 2

        case .top:
            let info = layout.top
            guard info.count > 0 else { return nil }
            guard let allocated = allocateFixedLane(time: time, lanes: &topLanes, duration: duration) else { return nil }
            lane = allocated
            y = info.originY + CGFloat(lane) * info.lineHeight + info.lineHeight / 2

        case .bottom:
            let info = layout.bottom
            guard info.count > 0 else { return nil }
            guard let allocated = allocateFixedLane(time: time, lanes: &bottomLanes, duration: duration) else { return nil }
            lane = allocated
            y = info.originY + CGFloat(info.count - 1 - lane) * info.lineHeight + info.lineHeight / 2

        case .advanced:
            return nil
        }

        return RenderDanmaku(
            id: "\(item.rowId)-\(time)-\(lane)",
            text: item.text,
            mode: item.mode,
            startTime: time,
            duration: duration,
            lane: lane,
            y: y,
            fontSize: fontSize,
            color: color,
            textWidth: textWidth,
            advancedParams: nil
        )
    }

    /// Advanced danmaku: startTime = item.time (video-synced), no lane allocation.
    private func makeAdvancedRender(item: DanmakuItem, settings: RenderSettings) -> RenderDanmaku? {
        let fontSize = danmakuFontSize(itemSize: item.size, mode: .advanced, settings: settings)
        let textWidth = measureWidth(text: item.text, fontSize: fontSize)
        let color: Color = settings.danmakuUseOriginalColor ? colorFromInt(item.color) : .white
        let duration = item.advancedParams?.duration ?? 10.0

        return RenderDanmaku(
            id: "\(item.rowId)-adv",
            text: item.text,
            mode: .advanced,
            startTime: item.time,
            duration: duration,
            lane: 0,
            y: 0,
            fontSize: fontSize,
            color: color,
            textWidth: textWidth,
            advancedParams: item.advancedParams
        )
    }

    // MARK: - Filter

    private func filterAllows(item: DanmakuItem, settings: RenderSettings) -> Bool {
        if settings.danmakuAdvancedOnly && item.mode != .advanced { return false }

        switch item.mode {
        case .scroll where !settings.danmakuAllowScroll: return false
        case .top where !settings.danmakuAllowTop: return false
        case .bottom where !settings.danmakuAllowBottom: return false
        case .reverse where !settings.danmakuAllowScroll: return false
        default: break
        }

        if !settings.danmakuUserHashBlocklist.isEmpty {
            let blocked = settings.danmakuUserHashBlocklist
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            if blocked.contains(item.userHash.lowercased()) { return false }
        }

        if !settings.danmakuKeywordBlocklist.isEmpty {
            let keywords = settings.danmakuKeywordBlocklist
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            let text = item.text.lowercased()
            if keywords.contains(where: { !text.isEmpty && text.contains($0) }) { return false }
        }

        if !settings.danmakuSearchQuery.isEmpty {
            let query = settings.danmakuSearchQuery.lowercased()
            if settings.danmakuSearchOnly, !item.text.lowercased().contains(query) {
                return false
            }
        }

        return true
    }

    private func activeRenderStillAllowed(item: RenderDanmaku, settings: RenderSettings) -> Bool {
        if settings.danmakuAdvancedOnly && item.mode != .advanced { return false }

        switch item.mode {
        case .scroll where !settings.danmakuAllowScroll: return false
        case .top where !settings.danmakuAllowTop: return false
        case .bottom where !settings.danmakuAllowBottom: return false
        case .reverse where !settings.danmakuAllowScroll: return false
        default: break
        }

        if !settings.danmakuKeywordBlocklist.isEmpty {
            let keywords = settings.danmakuKeywordBlocklist
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            let text = item.text.lowercased()
            if keywords.contains(where: { !text.isEmpty && text.contains($0) }) { return false }
        }

        if !settings.danmakuSearchQuery.isEmpty {
            let query = settings.danmakuSearchQuery.lowercased()
            if settings.danmakuSearchOnly, !item.text.lowercased().contains(query) {
                return false
            }
        }

        return true
    }

    // MARK: - Lane Layout

    private struct LaneLayout {
        struct LaneInfo {
            let count: Int
            let originY: CGFloat
            let lineHeight: CGFloat
        }
        let scroll: LaneInfo
        let top: LaneInfo
        let bottom: LaneInfo
    }

    private func laneLayout(size: CGSize, settings: RenderSettings) -> LaneLayout {
        #if os(macOS)
        let baseLH: CGFloat = 22
        #elseif os(tvOS)
        let baseLH: CGFloat = 28
        #elseif os(watchOS)
        let baseLH: CGFloat = 10
        #else
        let baseLH: CGFloat = 12
        #endif
        let lineHeight = max(10, baseLH * settings.danmakuScale + 2)
        let totalHeight = size.height

        let scrollAreaHeight: CGFloat
        let scrollOriginY: CGFloat
        switch settings.danmakuArea {
        case .full:
            scrollAreaHeight = totalHeight
            scrollOriginY = 0
        case .top:
            scrollAreaHeight = totalHeight * 0.5
            scrollOriginY = 0
        case .bottom:
            scrollAreaHeight = totalHeight * 0.5
            scrollOriginY = totalHeight * 0.5
        }

        let scrollCount = max(1, Int(scrollAreaHeight / lineHeight))
        let topCount = max(1, min(settings.danmakuMaxLines, Int((totalHeight * 0.33) / lineHeight)))
        let bottomCount = max(1, min(settings.danmakuMaxLines, Int((totalHeight * 0.33) / lineHeight)))

        return LaneLayout(
            scroll: .init(count: scrollCount, originY: scrollOriginY, lineHeight: lineHeight),
            top: .init(count: topCount, originY: 0, lineHeight: lineHeight),
            bottom: .init(count: bottomCount, originY: totalHeight - CGFloat(bottomCount) * lineHeight, lineHeight: lineHeight)
        )
    }

    private func ensureLaneCapacity(layout: LaneLayout) {
        if scrollLanes.count != layout.scroll.count {
            scrollLanes = Array(repeating: LaneState(), count: layout.scroll.count)
        }
        if reverseLanes.count != layout.scroll.count {
            reverseLanes = Array(repeating: LaneState(), count: layout.scroll.count)
        }
        if topLanes.count != layout.top.count {
            topLanes = Array(repeating: LaneState(), count: layout.top.count)
        }
        if bottomLanes.count != layout.bottom.count {
            bottomLanes = Array(repeating: LaneState(), count: layout.bottom.count)
        }
    }

    private func resetLanes() {
        scrollLanes = scrollLanes.map { _ in LaneState() }
        reverseLanes = reverseLanes.map { _ in LaneState() }
        topLanes = topLanes.map { _ in LaneState() }
        bottomLanes = bottomLanes.map { _ in LaneState() }
    }

    // MARK: - Helpers

    private func danmakuFontSize(itemSize: Int, mode: DanmakuMode, settings: RenderSettings) -> CGFloat {
        #if os(macOS)
        let basePt: CGFloat = 22
        let maxPt: CGFloat = 36
        #elseif os(tvOS)
        let basePt: CGFloat = 28
        let maxPt: CGFloat = 44
        #elseif os(watchOS)
        let basePt: CGFloat = 10
        let maxPt: CGFloat = 15
        #else
        let basePt: CGFloat = 12
        let maxPt: CGFloat = 18
        #endif
        var multiplier = settings.danmakuScale
        if mode == .advanced {
            multiplier *= settings.danmakuAdvancedScale
        }
        let scaled = CGFloat(itemSize) / 25.0 * basePt * multiplier
        return max(8, min(scaled, maxPt))
    }

    private func colorFromInt(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
