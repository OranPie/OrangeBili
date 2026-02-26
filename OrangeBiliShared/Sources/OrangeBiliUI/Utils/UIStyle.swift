import SwiftUI
import OrangeBiliCore

enum UIStyle {
    enum VideoLayout: Equatable {
        case row
        case grid(columns: Int)
    }

    static var videoLayout: VideoLayout {
#if os(tvOS)
        return .grid(columns: 2)
#elseif os(macOS)
        return .grid(columns: 3)
#else
        return .row
#endif
    }

    static let videoGridSpacing: CGFloat = 12
    static let videoTitleScale: CGFloat = 1.2

    #if os(watchOS)
    static let platformScale: CGFloat = 0.95
    #elseif os(tvOS)
    static let platformScale: CGFloat = 1.35
    static let buttonMinSize: CGFloat = 52
    #elseif os(macOS)
    static let platformScale: CGFloat = 1.1
    static let buttonMinSize: CGFloat = 36
    #else
    static let platformScale: CGFloat = 1.2
    static let buttonMinSize: CGFloat = 32
    #endif

    static func fontSize(_ size: CGFloat) -> CGFloat {
        size * platformScale
    }

    static let normalTextSize: CGFloat = 12 * platformScale

    #if os(watchOS)
    static let listRowInsets = EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
    static let cardPadding = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
    static let cardCornerRadius: CGFloat = 10
    static let chipCornerRadius: CGFloat = 8
    static let chipPadding = EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
    static let compactRowSpacing: CGFloat = 6
    static let compactIconSize: CGFloat = 11
    static let disclosureSpacing: CGFloat = 6
    #elseif os(tvOS)
    static let listRowInsets = EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
    static let cardPadding = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    static let cardCornerRadius: CGFloat = 18
    static let chipCornerRadius: CGFloat = 12
    static let chipPadding = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    static let compactRowSpacing: CGFloat = 14
    static let compactIconSize: CGFloat = 18
    static let disclosureSpacing: CGFloat = 10
    #elseif os(macOS)
    static let listRowInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    static let cardPadding = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
    static let cardCornerRadius: CGFloat = 12
    static let chipCornerRadius: CGFloat = 10
    static let chipPadding = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    static let compactRowSpacing: CGFloat = 10
    static let compactIconSize: CGFloat = 14
    static let disclosureSpacing: CGFloat = 8
    #else
    static let listRowInsets = EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
    static let cardPadding = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    static let cardCornerRadius: CGFloat = 14
    static let chipCornerRadius: CGFloat = 10
    static let chipPadding = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    static let compactRowSpacing: CGFloat = 10
    static let compactIconSize: CGFloat = 14
    static let disclosureSpacing: CGFloat = 8
    #endif
}
