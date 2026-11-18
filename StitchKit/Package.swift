// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StitchKit",
    platforms: [
        // Liquid Glass is a macOS 26 / iOS 26 feature and the chrome is built on it, so the
        // kit matches the app's deployment target rather than trailing it.
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "StitchKit", targets: ["StitchKit"]),
    ],
    targets: [
        .target(name: "StitchKit"),
        .testTarget(name: "StitchKitTests", dependencies: ["StitchKit"]),
    ]
)
