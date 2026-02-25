import SwiftUI
import OrangeBiliCore

struct InlineStatChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: UIStyle.fontSize(9.5), weight: .medium))
        .padding(UIStyle.chipPadding)
        .background(Color.gray.opacity(0.15), in: Capsule())
    }
}
