// swift-tools-version: 6.3
import PackageDescription
import Foundation

let workspaceRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let circuiteFoundationDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("CircuiteFoundation/Package.swift").path
)
    ? .package(path: "../CircuiteFoundation")
    : .package(
        url: "https://github.com/1amageek/CircuiteFoundation.git",
        revision: "2ec6ee13a89ac6885be3c26b41a9ee0ef89948ac"
    )

let signoffToolSupportDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("SignoffToolSupport/Package.swift").path
)
    ? .package(path: "../SignoffToolSupport")
    : .package(
        url: "https://github.com/1amageek/SignoffToolSupport.git",
        revision: "7bfd1864edd147c59a1dc79e58f297120d165323"
    )

let semiconductorLayoutDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("semiconductor-layout/Package.swift").path
)
    ? .package(path: "../semiconductor-layout")
    : .package(
        url: "https://github.com/1amageek/semiconductor-layout.git",
        revision: "eb4f8ac93dbe4c35410ae55e6bb00794376c8333"
    )

let package = Package(
    name: "DRCEngine",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DRCCore", targets: ["DRCCore"]),
        .library(name: "DRCFoundryImport", targets: ["DRCFoundryImport"]),
        .library(name: "DRCNative", targets: ["DRCNative"]),
        .library(name: "DRCParsers", targets: ["DRCParsers"]),
        .library(name: "DRCAdapters", targets: ["DRCAdapters"]),
        .library(name: "DRCPersistence", targets: ["DRCPersistence"]),
        .library(name: "DRCRuntime", targets: ["DRCRuntime"]),
        .library(name: "DRCEngine", targets: ["DRCEngine"]),
        .library(name: "DRCCLICore", targets: ["DRCCLICore"]),
        .executable(name: "drcengine", targets: ["DRCCLI"]),
    ],
    dependencies: [
        circuiteFoundationDependency,
        signoffToolSupportDependency,
        semiconductorLayoutDependency,
    ],
    targets: [
        .target(
            name: "DRCCore",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
            ]
        ),
        .target(
            name: "DRCFoundryImport",
            dependencies: [
                .product(name: "LayoutTech", package: "semiconductor-layout"),
            ]
        ),
        .target(
            name: "DRCNative",
            dependencies: [
                "DRCCore",
                "DRCFoundryImport",
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "LayoutTech", package: "semiconductor-layout"),
                .product(name: "LayoutVerify", package: "semiconductor-layout"),
                .product(name: "LayoutIO", package: "semiconductor-layout"),
            ],
            resources: [.copy("Resources")]
        ),
        .target(name: "DRCParsers", dependencies: ["DRCCore"]),
        .target(
            name: "DRCAdapters",
            dependencies: [
                "DRCCore",
                "DRCParsers",
                .product(name: "SignoffToolSupport", package: "SignoffToolSupport"),
            ],
            resources: [.copy("Resources/drc.tcl")]
        ),
        .target(name: "DRCPersistence", dependencies: ["DRCCore"]),
        .target(
            name: "DRCRuntime",
            dependencies: [
                "DRCCore",
                "DRCNative",
                "DRCAdapters",
                "DRCPersistence",
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "LayoutTech", package: "semiconductor-layout"),
                .product(name: "LayoutIO", package: "semiconductor-layout"),
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
            ]
        ),
        .target(
            name: "DRCEngine",
            dependencies: ["DRCCore", "DRCFoundryImport", "DRCNative", "DRCParsers", "DRCAdapters", "DRCPersistence", "DRCRuntime"]
        ),
        .target(
            name: "DRCCLICore",
            dependencies: [
                "DRCEngine",
                .product(name: "SignoffToolSupport", package: "SignoffToolSupport"),
            ]
        ),
        .executableTarget(name: "DRCCLI", dependencies: ["DRCCLICore"], path: "Sources/DRCCLI"),
        .testTarget(name: "DRCAdaptersTests", dependencies: ["DRCAdapters", "DRCCore"]),
        .testTarget(
            name: "DRCNativeTests",
            dependencies: [
                "DRCNative",
                "DRCCore",
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "LayoutTech", package: "semiconductor-layout"),
                .product(name: "LayoutIO", package: "semiconductor-layout"),
            ]
        ),
        .testTarget(name: "DRCParsersTests", dependencies: ["DRCParsers", "DRCCore"]),
        .testTarget(name: "DRCRuntimeTests", dependencies: ["DRCRuntime", "DRCCore"]),
        .testTarget(
            name: "DRCCLICoreTests",
            dependencies: [
                "DRCCLICore",
                "DRCNative",
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "LayoutTech", package: "semiconductor-layout"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
