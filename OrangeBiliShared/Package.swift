// swift-tools-version: 5.9
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let env = ProcessInfo.processInfo.environment
let platformHint = [
    env["PLATFORM_NAME"],
    env["EFFECTIVE_PLATFORM_NAME"],
    env["SDK_NAME"],
    env["LLVM_TARGET_TRIPLE_SUFFIX"],
    env["SDKROOT"]
].compactMap { $0?.lowercased() }.joined(separator: " ")
let ffmpegPlatformOverride = env["ORANGEBILI_WATCH_FFMPEG_PLATFORM"]?.lowercased()
let useWatchSimulatorFFmpeg: Bool = {
    if let override = ffmpegPlatformOverride {
        if override.contains("simulator") || override == "sim" {
            return true
        }
        if override.contains("watchos") || override == "device" {
            return false
        }
    }
    if platformHint.contains("simulator") {
        return true
    }
    if platformHint.contains("watchos") {
        return false
    }
    // Xcode may evaluate manifests without a concrete watch destination.
    // Prefer simulator libs by default so watchOS-simulator builds do not
    // accidentally link device-only FFmpeg archives.
    return true
}()
let ffmpegPlatformFolder = useWatchSimulatorFFmpeg ? "platform-watchsimulator" : "platform-watchos"
let ffmpegIncludePath = "\(packageRoot)/Vendor/FFmpeg/\(ffmpegPlatformFolder)/include"
let ffmpegLibPath = "\(packageRoot)/Vendor/FFmpeg/\(ffmpegPlatformFolder)/lib"

let package = Package(
    name: "OrangeBiliShared",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "OrangeBiliCore", targets: ["OrangeBiliCore"]),
        .library(name: "OrangeBiliUI", targets: ["OrangeBiliUI"]),
        .library(name: "WatchPlayer", targets: ["WatchPlayer"]),
        .library(name: "WatchCustomPlayer", targets: ["WatchCustomPlayer"])
    ],
    targets: [
        .target(
            name: "OrangeBiliCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "OrangeBiliUI",
            dependencies: [
                "OrangeBiliCore",
                .target(name: "WatchPlayer", condition: .when(platforms: [.watchOS])),
                .target(name: "WatchCustomPlayer", condition: .when(platforms: [.watchOS])),
                .target(name: "WatchDecodeCore", condition: .when(platforms: [.watchOS]))
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "WatchPlayer"
        ),
        .target(
            name: "WatchCustomPlayer"
        ),
        .target(
            name: "WatchDecodeCore",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I", ffmpegIncludePath], .when(platforms: [.watchOS]))
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", ffmpegLibPath
                ], .when(platforms: [.watchOS])),
                .linkedLibrary("avcodec", .when(platforms: [.watchOS])),
                .linkedLibrary("avformat", .when(platforms: [.watchOS])),
                .linkedLibrary("avutil", .when(platforms: [.watchOS])),
                .linkedLibrary("swscale", .when(platforms: [.watchOS])),
                .linkedLibrary("swresample", .when(platforms: [.watchOS])),
                .linkedFramework("Security", .when(platforms: [.watchOS])),
                .linkedFramework("CoreFoundation", .when(platforms: [.watchOS])),
                .linkedFramework("CFNetwork", .when(platforms: [.watchOS])),
                .linkedLibrary("z", .when(platforms: [.watchOS])),
                .linkedLibrary("bz2", .when(platforms: [.watchOS])),
                .linkedLibrary("iconv", .when(platforms: [.watchOS]))
            ]
        )
    ]
)
