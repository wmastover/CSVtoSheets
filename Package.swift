// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CSVtoSheets",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "CSVtoSheets",
            path: "Sources"),
    ]
)
