import SwiftUI
import OrangeBiliCore

struct AsyncCachedImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: Placeholder

    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
                    .overlay(
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
            case .empty:
                placeholder
            @unknown default:
                placeholder
            }
        }
    }
}
