import Foundation

public enum PlatformInfo {
    public static var platformName: String {
        #if os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(iOS)
        return "iOS"
        #else
        return "Apple"
        #endif
    }

    public static var userAgent: String {
        #if os(watchOS)
        return "Mozilla/5.0 (Apple Watch; watchOS 11.0)"
        #elseif os(tvOS)
        return "Mozilla/5.0 (Apple TV; tvOS 17.0)"
        #elseif os(iOS)
        return "Mozilla/5.0 (iPhone; iOS 18.0)"
        #else
        return "Mozilla/5.0"
        #endif
    }
}
