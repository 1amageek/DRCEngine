// swift-tools-version: 6.3
import PackageDescription

let circuiteFoundationDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/CircuiteFoundation.git",
    exact: "26.812.0"
)

let signoffToolSupportDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/SignoffToolSupport.git",
    exact: "26.812.0"
)

let semiconductorLayoutDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/semiconductor-layout.git",
    revision: "aada7526e4408c75f1940d3aa7372aaf523e2a42"
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
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
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
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
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
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "SignoffToolSupport", package: "SignoffToolSupport"),
            ],
            resources: [.copy("Resources/drc.tcl")]
        ),
        .target(
            name: "DRCPersistence",
            dependencies: [
                "DRCCore",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
            ]
        ),
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
        .testTarget(
            name: "DRCRuntimeTests",
            dependencies: [
                "DRCRuntime",
                "DRCCore",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "DRCCLICoreTests",
            dependencies: [
                "DRCCLICore",
                "DRCAdapters",
                "DRCFoundryImport",
                "DRCNative",
                .product(name: "LayoutCore", package: "semiconductor-layout"),
                .product(name: "LayoutTech", package: "semiconductor-layout"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
