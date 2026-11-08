// swift-tools-version: 6.0
import PackageDescription

/// The calculation logic, separate from the app.
///
/// Everything that computes lives here, as plain functions over value types,
/// so its tests run without a host app, in seconds. Nothing in here may
/// import SwiftUI.
let package = Package(
    name: "SourdoughKit",
    products: [
        .library(name: "SourdoughKit", targets: ["SourdoughKit"]),
    ],
    targets: [
        .target(name: "SourdoughKit"),
        .testTarget(name: "SourdoughKitTests", dependencies: ["SourdoughKit"]),
    ]
)
