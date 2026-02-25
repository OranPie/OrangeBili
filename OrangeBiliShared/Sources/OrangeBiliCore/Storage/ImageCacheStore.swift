import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public protocol ImageCacheStoreProtocol {
    func image(for url: URL) async -> Image?
}

public actor ImageCacheStore: ImageCacheStoreProtocol {
    public static let shared = ImageCacheStore()

    #if canImport(UIKit)
    private let memoryCache = NSCache<NSString, UIImage>()
    #endif

    private let folderURL: URL

    public init() {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        folderURL = baseURL.appendingPathComponent("image-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    public func image(for url: URL) async -> Image? {
        let key = url.absoluteString as NSString

        #if canImport(UIKit)
        if let cached = memoryCache.object(forKey: key) {
            return Image(uiImage: cached)
        }
        #endif

        let diskURL = folderURL.appendingPathComponent(url.lastPathComponent)

        #if canImport(UIKit)
        if let data = try? Data(contentsOf: diskURL), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key)
            return Image(uiImage: image)
        }

        if let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key)
            try? data.write(to: diskURL, options: [.atomic])
            return Image(uiImage: image)
        }
        #endif

        return nil
    }
}
