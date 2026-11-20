// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "podsstat",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "podsstat", targets: ["podsstat"]),
        .library(name: "PodsStatsCore", targets: ["PodsStatsCore"])
    ],
    targets: [
        .target(name: "PodsStatsCore", path: "Sources/PodsStatsCore"),
        .executableTarget(name: "podsstat", dependencies: ["PodsStatsCore"], path: "Sources/podsstat")
    ]
)
