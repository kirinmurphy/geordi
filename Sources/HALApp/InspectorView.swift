import AppKit
import HALDomain
import HALVisualization
import SwiftUI

struct InspectorView: View {
  let graph: SystemGraph
  let sourceGraph: SystemGraph
  let selection: GraphSelection?
  let onShowEntityTypeInfo: (EntityType) -> Void
  let onOpenEntity: (Entity) -> Void
  private let glossary = try? Glossary.bundled()
  private let displayProfile = try? InspectorDisplayProfile.bundled()

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
    let isDisplayGroup = DisplayGroupMetadata.isGroup(entity)
    return VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: EntityVisualStyle.symbol(for: entity.type))
            .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
          Text(entity.type.label.uppercased())
            .font(.halSmall.bold())
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
      Text(entity.name).font(.halTitle.bold())
      if entity.type != .application || isDisplayGroup {
        Text(entity.summary).font(.halSubsection)
      }
      if isDisplayGroup {
        includedEntities(entity)
      } else if !entity.details.isEmpty || !entity.instances.isEmpty {
        Divider()
        if entity.type == .application {
          applicationEvidenceSummary(entity)
          DisclosureGroup("Technical details") {
            groupedDetails(entity.details)
              .padding(.top, 10)
          }
          .font(.halSecondary.weight(.semibold))
        } else {
          if !entity.details.isEmpty {
            if !entity.instances.isEmpty {
              Text("Shared attributes")
                .font(.halRowTitle)
            }
            groupedDetails(entity.details)
          }
          if !entity.instances.isEmpty {
            instanceDetails(entity.instances)
          }
        }
      }
      if !isDisplayGroup {
        exploreFurther(entity)
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

  private func includedEntities(_ group: Entity) -> some View {
    let members = DisplayGroupMetadata.memberIDs(in: group).compactMap(sourceGraph.entity)
    return VStack(alignment: .leading, spacing: 10) {
      Text("Includes")
        .font(.halRowTitle)
      ForEach(members) { member in
        Button {
          onOpenEntity(member)
        } label: {
          HStack(spacing: 10) {
            Image(systemName: EntityVisualStyle.symbol(for: member.type))
              .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
              .foregroundStyle(EntityVisualStyle.color(for: member.type))
              .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
              Text(member.name)
                .font(.halSecondary.bold())
              Text(member.type.label)
                .font(.halSmall)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.halSmall.bold())
              .foregroundStyle(.secondary)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .background(
            EntityVisualStyle.color(for: member.type).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(EntityVisualStyle.color(for: member.type).opacity(0.45))
          }
        }
        .buttonStyle(.plain)
        .help("Open \(member.name)")
      }
    }
  }

  private func groupedDetails(_ details: [Detail]) -> some View {
    let grouped = Dictionary(grouping: details) {
      displayProfile?.group(for: $0.label).id ?? "technical"
    }
    let groups =
      displayProfile?.groups ?? [
        InspectorDetailGroup(id: "technical", label: "Technical details", detailLabels: [])
      ]
    return VStack(alignment: .leading, spacing: 14) {
      ForEach(groups.filter { grouped[$0.id]?.isEmpty == false }) { group in
        VStack(alignment: .leading, spacing: 8) {
          Text(group.label)
            .font(.halSecondary.bold())
          detailGrid(grouped[group.id] ?? [])
        }
      }
    }
  }

  private func exploreFurther(_ entity: Entity) -> some View {
    let paths = Array(Set(entity.details.map(\.value).filter { $0.hasPrefix("/") })).sorted()
    let manager = entity.details.first { $0.label == "Package manager" }?.value
    return Group {
      if !paths.isEmpty || manager == "Homebrew" {
        VStack(alignment: .leading, spacing: 10) {
          Text("Explore further").font(.halRowTitle)
          ForEach(paths, id: \.self) { PathActionMenu(path: $0) }
          if manager == "Homebrew", isSafePackageName(entity.name) {
            Button("Copy Homebrew removal guidance") {
              let command = "brew uninstall \(entity.name)"
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(command, forType: .string)
            }
            .help("Copies guidance only. HAL never runs package removal.")
          }
        }
      }
    }
  }

  private func isSafePackageName(_ value: String) -> Bool {
    !value.isEmpty
      && value.unicodeScalars.allSatisfy {
        CharacterSet.alphanumerics.contains($0) || "/@+_.-".unicodeScalars.contains($0)
      }
  }

  private func applicationEvidenceSummary(_ entity: Entity) -> some View {
    let signature = entity.details.first { $0.label == "Signature" }
    let team = entity.details.first { $0.label == "Team identifier" }
    let provenance = entity.details.filter {
      $0.label.localizedCaseInsensitiveContains("receipt")
        || $0.label.localizedCaseInsensitiveContains("origin")
    }
    return VStack(alignment: .leading, spacing: 10) {
      Text("Identity & provenance")
        .font(.halRowTitle)
      evidenceSummaryRow(
        title: "Signing",
        value: signature.map { signatureDetail in
          team.map { "\(signatureDetail.value) · Team \($0.value)" } ?? signatureDetail.value
        } ?? "Evidence unavailable",
        systemImage: signature == nil ? "questionmark.seal" : "checkmark.seal"
      )
      evidenceSummaryRow(
        title: "Provenance",
        value: provenanceSummary(provenance),
        systemImage: provenance.contains { $0.value != "Not observed" }
          ? "shippingbox" : "questionmark.folder"
      )
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }

  private func evidenceSummaryRow(
    title: String,
    value: String,
    systemImage: String
  ) -> some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: systemImage)
        .frame(width: 18)
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.halSmall.bold())
          .foregroundStyle(.secondary)
        Text(value)
          .font(.halSecondary.weight(.medium))
      }
    }
  }

  private func provenanceSummary(_ details: [Detail]) -> String {
    guard !details.isEmpty else {
      return "Evidence unavailable"
    }
    let observed = details.filter { $0.value != "Not observed" }
    guard !observed.isEmpty else {
      return "No retained receipt or download origin was observed"
    }
    return observed.map { "\($0.label): \($0.value)" }.joined(separator: " · ")
  }

  private func detailGrid(_ details: [Detail]) -> some View {
    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
      ForEach(details) { detail in
        GridRow {
          if let term = glossary?.term(matchingExactAlias: detail.label) {
            GlossaryTermToggle(
              label: detail.label,
              term: term,
              delayMilliseconds: glossary?.hoverDelayMilliseconds ?? 700
            )
            .gridColumnAlignment(.trailing)
          } else {
            Text(detail.label)
              .foregroundStyle(.secondary)
              .gridColumnAlignment(.trailing)
          }
          if detail.value.hasPrefix("/") {
            PathActionMenu(path: detail.value)
              .fontWeight(.semibold)
              .gridColumnAlignment(.leading)
          } else {
            Text(detail.value)
              .fontWeight(.semibold)
              .gridColumnAlignment(.leading)
              .textSelection(.enabled)
          }
        }
      }
    }
  }

  private func instanceDetails(_ instances: [EntityInstance]) -> some View {
    let columns = instances.reduce(into: [String]()) { labels, instance in
      for detail in instance.details where !labels.contains(detail.label) {
        labels.append(detail.label)
      }
    }
    return VStack(alignment: .leading, spacing: 10) {
      Text("Observed instances (\(instances.count))")
        .font(.halRowTitle)
      ScrollView(.horizontal) {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
          GridRow {
            Text("Instance")
            ForEach(columns, id: \.self) { label in
              Text(label)
            }
          }
          .font(.halSmall.bold())
          .foregroundStyle(.secondary)

          Divider()

          ForEach(instances) { instance in
            GridRow {
              Text(instance.id)
                .fontWeight(.semibold)
              ForEach(columns, id: \.self) { label in
                Text(instance.details.first { $0.label == label }?.value ?? "—")
                  .textSelection(.enabled)
              }
            }
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  private func relationshipView(_ relationship: Relationship) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      label("Relationship", systemImage: "arrow.right")
      Text(relationship.type.rawValue.capitalized).font(.halTitle.bold())
      HStack {
        Text(graph.entity(relationship.source)?.name ?? "Unknown source")
        Image(systemName: "arrow.right")
          .accessibilityLabel("points to")
        Text(graph.entity(relationship.target)?.name ?? "Unknown target")
      }
      .font(.halRowTitle)
      Text(relationship.explanation).font(.halSubsection)
      Label(
        "\(relationship.confidence.plainLanguage) · \(relationship.confidence.rawValue.capitalized)",
        systemImage: relationship.confidence == .ambiguous
          ? "questionmark.diamond" : "checkmark.seal"
      )
      .foregroundStyle(relationship.confidence == .ambiguous ? .orange : .secondary)
      VStack(alignment: .leading, spacing: 12) {
        Text("Evidence (\(relationship.evidence.count))")
          .font(.halRowTitle)
        ForEach(relationship.evidence) { evidence in
          VStack(alignment: .leading, spacing: 4) {
            Text(evidence.kind == .observed ? "OBSERVED FACT" : "HAL INFERENCE")
              .font(.halSmall.bold())
              .foregroundStyle(evidence.kind == .observed ? .green : .blue)
            Text(evidence.summary)
            Text(evidence.source)
              .font(.halSmall)
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
        .font(.halSecondary.bold())
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
            .font(.halSmall.bold())
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
      .font(.halSecondary.bold())

      if relationships.count > 1 {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(counterparts) { counterpart in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Circle()
                .fill(tint.opacity(0.8))
                .frame(width: 5, height: 5)
              Text(counterpart.name)
                .font(.halSecondary.weight(.medium))
            }
          }
        }
        .padding(.top, 2)
      } else {
        Text(first.explanation)
          .font(.halSmall)
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
      .font(.halSmall.bold())
      .foregroundStyle(tint)
  }
}
