import SwiftUI
import OrangeBiliCore

struct AsyncCachedImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: Placeholder

    @State private var loadedImage: Image?
    @State private var failed = false

    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                image
                    .resizable()
                    .scaledToFill()
            } else if failed {
                placeholder
                    .overlay(
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard let url else {
                failed = true
                return
            }
            loadedImage = nil
            failed = false
            if let image = await ImageCacheStore.shared.image(for: url) {
                loadedImage = image
            } else {
                failed = true
            }
        }
    }
}
