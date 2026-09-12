// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "geordi",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "GeordiDomain", targets: ["GeordiDomain"]),
    .library(name: "GeordiManifestKit", targets: ["GeordiManifestKit"]),
    .library(name: "GeordiCollectors", targets: ["GeordiCollectors"]),
    .library(name: "GeordiDataSource", targets: ["GeordiDataSource"]),
    .library(name: "GeordiProfileSchema", targets: ["GeordiProfileSchema"]),
    .library(name: "GeordiFixtures", targets: ["GeordiFixtures"]),
    .library(name: "GeordiVisualization", targets: ["GeordiVisualization"]),
    .executable(name: "GeordiApp", targets: ["GeordiApp"]),
    .executable(name: "geordi-fixture-validator", targets: ["GeordiFixtureValidator"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/ajevans99/swift-json-schema",
      from: "0.13.1"
    )
  ],
  targets: [
    .target(
      name: "GeordiDomain",
      dependencies: ["GeordiManifestKit"],
      resources: [.process("Resources")]
    ),
    .target(
      name: "GeordiManifestKit",
      dependencies: [
        .product(name: "JSONSchema", package: "swift-json-schema")
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "GeordiCollectors",
      dependencies: ["GeordiDomain", "GeordiManifestKit"],
      resources: [.process("Resources")]
    ),
    .target(name: "GeordiDataSource", dependencies: ["GeordiDomain"]),
    .target(
      name: "GeordiProfileSchema",
      dependencies: [
        "GeordiDomain",
        "GeordiManifestKit",
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "GeordiFixtures",
      dependencies: ["GeordiDomain", "GeordiManifestKit", "GeordiProfileSchema"],
      resources: [.process("Resources")]
    ),
    .target(
      name: "GeordiVisualization",
      dependencies: ["GeordiDomain", "GeordiManifestKit"],
      resources: [.process("Resources")]
    ),
    .executableTarget(
      name: "GeordiApp",
      dependencies: [
        "GeordiCollectors", "GeordiDataSource", "GeordiDomain", "GeordiFixtures",
        "GeordiVisualization",
      ]
    ),
    .executableTarget(
      name: "GeordiFixtureValidator",
      dependencies: ["GeordiDomain", "GeordiFixtures", "GeordiProfileSchema"]
    ),
    .testTarget(name: "GeordiDomainTests", dependencies: ["GeordiDomain"]),
    .testTarget(name: "GeordiManifestKitTests", dependencies: ["GeordiManifestKit"]),
    .testTarget(
      name: "GeordiDataSourceTests",
      dependencies: ["GeordiDataSource", "GeordiDomain"]
    ),
    .testTarget(
      name: "GeordiProfileSchemaTests",
      dependencies: ["GeordiDomain", "GeordiProfileSchema"]
    ),
    .testTarget(
      name: "GeordiCollectorsTests",
      dependencies: ["GeordiCollectors", "GeordiDomain", "GeordiManifestKit"]
    ),
    .testTarget(
      name: "GeordiFixturesTests",
      dependencies: ["GeordiDomain", "GeordiFixtures"]
    ),
    .testTarget(
      name: "GeordiVisualizationTests",
      dependencies: ["GeordiDomain", "GeordiFixtures", "GeordiVisualization"]
    ),
    .testTarget(
      name: "GeordiAppTests",
      dependencies: ["GeordiApp", "GeordiCollectors", "GeordiDataSource", "GeordiDomain"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
