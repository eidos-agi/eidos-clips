// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EidosClips",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClipsCore", targets: ["ClipsCore"]),
        .library(name: "ClipsMedia", targets: ["ClipsMedia"]),
        .executable(name: "EidosClips", targets: ["EidosClips"]),
        .executable(name: "clips-probe", targets: ["ClipsProbe"]),
    ],
    targets: [
        .target(name: "ClipsCore"),
        .target(name: "ClipsMedia", dependencies: ["ClipsCore"]),
        .target(name: "ClipsFixtures", dependencies: ["ClipsCore"]),
        .executableTarget(name: "EidosClips", dependencies: ["ClipsCore", "ClipsMedia"]),
        .executableTarget(name: "ClipsProbe", dependencies: ["ClipsCore", "ClipsMedia", "ClipsFixtures"]),
        .testTarget(name: "ClipsCoreTests", dependencies: ["ClipsCore"]),
        .testTarget(name: "ClipsMediaTests", dependencies: ["ClipsCore", "ClipsMedia", "ClipsFixtures"]),
    ]
)
