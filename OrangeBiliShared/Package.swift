// swift-tools-version: 5.9
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let env = ProcessInfo.processInfo.environment
let sdkName = (env["SDK_NAME"] ?? "").lowercased()
let platformName = (env["PLATFORM_NAME"] ?? "").lowercased()
let isWatchSimulator = sdkName.contains("simulator") || platformName.contains("simulator")
let ffmpegPlatformDir = isWatchSimulator ? "platform-watchsimulator" : "platform-watchos"
let ffmpegIncludePath = "\(packageRoot)/Vendor/FFmpeg/\(ffmpegPlatformDir)/include"
let ffmpegLibPath = "\(packageRoot)/Vendor/FFmpeg/\(ffmpegPlatformDir)/lib"

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
