import HALDomain

struct ApplicationStoryModel: Equatable {
  struct Connection: Identifiable, Equatable {
    let id: RelationshipID
    let entity: Entity
    let relationship: Relationship
  }

  let application: Entity
  let processes: [Connection]
  let startupItems: [Connection]
  let associatedItems: [Connection]
  let owners: [Connection]
  let provenance: [Detail]
  let unknowns: [String]

  init(application: Entity, graph: SystemGraph) {
    self.application = application
    let connections = graph.relationships(connectedTo: application.id).compactMap {
      relationship -> Connection? in
      let counterpartID =
        relationship.source == application.id ? relationship.target : relationship.source
      guard let entity = graph.entity(counterpartID) else { return nil }
      return Connection(id: relationship.id, entity: entity, relationship: relationship)
    }
    processes = connections.filter { $0.entity.type == .process }
    startupItems = connections.filter { $0.entity.type == .persistence }
    associatedItems = connections.filter {
      [.file, .package, .shellFramework].contains($0.entity.type)
    }
    owners = connections.filter {
      $0.relationship.target == application.id
        && [.packageManager, .package].contains($0.entity.type)
    }
    provenance = application.details.filter {
      let label = $0.label.lowercased()
      return label.contains("signature") || label.contains("team")
        || label.contains("receipt") || label.contains("origin")
        || label.contains("installed with") || label.contains("download")
        || label.contains("package manager")
    }

    var missing: [String] = []
    if processes.isEmpty {
      missing.append("HAL did not observe a running process for this application.")
    }
    if startupItems.isEmpty {
      missing.append("HAL did not find a connected startup declaration.")
    }
    if provenance.isEmpty && owners.isEmpty {
      missing.append("Installation-source evidence is unavailable.")
    }
    if associatedItems.isEmpty {
      missing.append("No strongly associated support locations or tools were observed.")
    }
    if connections.contains(where: { $0.relationship.confidence == .ambiguous }) {
      missing.append(
        "At least one connection remains ambiguous; HAL shows it without claiming ownership.")
    }
    unknowns = missing
  }

  var currentState: String {
    application.details.first { $0.label == "Current state" }?.value
      ?? (processes.isEmpty ? "Not observed running" : "Observed running")
  }

  var sourceSummary: String {
    if let installed = application.details.first(where: { $0.label == "Installed with" }) {
      return installed.value
    }
    if let owner = owners.first {
      return "Managed by \(owner.entity.name)"
    }
    if let provenance = provenance.first {
      return "\(provenance.label): \(provenance.value)"
    }
    return "Source evidence unavailable"
  }

  var confidenceSummary: String {
    let connected = processes + startupItems + associatedItems + owners
    guard !connected.isEmpty else { return "No connected evidence" }
    if connected.contains(where: { $0.relationship.confidence == .ambiguous }) {
      return "Some connections are uncertain"
    }
    return "Evidence-backed connections"
  }
}
