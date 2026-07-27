// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "HAL",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "HALDomain", targets: ["HALDomain"]),
    .library(name: "HALCollectors", targets: ["HALCollectors"]),
    .library(name: "HALFixtures", targets: ["HALFixtures"]),
    .library(name: "HALVisualization", targets: ["HALVisualization"]),
    .executable(name: "HALApp", targets: ["HALApp"]),
    .executable(name: "hal-fixture-validator", targets: ["HALFixtureValidator"]),
  ],
  targets: [
    .target(name: "HALDomain"),
    .target(name: "HALCollectors", dependencies: ["HALDomain"]),
    .target(name: "HALFixtures", dependencies: ["HALDomain"]),
    .target(name: "HALVisualization", dependencies: ["HALDomain"]),
    .executableTarget(
      name: "HALApp",
      dependencies: ["HALDomain", "HALFixtures", "HALVisualization"]
    ),
    .executableTarget(
      name: "HALFixtureValidator",
      dependencies: ["HALDomain", "HALFixtures"]
    ),
    .testTarget(name: "HALDomainTests", dependencies: ["HALDomain"]),
    .testTarget(
      name: "HALCollectorsTests",
      dependencies: ["HALCollectors", "HALDomain"]
    ),
    .testTarget(
      name: "HALFixturesTests",
      dependencies: ["HALDomain", "HALFixtures"]
    ),
    .testTarget(
      name: "HALVisualizationTests",
      dependencies: ["HALDomain", "HALFixtures", "HALVisualization"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
