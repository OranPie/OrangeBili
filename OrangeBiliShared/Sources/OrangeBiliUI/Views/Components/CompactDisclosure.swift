import SwiftUI
import OrangeBiliCore

struct CompactDisclosure<Label: View, Content: View>: View {
    @ViewBuilder let label: Label
    @ViewBuilder let content: Content
    @State private var isExpanded: Bool

    init(expanded: Bool = false, @ViewBuilder label: () -> Label, @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
        self._isExpanded = State(initialValue: expanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    label
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: UIStyle.disclosureSpacing) {
                    content
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
    }
}
