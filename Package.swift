// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhoopWidget",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WhoopWidget",
            targets: ["WhoopWidget"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WhoopWidget",
            path: "Sources"
        )
    ]
)
