// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "aria2bar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "aria2bar",
            path: "Sources/aria2bar"
        )
    ]
)
