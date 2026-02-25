import Foundation

enum DanmakuMode: String, Codable {
    case scroll
    case top
    case bottom
}

enum DanmakuArea: String, Codable, CaseIterable {
    case full
    case top
    case bottom
}

struct DanmakuItem: Identifiable, Hashable {
    let id: String
    let time: Double
    let mode: DanmakuMode
    let size: Int
    let color: UInt32
    let timestamp: Int
    let pool: Int
    let userHash: String
    let rowId: String
    let text: String
}

