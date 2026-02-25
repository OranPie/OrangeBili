import Foundation
import Combine
import SwiftUI

@MainActor
public final class DanmakuViewModel: ObservableObject {
    public struct ActiveDanmaku: Identifiable, Hashable {
        public let id: String
        public let item: DanmakuItem
        public let startTime: Double
        public let duration: Double
        public let lane: Int
        public let y: CGFloat
        public let fontSize: CGFloat
        public let color: Color
        public let textWidth: CGFloat
    }

    @Published public private(set) var active: [ActiveDanmaku] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private var items: [DanmakuItem] = []
    private var nextIndex = 0
    private var lastTime: Double = 0
    private var laneCursor: [DanmakuMode: Int] = [.scroll: 0, .top: 0, .bottom: 0]

    private let service: DanmakuService

    public init(service: DanmakuService = .shared) {
        self.service = service
    }

    public func reset() {
        items = []
        nextIndex = 0
        lastTime = 0
        laneCursor = [.scroll: 0, .top: 0, .bottom: 0]
        active = []
        errorMessage = nil
    }

    public func load(cid: Int) async {
        guard cid > 0 else { return }
        isLoading = true
        errorMessage = nil
        do {
            items = try await service.fetchDanmaku(cid: cid)
            nextIndex = 0
            lastTime = 0
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func update(time: Double, size: CGSize, settings: RenderSettings) {
        guard settings.danmakuEnabled else {
            active = []
            return
        }
        if time + 0.1 < lastTime {
            nextIndex = 0
            active = []
        }

        let laneConfig = laneLayout(size: size, settings: settings)

        let allowedPerSecond = max(1, 7 - settings.danmakuDensity)
        var addedThisTick = 0

        while nextIndex < items.count, items[nextIndex].time <= time {
            let item = items[nextIndex]
            nextIndex += 1

            if !filterAllows(item: item, settings: settings) { continue }
            if addedThisTick >= allowedPerSecond { continue }

            if let activeItem = makeActive(item: item, time: time, layout: laneConfig, settings: settings) {
                active.append(activeItem)
                addedThisTick += 1
            }
        }

        active.removeAll { time - $0.startTime > $0.duration }
        lastTime = time
    }

    public func xPosition(for activeItem: ActiveDanmaku, time: Double, width: CGFloat) -> CGFloat {
        let elapsed = time - activeItem.startTime
        if activeItem.item.mode == .scroll {
            let total = width + activeItem.textWidth + 12
            let progress = min(max(elapsed / activeItem.duration, 0), 1)
            return width - total * CGFloat(progress) + activeItem.textWidth / 2
        }
        return width / 2
    }

    private func filterAllows(item: DanmakuItem, settings: RenderSettings) -> Bool {
        switch item.mode {
        case .scroll where !settings.danmakuAllowScroll: return false
        case .top where !settings.danmakuAllowTop: return false
        case .bottom where !settings.danmakuAllowBottom: return false
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

    private func makeActive(item: DanmakuItem, time: Double, layout: LaneLayout, settings: RenderSettings) -> ActiveDanmaku? {
        let baseSize = CGFloat(item.size) / 25.0 * 12.0 * settings.danmakuScale
        let fontSize = max(8, min(baseSize, 18))
        let textWidth = estimateWidth(text: item.text, fontSize: fontSize)
        let color = settings.danmakuUseOriginalColor ? colorFromInt(item.color) : .white

        let duration: Double
        if item.mode == .scroll {
            duration = max(3.5, 6.0 / settings.danmakuSpeed)
        } else {
            duration = max(2.8, 4.0 / settings.danmakuSpeed)
        }

        let laneInfo = layout.laneInfo(for: item.mode)
        guard laneInfo.count > 0 else { return nil }

        let lane = laneCursor[item.mode, default: 0] % laneInfo.count
        laneCursor[item.mode, default: 0] = lane + 1

        let y = laneInfo.originY + CGFloat(lane) * laneInfo.lineHeight + laneInfo.lineHeight / 2

        return ActiveDanmaku(
            id: "\(item.rowId)-\(time)-\(lane)",
            item: item,
            startTime: time,
            duration: duration,
            lane: lane,
            y: y,
            fontSize: fontSize,
            color: color,
            textWidth: textWidth
        )
    }

    private func estimateWidth(text: String, fontSize: CGFloat) -> CGFloat {
        CGFloat(text.count) * fontSize * 0.6
    }

    private func colorFromInt(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private struct LaneLayout {
        struct LaneInfo {
            let count: Int
            let originY: CGFloat
            let lineHeight: CGFloat
        }

        let scroll: LaneInfo
        let top: LaneInfo
        let bottom: LaneInfo

        func laneInfo(for mode: DanmakuMode) -> LaneInfo {
            switch mode {
            case .scroll: return scroll
            case .top: return top
            case .bottom: return bottom
            }
        }
    }

    private func laneLayout(size: CGSize, settings: RenderSettings) -> LaneLayout {
        let lineHeight = max(10, 12 * settings.danmakuScale + 2)
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

        let topInfo = LaneLayout.LaneInfo(count: topCount, originY: 0, lineHeight: lineHeight)
        let bottomInfo = LaneLayout.LaneInfo(count: bottomCount, originY: totalHeight - CGFloat(bottomCount) * lineHeight, lineHeight: lineHeight)
        let scrollInfo = LaneLayout.LaneInfo(count: scrollCount, originY: scrollOriginY, lineHeight: lineHeight)

        return LaneLayout(scroll: scrollInfo, top: topInfo, bottom: bottomInfo)
    }
}
