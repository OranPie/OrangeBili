import Foundation

public enum Formatting {
    private static let absoluteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        return formatter
    }()

    public static func count(_ value: Int) -> String {
        let language = Locale.current.languageCode ?? "en"
        if language.hasPrefix("zh") {
            if value >= 10_000 {
                return String(format: "%.1f万", Double(value) / 10_000).replacingOccurrences(of: ".0", with: "")
            }
            return "\(value)"
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000).replacingOccurrences(of: ".0", with: "")
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000).replacingOccurrences(of: ".0", with: "")
        }
        return "\(value)"
    }

    public static func time(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    public static func absoluteDate(_ date: Date) -> String {
        absoluteDateFormatter.string(from: date)
    }

    public static func compactDuration(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":").compactMap { Int($0) }
        if parts.count == 3 {
            let hours = parts[0]
            let minutes = parts[1]
            return hours > 0 ? "\(hours)h\(minutes)m" : String(format: "%02d:%02d", minutes, parts[2])
        }
        if parts.count == 2 {
            return String(format: "%02d:%02d", parts[0], parts[1])
        }
        return String(trimmed.prefix(8))
    }

    public static func timeText(_ seconds: Int) -> String {
        let safe = max(seconds, 0)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }
}
