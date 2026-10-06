// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StitchKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "StitchKit", targets: ["StitchKit"]),
    ],
    targets: [
        .target(name: "StitchKit"),
        .testTarget(name: "StitchKitTests", dependencies: ["StitchKit"]),
    ]
)
