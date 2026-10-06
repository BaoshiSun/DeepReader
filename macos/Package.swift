// swift-tools-version: 5.9
// SPDX-License-Identifier: AGPL-3.0-or-later
import PackageDescription

let package = Package(
    name: "DeepReader",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "DeepReader", targets: ["DeepReader"])],
    targets: [
        .target(name: "DeepReaderCore"),
        .target(name: "DeepReaderDesktop", dependencies: ["DeepReaderCore"]),
        .executableTarget(name: "DeepReader", dependencies: ["DeepReaderDesktop"]),
        .testTarget(name: "DeepReaderTests", dependencies: ["DeepReaderCore", "DeepReaderDesktop"])
    ],
    swiftLanguageVersions: [.v5]
)
