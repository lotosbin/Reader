// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RSSReader",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RSSReader",
            targets: ["RSSReader"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2"),
    ],
    targets: [
        .target(
            name: "RSSReader",
            dependencies: ["FeedKit"]),
        .testTarget(
            name: "RSSReaderTests",
            dependencies: ["RSSReader"]),
    ]
)
