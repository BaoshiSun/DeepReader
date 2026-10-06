// swift-tools-version: 5.9
// SPDX-License-Identifier: AGPL-3.0-or-later
import PackageDescription

let package = Package(
    name: "DeepReader",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "DeepReader", targets: ["DeepReader"])],
    targets: [
        .systemLibrary(name: "CArchive"),
        .target(name: "CMobi", path: "Vendor/libmobi", exclude: ["COPYING", "AUTHORS", "README.md", "ORIGIN.json"],
            publicHeadersPath: "include", cSettings: [.define("HAVE_STRDUP"), .define("PACKAGE_VERSION", to: "\"0.12\"")],
            linkerSettings: [.linkedLibrary("z")]),
        .target(name: "DeepReaderCore", dependencies: ["CArchive", "CMobi"]),
        .target(name: "DeepReaderDesktop", dependencies: ["DeepReaderCore"]),
        .executableTarget(name: "DeepReader", dependencies: ["DeepReaderDesktop"]),
        .testTarget(name: "DeepReaderTests", dependencies: ["DeepReaderCore", "DeepReaderDesktop"])
    ],
    swiftLanguageVersions: [.v5]
)
