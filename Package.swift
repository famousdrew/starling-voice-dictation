// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Starling",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Starling", targets: ["Starling"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Starling",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/Starling"
        )
    ]
)
