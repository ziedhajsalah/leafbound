// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Leafbound",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Leafbound", targets: ["Leafbound"])],
    targets: [
        .target(name: "LeafboundCore"),
        .executableTarget(name: "Leafbound", dependencies: ["LeafboundCore"]),
        .testTarget(name: "LeafboundCoreTests", dependencies: ["LeafboundCore"])
    ]
)
