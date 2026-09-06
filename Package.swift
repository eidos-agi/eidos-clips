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
        .target(name: "ClipsModules"),
        .target(name: "ClipsMedia", dependencies: ["ClipsCore", "ClipsModules"]),
        .target(name: "ClipsFixtures", dependencies: ["ClipsCore"]),
        .executableTarget(name: "EidosClips", dependencies: ["ClipsCore", "ClipsMedia", "ClipsModules"],
                          linkerSettings: [.linkedFramework("AVKit")]),
        .executableTarget(name: "ClipsProbe", dependencies: ["ClipsCore", "ClipsMedia", "ClipsFixtures"]),
        .testTarget(name: "ClipsModulesTests", dependencies: ["ClipsModules"]),
        .testTarget(name: "ClipsCoreTests", dependencies: ["ClipsCore"]),
        .testTarget(name: "ClipsMediaTests", dependencies: ["ClipsCore", "ClipsMedia", "ClipsFixtures", "ClipsModules"]),
    ]
)
