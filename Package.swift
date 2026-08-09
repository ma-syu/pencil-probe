// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PencilProbe",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "pencil-probe",
            dependencies: ["Core"],
            path: "Sources/IO"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        ),
    ]
)
