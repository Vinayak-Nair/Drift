// swift-tools-version:5.9
import PackageDescription

// DriftKit is the pure, testable core (audio, transcription, cleanup, pipeline).
// The macOS app target lives in Sources/DriftApp and is built by the Xcode
// project generated from project.yml (it depends on this package's DriftKit).
let package = Package(
    name: "Drift",
    platforms: [.macOS(.v14)], // WhisperKit requires macOS 14+
    products: [
        .library(name: "DriftKit", targets: ["DriftKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "0.9.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.4"),
    ],
    targets: [
        .target(
            name: "DriftKit",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/DriftKit"
        ),
        .testTarget(
            name: "DriftKitTests",
            dependencies: ["DriftKit"],
            path: "Tests/DriftKitTests"
        ),
    ]
)
