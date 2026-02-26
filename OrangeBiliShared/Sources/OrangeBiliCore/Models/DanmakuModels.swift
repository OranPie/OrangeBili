import Foundation
import CoreGraphics

public enum DanmakuMode: String, Codable, Sendable {
    case scroll
    case top
    case bottom
    case reverse
    case advanced
}

public enum DanmakuSource: String, Codable, CaseIterable, Sendable {
    case xml       // Legacy XML (~1500 max)
    case protobuf  // Segmented protobuf (full coverage)
}

public enum DanmakuArea: String, Codable, CaseIterable, Sendable {
    case full
    case top
    case bottom
}

public struct AdvancedDanmakuParams: Hashable {
    public let startX: CGFloat
    public let startY: CGFloat
    public let startOpacity: Double
    public let endOpacity: Double
    public let duration: Double
    public let zRotate: Double
    public let yRotate: Double
    public let endX: CGFloat
    public let endY: CGFloat
    public let moveTime: Double   // ms
    public let moveDelay: Double  // ms
    public let stroke: Bool
    public let fontFamily: String
    public let linearSpeedUp: Bool

    public init(startX: CGFloat, startY: CGFloat, startOpacity: Double, endOpacity: Double,
                duration: Double, zRotate: Double, yRotate: Double, endX: CGFloat, endY: CGFloat,
                moveTime: Double, moveDelay: Double, stroke: Bool, fontFamily: String, linearSpeedUp: Bool) {
        self.startX = startX
        self.startY = startY
        self.startOpacity = startOpacity
        self.endOpacity = endOpacity
        self.duration = duration
        self.zRotate = zRotate
        self.yRotate = yRotate
        self.endX = endX
        self.endY = endY
        self.moveTime = moveTime
        self.moveDelay = moveDelay
        self.stroke = stroke
        self.fontFamily = fontFamily
        self.linearSpeedUp = linearSpeedUp
    }
}

public struct DanmakuItem: Identifiable, Hashable {
    public let id: String
    public let time: Double
    public let mode: DanmakuMode
    public let size: Int
    public let color: UInt32
    public let timestamp: Int
    public let pool: Int
    public let userHash: String
    public let rowId: String
    public let text: String
    public let advancedParams: AdvancedDanmakuParams?

    public init(
        id: String,
        time: Double,
        mode: DanmakuMode,
        size: Int,
        color: UInt32,
        timestamp: Int,
        pool: Int,
        userHash: String,
        rowId: String,
        text: String,
        advancedParams: AdvancedDanmakuParams? = nil
    ) {
        self.id = id
        self.time = time
        self.mode = mode
        self.size = size
        self.color = color
        self.timestamp = timestamp
        self.pool = pool
        self.userHash = userHash
        self.rowId = rowId
        self.text = text
        self.advancedParams = advancedParams
    }
}
