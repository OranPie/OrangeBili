import SwiftUI
import OrangeBiliCore

enum UIStyle {
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
    static let chipPadding = EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
    static let compactRowSpacing: CGFloat = 14
    static let compactIconSize: CGFloat = 18
    static let disclosureSpacing: CGFloat = 10
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
