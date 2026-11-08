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
        // The tips and tricks texts are Markdown files in `Sources/SourdoughKit/Tips`.
        .target(name: "SourdoughKit", resources: [.copy("Tips")]),
        .testTarget(name: "SourdoughKitTests", dependencies: ["SourdoughKit"]),
    ]
)
