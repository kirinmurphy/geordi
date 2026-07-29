import Foundation

public enum EntityType: String, CaseIterable, Codable, Sendable {
  case application
  case process
  case file
  case persistence
  case resource
  case incident
  case event
  case packageManager
  case shellFramework
  case package

  public var label: String {
    switch self {
    case .application: "Applications"
    case .process: "Processes"
    case .file: "Files"
    case .persistence: "Persistence"
    case .resource: "Resources"
    case .incident: "Incidents"
    case .event: "Events"
    case .packageManager: "Package managers"
    case .shellFramework: "Shell frameworks"
    case .package: "Packages"
    }
  }
}

public struct EntityID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}

public struct Entity: Identifiable, Hashable, Codable, Sendable {
  public let id: EntityID
  public let type: EntityType
  public let name: String
  public let summary: String
  public let details: [Detail]
  public let instances: [EntityInstance]
  public let presentation: EntityPresentation?

  private enum CodingKeys: String, CodingKey {
    case id, type, name, summary, details, instances, presentation
  }

  public init(
    id: EntityID,
    type: EntityType,
    name: String,
    summary: String,
    details: [Detail] = [],
    instances: [EntityInstance] = [],
    presentation: EntityPresentation? = nil
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.summary = summary
    self.details = details
    self.instances = instances
    self.presentation = presentation
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(EntityID.self, forKey: .id)
    type = try container.decode(EntityType.self, forKey: .type)
    name = try container.decode(String.self, forKey: .name)
    summary = try container.decode(String.self, forKey: .summary)
    details = try container.decode([Detail].self, forKey: .details)
    instances = try container.decodeIfPresent([EntityInstance].self, forKey: .instances) ?? []
    presentation = try container.decodeIfPresent(
      EntityPresentation.self,
      forKey: .presentation
    )
  }
}

public enum EntityPresentationTint: String, CaseIterable, Codable, Sendable {
  case accent
  case blue
  case cyan
  case green
  case mint
  case orange
  case purple
  case red
}

public struct EntityPresentation: Hashable, Codable, Sendable {
  public let symbol: String
  public let tint: EntityPresentationTint
  public let subtitle: String?
  public let trailingDetailLabel: String?

  public init(
    symbol: String,
    tint: EntityPresentationTint = .accent,
    subtitle: String? = nil,
    trailingDetailLabel: String? = nil
  ) {
    self.symbol = symbol
    self.tint = tint
    self.subtitle = subtitle
    self.trailingDetailLabel = trailingDetailLabel
  }
}

public struct Detail: Identifiable, Hashable, Codable, Sendable {
  public var id: String { label }
  public let label: String
  public let value: String

  public init(_ label: String, _ value: String) {
    self.label = label
    self.value = value
  }
}

/// One observed instance of a logical entity, containing only attributes whose
/// values are not shared by every instance.
public struct EntityInstance: Identifiable, Hashable, Codable, Sendable {
  public let id: String
  public let details: [Detail]

  public init(id: String, details: [Detail]) {
    self.id = id
    self.details = details
  }
}

public struct EntityInstancePartition: Hashable, Sendable {
  public let sharedDetails: [Detail]
  public let instances: [EntityInstance]

  public init(detailsByInstance: [(id: String, details: [Detail])]) {
    guard let first = detailsByInstance.first else {
      sharedDetails = []
      instances = []
      return
    }

    let labels = Set(detailsByInstance.flatMap { $0.details.map(\.label) })
    let sharedLabels = labels.filter { label in
      let values = detailsByInstance.map { instance in
        instance.details.first { $0.label == label }?.value
      }
      return values.allSatisfy { $0 != nil } && Set(values.compactMap { $0 }).count == 1
    }

    sharedDetails = first.details.filter { sharedLabels.contains($0.label) }
    instances = detailsByInstance.map { instance in
      EntityInstance(
        id: instance.id,
        details: instance.details.filter { !sharedLabels.contains($0.label) }
      )
    }
  }
}
