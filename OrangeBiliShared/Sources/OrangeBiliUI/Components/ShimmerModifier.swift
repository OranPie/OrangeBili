import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @State private var started = false

    private var duration: Double {
        #if os(watchOS)
        1.6
        #else
        1.2
        #endif
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.25), location: 0.5),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: phase * width)
                    .clipped()
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onAppear {
                guard !started else { return }
                started = true
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
