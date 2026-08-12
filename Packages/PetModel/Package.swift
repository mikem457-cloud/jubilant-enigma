// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PetModel",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PetModel", targets: ["PetModel"])
    ],
    dependencies: [
        // Value types only (DoseSchedule, DateOnly, TimeOfDay). The engine
        // itself never imports PetModel — that direction stays forbidden.
        .package(path: "../ScheduleEngine")
    ],
    targets: [
        // SwiftData models are #if canImport(SwiftData) — this package builds
        // to its enums/value types on Linux and to the full model on Apple
        // platforms. Model-layer tests (cascades, orphan reaping) live in the
        // app project where a ModelContainer exists.
        .target(name: "PetModel", dependencies: ["ScheduleEngine"])
    ]
)
