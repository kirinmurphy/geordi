// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "HAL",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "HALDomain", targets: ["HALDomain"]),
    .library(name: "HALManifestKit", targets: ["HALManifestKit"]),
    .library(name: "HALCollectors", targets: ["HALCollectors"]),
    .library(name: "HALDataSource", targets: ["HALDataSource"]),
    .library(name: "HALProfileSchema", targets: ["HALProfileSchema"]),
    .library(name: "HALFixtures", targets: ["HALFixtures"]),
    .library(name: "HALVisualization", targets: ["HALVisualization"]),
    .executable(name: "HALApp", targets: ["HALApp"]),
    .executable(name: "hal-fixture-validator", targets: ["HALFixtureValidator"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/ajevans99/swift-json-schema",
      from: "0.13.1"
    )
  ],
  targets: [
    .target(name: "HALDomain"),
    .target(
      name: "HALManifestKit",
      dependencies: [
        .product(name: "JSONSchema", package: "swift-json-schema")
      ]
    ),
    .target(
      name: "HALCollectors",
      dependencies: ["HALDomain", "HALManifestKit"],
      resources: [.process("Resources")]
    ),
    .target(name: "HALDataSource", dependencies: ["HALDomain"]),
    .target(
      name: "HALProfileSchema",
      dependencies: [
        "HALDomain",
        "HALManifestKit",
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "HALFixtures",
      dependencies: ["HALDomain", "HALManifestKit", "HALProfileSchema"],
      resources: [.process("Resources")]
    ),
    .target(
      name: "HALVisualization",
      dependencies: ["HALDomain", "HALManifestKit"],
      resources: [.process("Resources")]
    ),
    .executableTarget(
      name: "HALApp",
      dependencies: [
        "HALCollectors", "HALDataSource", "HALDomain", "HALFixtures", "HALVisualization",
      ]
    ),
    .executableTarget(
      name: "HALFixtureValidator",
      dependencies: ["HALDomain", "HALFixtures", "HALProfileSchema"]
    ),
    .testTarget(name: "HALDomainTests", dependencies: ["HALDomain"]),
    .testTarget(
      name: "HALDataSourceTests",
      dependencies: ["HALDataSource", "HALDomain"]
    ),
    .testTarget(
      name: "HALProfileSchemaTests",
      dependencies: ["HALDomain", "HALProfileSchema"]
    ),
    .testTarget(
      name: "HALCollectorsTests",
      dependencies: ["HALCollectors", "HALDomain", "HALManifestKit"]
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
