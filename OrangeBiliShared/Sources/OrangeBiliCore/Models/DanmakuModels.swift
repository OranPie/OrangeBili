import Foundation

public enum DanmakuMode: String, Codable {
    case scroll
    case top
    case bottom
}

public enum DanmakuArea: String, Codable, CaseIterable {
    case full
    case top
    case bottom
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
        text: String
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
    }
}
