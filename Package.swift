// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HandGestureApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HandGestureApp",
            targets: ["HandGestureApp"]
        ),
        .executable(
            name: "TestRunner",
            targets: ["TestRunner"]
        ),
        .library(
            name: "HandGestureAppCore",
            targets: ["HandGestureAppCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HandGestureAppCore",
            dependencies: [],
            path: "Sources/HandGestureAppCore",
            exclude: ["Resources/Info.plist"]
        ),
        .executableTarget(
            name: "HandGestureApp",
            dependencies: ["HandGestureAppCore"],
            path: "Sources/HandGestureApp"
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["HandGestureAppCore"],
            path: "Sources/TestRunner"
        )
    ]
)

