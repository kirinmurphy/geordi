import Foundation
import HALDomain
import HALVisualization
import SwiftUI

struct ApplicationStoryTreeItem: Identifiable {
  let id: String
  let entity: Entity
  let relationship: Relationship?
  let path: String?

  init(entity: Entity, relationship: Relationship? = nil) {
    id = relationship?.id.rawValue ?? "entity:\(entity.id.rawValue)"
    self.entity = entity
    self.relationship = relationship
    path = entity.details.first(where: { $0.value.hasPrefix("/") })?.value
  }
}

struct ApplicationStoryFilesystemTree: View {
  let items: [ApplicationStoryTreeItem]
  let inspect: (Entity) -> Void

  private var roots: [ApplicationStoryTreeNode] {
    ApplicationStoryTreeNode.build(items)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(roots) { node in
        ApplicationStoryTreeBranch(node: node, depth: 0, inspect: inspect)
      }
    }
    .padding(.vertical, 6)
    .background(.secondary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.16))
    }
  }
}

private struct ApplicationStoryTreeNode: Identifiable {
  let id: String
  let label: String
  let fullPath: String?
  let children: [ApplicationStoryTreeNode]
  let items: [ApplicationStoryTreeItem]

  static func build(_ items: [ApplicationStoryTreeItem]) -> [Self] {
    let root = BuilderNode(label: "/", fullPath: "/")
    let related = BuilderNode(label: "Related software", fullPath: nil)
    for item in items {
      guard let path = item.path else {
        related.items.append(item)
        continue
      }
      var cursor = root
      var accumulated = ""
      for component in URL(filePath: path).standardizedFileURL.pathComponents.dropFirst() {
        accumulated += "/\(component)"
        if cursor.children[component] == nil {
          cursor.children[component] = BuilderNode(label: component, fullPath: accumulated)
        }
        cursor = cursor.children[component]!
      }
      cursor.items.append(item)
    }
    var result: [Self] = []
    if !root.children.isEmpty { result.append(root.freeze(id: "path:/")) }
    if !related.items.isEmpty { result.append(related.freeze(id: "related")) }
    return result
  }

  private final class BuilderNode {
    let label: String
    let fullPath: String?
    var children: [String: BuilderNode] = [:]
    var items: [ApplicationStoryTreeItem] = []

    init(label: String, fullPath: String?) {
      self.label = label
      self.fullPath = fullPath
    }

    func freeze(id: String) -> ApplicationStoryTreeNode {
      ApplicationStoryTreeNode(
        id: id,
        label: label,
        fullPath: fullPath,
        children: children.keys.sorted().compactMap {
          children[$0]?.freeze(id: "\(id)/\($0)")
        },
        items: items
      )
    }
  }
}

private struct ApplicationStoryTreeBranch: View {
  let node: ApplicationStoryTreeNode
  let depth: Int
  let inspect: (Entity) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        treeGuide
        Image(systemName: "folder.fill")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.blue)
        Text(node.label)
          .font(.halSecondary.weight(.semibold))
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 7)

      ForEach(node.items) { item in
        ApplicationStoryTreeLeaf(item: item, depth: depth + 1, inspect: inspect)
      }
      ForEach(node.children) { child in
        ApplicationStoryTreeBranch(node: child, depth: depth + 1, inspect: inspect)
      }
    }
  }

  private var treeGuide: some View {
    HStack(spacing: 0) {
      ForEach(0..<depth, id: \.self) { _ in
        Rectangle()
          .fill(Color.secondary.opacity(0.2))
          .frame(width: 1)
          .frame(width: 20)
      }
      Image(systemName: depth == 0 ? "circle.fill" : "arrow.turn.down.right")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.tertiary)
        .frame(width: 18)
    }
  }
}

private struct ApplicationStoryTreeLeaf: View {
  let item: ApplicationStoryTreeItem
  let depth: Int
  let inspect: (Entity) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      HStack(spacing: 0) {
        ForEach(0..<depth, id: \.self) { _ in
          Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1)
            .frame(width: 20)
        }
        Image(systemName: "arrow.turn.down.right")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.tertiary)
          .frame(width: 18)
      }
      Image(systemName: EntityVisualStyle.symbol(for: item.entity.type))
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(EntityVisualStyle.color(for: item.entity.type))
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.entity.name)
          .font(.halRowTitle)
        Text(item.relationship?.explanation ?? item.entity.summary)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
        if let relationship = item.relationship {
          Text("Why HAL connects these: \(evidenceExplanation(relationship))")
            .font(.halSmall)
            .foregroundStyle(
              relationship.confidence == .ambiguous ? Color.orange : Color.secondary
            )
            .textSelection(.enabled)
        }
        if let path = item.path {
          PathActionMenu(path: path)
        }
      }
      Spacer()
      Button("Inspect") { inspect(item.entity) }
        .buttonStyle(.bordered)
    }
    .padding(.leading, 12)
    .padding(.trailing, 12)
    .padding(.vertical, 10)
    .background(.background.opacity(0.45))
    .overlay(alignment: .bottom) {
      Rectangle().fill(.secondary.opacity(0.12)).frame(height: 1)
    }
  }

  private func evidenceExplanation(_ relationship: Relationship) -> String {
    let summaries = relationship.evidence.map(\.summary)
    return summaries.isEmpty
      ? "HAL retained no supporting evidence details."
      : summaries.prefix(2).joined(separator: " ")
  }
}
