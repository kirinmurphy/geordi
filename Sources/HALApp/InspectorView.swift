import HALDomain
import HALVisualization
import SwiftUI

struct InspectorView: View {
  let graph: SystemGraph
  let selection: GraphSelection?
  let onShowEntityTypeInfo: (EntityType) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if let selection {
          switch selection.value {
          case .entity(let id):
            if let entity = graph.entity(id) { entityView(entity) }
          case .relationship(let id):
            if let relationship = graph.relationship(id) {
              relationshipView(relationship)
            }
          }
        } else {
          ContentUnavailableView(
            "Nothing selected",
            systemImage: "cursorarrow.click",
            description: Text("Select a node or relationship, or use the text navigator.")
          )
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 500)
    .accessibilityIdentifier("inspector")
  }

  private func entityView(_ entity: Entity) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: EntityVisualStyle.symbol(for: entity.type))
            .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
          Text(entity.type.label.uppercased())
            .font(.caption.bold())
        }
        .foregroundStyle(EntityVisualStyle.color(for: entity.type))
        Button {
          onShowEntityTypeInfo(entity.type)
        } label: {
          Image(systemName: "info.circle")
        }
        .buttonStyle(.plain)
        .foregroundStyle(EntityVisualStyle.color(for: entity.type))
        .help("Explain \(entity.type.label.lowercased())")
        .accessibilityLabel("About \(entity.type.label)")
      }
      Text(entity.name).font(.title.bold())
      Text(entity.summary).font(.title3)
      if !entity.details.isEmpty {
        Divider()
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
          ForEach(entity.details) { detail in
            GridRow {
              Text(detail.label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
              Text(detail.value)
                .fontWeight(.semibold)
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
      Divider()
      let upstream = graph.relationships(connectedTo: entity.id).filter {
        $0.target == entity.id
      }
      let downstream = graph.relationships(connectedTo: entity.id).filter {
        $0.source == entity.id
      }
      if !upstream.isEmpty {
        relationshipSection(
          "Upstream relationships",
          relationships: upstream,
          selectedEntity: entity,
          isUpstream: true
        )
      }
      if !downstream.isEmpty {
        relationshipSection(
          "Downstream relationships",
          relationships: downstream,
          selectedEntity: entity,
          isUpstream: false
        )
      }
    }
  }

  private func relationshipView(_ relationship: Relationship) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      label("Relationship", systemImage: "arrow.right")
      Text(relationship.type.rawValue.capitalized).font(.title.bold())
      HStack {
        Text(graph.entity(relationship.source)?.name ?? "Unknown source")
        Image(systemName: "arrow.right")
          .accessibilityLabel("points to")
        Text(graph.entity(relationship.target)?.name ?? "Unknown target")
      }
      .font(.headline)
      Text(relationship.explanation).font(.title3)
      Label(
        "\(relationship.confidence.plainLanguage) · \(relationship.confidence.rawValue.capitalized)",
        systemImage: relationship.confidence == .ambiguous
          ? "questionmark.diamond" : "checkmark.seal"
      )
      .foregroundStyle(relationship.confidence == .ambiguous ? .orange : .secondary)
      VStack(alignment: .leading, spacing: 12) {
        Text("Evidence (\(relationship.evidence.count))")
          .font(.headline)
        ForEach(relationship.evidence) { evidence in
          VStack(alignment: .leading, spacing: 4) {
            Text(evidence.kind == .observed ? "OBSERVED FACT" : "HAL INFERENCE")
              .font(.caption2.bold())
              .foregroundStyle(evidence.kind == .observed ? .green : .blue)
            Text(evidence.summary)
            Text(evidence.source)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .accessibilityIdentifier("evidenceDisclosure")
    }
  }

  private func relationshipSection(
    _ title: String,
    relationships: [Relationship],
    selectedEntity: Entity,
    isUpstream: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.subheadline.bold())
        .foregroundStyle(.secondary)
      ForEach(groupedRelationships(relationships, isUpstream: isUpstream), id: \.key) { group in
        relationshipGroup(
          group.relationships,
          selectedEntity: selectedEntity,
          isUpstream: isUpstream
        )
      }
    }
  }

  private func relationshipGroup(
    _ relationships: [Relationship],
    selectedEntity: Entity,
    isUpstream: Bool
  ) -> some View {
    let first = relationships[0]
    let counterparts = relationships.compactMap {
      graph.entity(isUpstream ? $0.source : $0.target)
    }
    let nodeType = counterparts.first?.type
    let tint = nodeType.map { EntityVisualStyle.color(for: $0) } ?? .secondary
    return VStack(alignment: .leading, spacing: 9) {
      if let nodeType {
        HStack(spacing: 6) {
          Image(systemName: EntityVisualStyle.symbol(for: nodeType))
            .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
          Text(nodeType.label.uppercased())
            .font(.caption2.bold())
        }
        .foregroundStyle(tint)
      }

      Text(
        groupTitle(
          relationship: first,
          count: counterparts.count,
          counterparts: counterparts,
          selectedEntity: selectedEntity,
          isUpstream: isUpstream
        )
      )
      .font(.callout.bold())

      if relationships.count > 1 {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(counterparts) { counterpart in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Circle()
                .fill(tint.opacity(0.8))
                .frame(width: 5, height: 5)
              Text(counterpart.name)
                .font(.callout.weight(.medium))
            }
          }
        }
        .padding(.top, 2)
      } else {
        Text(first.explanation)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.45))
    }
  }

  private func groupedRelationships(
    _ relationships: [Relationship],
    isUpstream: Bool
  )
    -> [(key: String, relationships: [Relationship])]
  {
    Dictionary(grouping: relationships) { relationship in
      let counterpartID = isUpstream ? relationship.source : relationship.target
      let type = graph.entity(counterpartID)?.type.rawValue ?? "unknown"
      return "\(relationship.type.rawValue)|\(type)"
    }
    .map { (key: $0.key, relationships: $0.value) }
    .sorted { $0.key < $1.key }
  }

  private func groupTitle(
    relationship: Relationship,
    count: Int,
    counterparts: [Entity],
    selectedEntity: Entity,
    isUpstream: Bool
  ) -> String {
    let typeLabels = Set(counterparts.map { $0.type.label.lowercased() })
    let counterpartDescription =
      typeLabels.count == 1 ? (typeLabels.first ?? "items") : "connected items"
    if isUpstream {
      return count == 1
        ? "\(counterparts.first?.name ?? "Item") \(relationship.type.rawValue) \(selectedEntity.name)"
        : "\(count) \(counterpartDescription) \(relationship.type.rawValue) \(selectedEntity.name)"
    }
    return count == 1
      ? "\(selectedEntity.name) \(relationship.type.rawValue) \(counterparts.first?.name ?? "item")"
      : "\(selectedEntity.name) \(relationship.type.rawValue) \(count) \(counterpartDescription)"
  }

  private func directionText(_ relationship: Relationship) -> String {
    let source = graph.entity(relationship.source)?.name ?? "Unknown"
    let target = graph.entity(relationship.target)?.name ?? "Unknown"
    return "\(source) \(relationship.type.rawValue) \(target)"
  }

  private func label(
    _ text: String,
    systemImage: String,
    tint: Color = .secondary
  ) -> some View {
    Label(text.uppercased(), systemImage: systemImage)
      .font(.caption.bold())
      .foregroundStyle(tint)
  }
}
