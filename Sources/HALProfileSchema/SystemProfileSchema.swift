import Foundation
import HALDomain
import JSONSchema

public enum SystemProfileSchema {
  public static let currentVersion = 1

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "system-profile.schema",
        withExtension: "json"
      )
    else {
      throw SystemProfileSchemaError.schemaUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data) throws -> SystemProfileDocument {
    try validateAgainstDeclarativeSchema(data)
    let decoder = JSONDecoder()
    let document: SystemProfileDocument
    do {
      document = try decoder.decode(SystemProfileDocument.self, from: data)
    } catch {
      throw SystemProfileSchemaError.decoding(String(describing: error))
    }
    try document.validate()
    return document
  }

  private static func validateAgainstDeclarativeSchema(_ data: Data) throws {
    do {
      let schemaText = String(decoding: try declarativeSchemaData(), as: UTF8.self)
      let instanceText = String(decoding: data, as: UTF8.self)
      let schema = try Schema(instance: schemaText)
      let result = try schema.validate(instance: instanceText)
      guard result.isValid else {
        throw SystemProfileSchemaError.declarativeValidation(
          String(describing: result.errors)
        )
      }
    } catch let error as SystemProfileSchemaError {
      throw error
    } catch {
      throw SystemProfileSchemaError.declarativeValidation(
        String(describing: error)
      )
    }
  }
}

public struct SystemProfileDocument: Hashable, Codable, Sendable {
  public let schemaVersion: Int
  public let id: String
  public let name: String
  public let summary: String
  public let entities: [ProfileEntity]
  public let relationships: [ProfileRelationship]

  public init(
    schemaVersion: Int,
    id: String,
    name: String,
    summary: String,
    entities: [ProfileEntity],
    relationships: [ProfileRelationship]
  ) {
    self.schemaVersion = schemaVersion
    self.id = id
    self.name = name
    self.summary = summary
    self.entities = entities
    self.relationships = relationships
  }

  public func validate() throws {
    guard schemaVersion == SystemProfileSchema.currentVersion else {
      throw SystemProfileSchemaError.unsupportedVersion(schemaVersion)
    }
    guard !id.isEmpty, !name.isEmpty, !summary.isEmpty else {
      throw SystemProfileSchemaError.missingRequiredValue("$")
    }
    let entityIDs = entities.map(\.id)
    guard Set(entityIDs).count == entityIDs.count else {
      throw SystemProfileSchemaError.duplicateEntity
    }
    let relationshipIDs = relationships.map(\.id)
    guard Set(relationshipIDs).count == relationshipIDs.count else {
      throw SystemProfileSchemaError.duplicateRelationship
    }
    let validEntityIDs = Set(entityIDs)
    for relationship in relationships {
      guard validEntityIDs.contains(relationship.source) else {
        throw SystemProfileSchemaError.missingEndpoint(
          relationship: relationship.id,
          endpoint: relationship.source
        )
      }
      guard validEntityIDs.contains(relationship.target) else {
        throw SystemProfileSchemaError.missingEndpoint(
          relationship: relationship.id,
          endpoint: relationship.target
        )
      }
      guard !relationship.evidence.isEmpty else {
        throw SystemProfileSchemaError.missingEvidence(relationship.id)
      }
    }
  }

  public func graph() -> SystemGraph {
    SystemGraph(
      metadata: FixtureMetadata(
        id: id,
        version: schemaVersion,
        name: name,
        summary: summary
      ),
      entities: entities.map(\.entity),
      relationships: relationships.map(\.relationship)
    )
  }
}

public struct ProfileEntity: Hashable, Codable, Sendable {
  public let id: String
  public let type: EntityType
  public let name: String
  public let summary: String
  public let details: [ProfileDetail]

  public init(
    id: String,
    type: EntityType,
    name: String,
    summary: String,
    details: [ProfileDetail] = []
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.summary = summary
    self.details = details
  }

  fileprivate var entity: Entity {
    Entity(
      id: EntityID(id),
      type: type,
      name: name,
      summary: summary,
      details: details.map { Detail($0.label, $0.value) }
    )
  }
}

public struct ProfileDetail: Hashable, Codable, Sendable {
  public let label: String
  public let value: String

  public init(label: String, value: String) {
    self.label = label
    self.value = value
  }
}

public struct ProfileRelationship: Hashable, Codable, Sendable {
  public let id: String
  public let source: String
  public let target: String
  public let type: RelationshipType
  public let confidence: Confidence
  public let explanation: String
  public let evidence: [ProfileEvidence]

  public init(
    id: String,
    source: String,
    target: String,
    type: RelationshipType,
    confidence: Confidence,
    explanation: String,
    evidence: [ProfileEvidence]
  ) {
    self.id = id
    self.source = source
    self.target = target
    self.type = type
    self.confidence = confidence
    self.explanation = explanation
    self.evidence = evidence
  }

  fileprivate var relationship: Relationship {
    Relationship(
      id: RelationshipID(id),
      source: EntityID(source),
      target: EntityID(target),
      type: type,
      confidence: confidence,
      explanation: explanation,
      evidence: evidence.map(\.domainEvidence)
    )
  }
}

public struct ProfileEvidence: Hashable, Codable, Sendable {
  public let id: String
  public let kind: EvidenceKind
  public let summary: String
  public let source: String
  public let observationID: ObservationID?
  public let observedAt: Date?
  public let ruleID: String?
  public let ruleVersion: Int?

  public init(
    id: String,
    kind: EvidenceKind,
    summary: String,
    source: String,
    observationID: ObservationID? = nil,
    observedAt: Date? = nil,
    ruleID: String? = nil,
    ruleVersion: Int? = nil
  ) {
    self.id = id
    self.kind = kind
    self.summary = summary
    self.source = source
    self.observationID = observationID
    self.observedAt = observedAt
    self.ruleID = ruleID
    self.ruleVersion = ruleVersion
  }

  fileprivate var domainEvidence: Evidence {
    Evidence(
      id: id,
      kind: kind,
      summary: summary,
      source: source,
      observationID: observationID,
      observedAt: observedAt,
      ruleID: ruleID,
      ruleVersion: ruleVersion
    )
  }
}

public enum SystemProfileSchemaError: Error, Equatable, CustomStringConvertible {
  case decoding(String)
  case schemaUnavailable
  case declarativeValidation(String)
  case unsupportedVersion(Int)
  case missingRequiredValue(String)
  case duplicateEntity
  case duplicateRelationship
  case missingEndpoint(relationship: String, endpoint: String)
  case missingEvidence(String)

  public var description: String {
    switch self {
    case .decoding(let message): "Profile decoding failed: \(message)"
    case .schemaUnavailable: "The declarative system-profile schema is unavailable."
    case .declarativeValidation(let message):
      "Profile failed declarative schema validation: \(message)"
    case .unsupportedVersion(let version): "Unsupported profile schema version \(version)."
    case .missingRequiredValue(let path): "A required value is missing at \(path)."
    case .duplicateEntity: "Profile contains a duplicate entity identifier."
    case .duplicateRelationship: "Profile contains a duplicate relationship identifier."
    case .missingEndpoint(let relationship, let endpoint):
      "Relationship \(relationship) references missing endpoint \(endpoint)."
    case .missingEvidence(let relationship):
      "Relationship \(relationship) has no evidence."
    }
  }
}
