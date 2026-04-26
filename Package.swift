// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "ControlXVoz",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "ControlXVoz", targets: ["ControlXVoz"])
    ],
    targets: [
        .target(name: "ControlXVoz"),
        .testTarget(name: "ControlXVozTests", dependencies: ["ControlXVoz"])
    ]
)
