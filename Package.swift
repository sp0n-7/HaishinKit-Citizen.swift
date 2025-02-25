// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

#if swift(<6)
let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("ExistentialAny"),
    .enableExperimentalFeature("StrictConcurrency")
]
#else
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny")
]
#endif

let package = Package(
    name: "HaishinKitCitizen",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1),
        .macOS(.v10_15),
        .macCatalyst(.v14)
    ],
    products: [
        .library(name: "HaishinKitCitizen", targets: ["HaishinKitCitizen"]),
        .library(name: "SRTHaishinKitCitizen", targets: ["SRTHaishinKitCitizen"]),
        .library(name: "MoQTHaishinKitCitizen", targets: ["MoQTHaishinKitCitizen"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3"),
        .package(url: "https://github.com/shogo4405/Logboard.git", "2.5.0"..<"2.6.0")
    ],
    targets: [
        .binaryTarget(
            name: "libsrt",
            path: "SRTHaishinKit/Vendor/SRT/libsrt.xcframework"
        ),
        .target(
            name: "HaishinKitCitizen",
            dependencies: ["Logboard"],
            path: "HaishinKit/Sources",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SRTHaishinKitCitizen",
            dependencies: ["libsrt", "HaishinKitCitizen"],
            path: "SRTHaishinKit/Sources",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "MoQTHaishinKitCitizen",
            dependencies: ["HaishinKitCitizen"],
            path: "MoQTHaishinKit/Sources",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HaishinKitTestsCitizen",
            dependencies: ["HaishinKitCitizen"],
            path: "HaishinKit/Tests",
            resources: [
                .process("Asset")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SRTHaishinKitTestsCitizen",
            dependencies: ["SRTHaishinKitCitizen"],
            path: "SRTHaishinKit/Tests",
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6, .v5]
)
