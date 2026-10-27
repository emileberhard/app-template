// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "StarterCore",
    products: [.library(name: "StarterCore", targets: ["StarterCore"])],
    targets: [
        .target(name: "StarterCore"),
        .testTarget(name: "StarterCoreTests", dependencies: ["StarterCore"]),
    ],
    swiftLanguageModes: [.v6]
)
