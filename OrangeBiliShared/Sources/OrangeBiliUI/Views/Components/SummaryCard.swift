import SwiftUI
import OrangeBiliCore

struct SummaryCard: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let trailing: String?

    init(_ title: String, subtitle: String? = nil, systemImage: String? = nil, trailing: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: UIStyle.fontSize(UIStyle.compactIconSize), weight: .semibold))
                    .frame(width: UIStyle.fontSize(20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: UIStyle.fontSize(12), weight: .semibold))
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: UIStyle.fontSize(10)))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: UIStyle.fontSize(10), weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(UIStyle.cardPadding)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: UIStyle.cardCornerRadius))
#if os(tvOS)
        .frame(minHeight: UIStyle.buttonMinSize)
#endif
    }
}
