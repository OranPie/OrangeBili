import Foundation

enum Formatting {
    private static let absoluteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func count(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1f万", Double(value) / 10_000).replacingOccurrences(of: ".0", with: "")
        }
        return "\(value)"
    }

    static func time(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func absoluteDate(_ date: Date) -> String {
        absoluteDateFormatter.string(from: date)
    }

    static func compactDuration(_ raw: String) -> String {
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
}
