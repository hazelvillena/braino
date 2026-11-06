// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Braino", platforms: [.macOS(.v14)], targets: [.executableTarget(name: "Braino", path: "Sources", swiftSettings: [.swiftLanguageMode(.v5)])])
