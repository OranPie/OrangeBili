import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public protocol ImageCacheStoreProtocol {
    func image(for url: URL) async -> Image?
}

public actor ImageCacheStore: ImageCacheStoreProtocol {
    public static let shared = ImageCacheStore()

    #if canImport(UIKit)
    private let memoryCache = NSCache<NSString, UIImage>()
    #elseif canImport(AppKit)
    private let memoryCache = NSCache<NSString, NSImage>()
    #endif

    private let folderURL: URL

    public init() {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        folderURL = baseURL.appendingPathComponent("image-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        #if canImport(UIKit)
        #if os(watchOS)
        memoryCache.countLimit = 30
        memoryCache.totalCostLimit = 8 * 1024 * 1024  // 8 MB
        #else
        memoryCache.countLimit = 80
        memoryCache.totalCostLimit = 30 * 1024 * 1024  // 30 MB
        #endif
        #elseif canImport(AppKit)
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 40 * 1024 * 1024  // 40 MB
        #endif
    }

    public func image(for url: URL) async -> Image? {
        let key = url.absoluteString as NSString
        let diskURL = folderURL.appendingPathComponent(diskKey(for: url))

        #if canImport(UIKit)
        if let cached = memoryCache.object(forKey: key) {
            return Image(uiImage: cached)
        }

        if let data = try? Data(contentsOf: diskURL), let img = UIImage(data: data) {
            memoryCache.setObject(img, forKey: key, cost: data.count)
            return Image(uiImage: img)
        }

        var request = URLRequest(url: url)
        #if os(watchOS)
        request.timeoutInterval = 15
        #else
        request.timeoutInterval = 12
        #endif
        if let (data, _) = try? await URLSession.shared.data(for: request), let img = UIImage(data: data) {
            memoryCache.setObject(img, forKey: key, cost: data.count)
            try? data.write(to: diskURL, options: [.atomic])
            return Image(uiImage: img)
        }

        #elseif canImport(AppKit)
        if let cached = memoryCache.object(forKey: key) {
            return Image(nsImage: cached)
        }

        if let data = try? Data(contentsOf: diskURL), let img = NSImage(data: data) {
            memoryCache.setObject(img, forKey: key, cost: data.count)
            return Image(nsImage: img)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        if let (data, _) = try? await URLSession.shared.data(for: request), let img = NSImage(data: data) {
            memoryCache.setObject(img, forKey: key, cost: data.count)
            try? data.write(to: diskURL, options: [.atomic])
            return Image(nsImage: img)
        }
        #endif

        return nil
    }

    /// Stable disk filename from URL (hash to avoid path issues)
    private func diskKey(for url: URL) -> String {
        let str = url.absoluteString
        var hash: UInt64 = 5381
        for byte in str.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        return "\(hash).\(ext)"
    }
}
