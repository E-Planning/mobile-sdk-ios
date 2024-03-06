// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EplanningSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "EplanningSDK",
            targets: [
                "EplanningSDK",
            ]
        ),
        .library(
            name: "GoogleMediationAdapter",
            targets: [
                "GoogleMediationAdapter",
            ]
        ),
    ],
    dependencies: [
        .package(name: "GoogleMobileAds", url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", .exact("10.10.0"))
    ],
    targets: [
        .binaryTarget(
            name: "OMSDK_Microsoft",
            path: "sdk/sourcefiles/Viewability/dynamic_framework/OMSDK_Microsoft.xcframework"
        ),
        .target(
            name: "EplanningSDK",
            dependencies: ["OMSDK_Microsoft"],
            path: "sdk/sourcefiles",
            exclude: [
                "Resources/Info.plist",
                "Resources/ANSDKResources.bundle",
                "Viewability/dynamic_framework/OMSDK_Microsoft.xcframework",
                "Viewability/static_framework/OMSDK-Static_Microsoft.xcframework",
                "macOS/"
            ],
            resources: [
                .process("Resources")
            ],
            publicHeadersPath: "./public-headers",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("./Categories"),
                .headerSearchPath("./internal"),
                .headerSearchPath("./internal/config"),
                .headerSearchPath("./internal/MRAID"),
                .headerSearchPath("./native"),
                .headerSearchPath("./native/internal"),
                .headerSearchPath("./native/internal/NativeRendering"),
                .headerSearchPath("./video"),
                .headerSearchPath("./Viewability"),
            ]
        ),
        .target(
            name: "GoogleMediationAdapter",
            dependencies: ["EplanningSDK","GoogleMobileAds"],
            path: "mediation/mediatedviews/GoogleAdMob",
            cSettings: [
                .headerSearchPath("./"),
            ]
        )
    ]
)