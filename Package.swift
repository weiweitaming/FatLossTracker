// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FatLossTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FatLossTracker", targets: ["FatLossTracker"])
    ],
    targets: [
        .executableTarget(
            name: "FatLossTracker",
            path: "Sources"
        ),
        .testTarget(
            name: "FatLossTrackerTests",
            dependencies: ["FatLossTracker"],
            path: "Tests"
        )
    ]
)
