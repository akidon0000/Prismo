// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Prismo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Prismo",
            path: "Prismo/Sources"
        ),
        .testTarget(
            name: "PrismoTests",
            dependencies: ["Prismo"],
            path: "Prismo/Tests"
        ),
    ]
)
