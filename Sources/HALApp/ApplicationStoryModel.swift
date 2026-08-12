import HALDomain

struct ApplicationStoryModel: Equatable {
  enum Status: Equatable {
    case running
    case offline
    case warnings(Int)
    case unhealthy

    var label: String {
      switch self {
      case .running: "Running"
      case .offline: "Offline"
      case .warnings(let count): "\(count) warning\(count == 1 ? "" : "s")"
      case .unhealthy: "Application unhealthy"
      }
    }
  }

  struct Connection: Identifiable, Equatable {
    let id: RelationshipID
    let entity: Entity
    let relationship: Relationship
  }

  let application: Entity
  let processes: [Connection]
  let startupItems: [Connection]
  let associatedItems: [Connection]
  let possibleAssociatedItems: [Connection]
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
    let associationCandidates = connections.filter {
      [.file, .package, .shellFramework].contains($0.entity.type)
    }
    associatedItems = associationCandidates.filter {
      [.confirmed, .high].contains($0.relationship.confidence)
    }
    possibleAssociatedItems = associationCandidates.filter {
      ![.confirmed, .high].contains($0.relationship.confidence)
    }
    owners = connections.filter {
      $0.relationship.target == application.id
        && [.packageManager, .package].contains($0.entity.type)
    }
    let rawProvenance = application.details.filter {
      let label = $0.label.lowercased()
      return label.contains("receipt") || label.contains("origin")
        || label.contains("installed with") || label.contains("download")
        || label.contains("package manager")
    }
    let hasAppStoreReceipt = rawProvenance.contains {
      $0.label == "App Store receipt" && $0.value == "Present"
    }
    provenance =
      rawProvenance.filter {
        $0.label != "App Store receipt"
          && $0.value != "Not observed"
          && !$0.value.hasPrefix("Unavailable")
      } + (hasAppStoreReceipt ? [Detail("Installation source", "App Store")] : [])

    var missing: [String] = []
    if processes.isEmpty {
      missing.append(
        "\(AppBrand.displayName) did not observe a running process for this application.")
    }
    if startupItems.isEmpty {
      missing.append("\(AppBrand.displayName) did not find a connected startup declaration.")
    }
    if provenance.isEmpty && owners.isEmpty {
      missing.append("Installation-source evidence is unavailable.")
    }
    if associatedItems.isEmpty && possibleAssociatedItems.isEmpty {
      missing.append("No strongly associated support locations or tools were observed.")
    }
    if connections.contains(where: { $0.relationship.confidence == .ambiguous }) {
      missing.append(
        "At least one connection remains ambiguous; \(AppBrand.displayName) shows it without claiming ownership."
      )
    }
    unknowns = missing
  }

  var currentState: String {
    application.details.first { $0.label == "Current state" }?.value
      ?? (processes.isEmpty ? "Not observed running" : "Observed running")
  }

  var status: Status {
    if application.details.contains(where: {
      $0.label == "Application health"
        && ["broken", "unhealthy"].contains($0.value.lowercased())
    }) {
      return .unhealthy
    }
    if let warningCount = application.details.first(where: { $0.label == "Warnings" })
      .flatMap({ Int($0.value) }), warningCount > 0
    {
      return .warnings(warningCount)
    }
    let normalizedState = currentState.lowercased()
    if !processes.isEmpty || ["running", "observed running"].contains(normalizedState) {
      return .running
    }
    return .offline
  }
}
