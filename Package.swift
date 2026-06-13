// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AriaPilot",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AriaPilot",
            path: "Sources/AriaPilot"
        )
    ]
)
