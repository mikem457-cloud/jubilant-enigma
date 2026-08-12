// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScheduleEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScheduleEngine", targets: ["ScheduleEngine"])
    ],
    targets: [
        // Depends on nothing — see 01-ARCHITECTURE.md §2. Keep it that way.
        .target(name: "ScheduleEngine"),
        .testTarget(name: "ScheduleEngineTests", dependencies: ["ScheduleEngine"]),
    ]
)
