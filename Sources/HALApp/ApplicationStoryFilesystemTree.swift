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
        ApplicationStoryTreeBranch(
          node: node,
          ancestorContinuations: [],
          isLast: true,
          isRoot: true,
          inspect: inspect
        )
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
      // The entity represents the final path component. Only its ancestors are folders
      // in this presentation; otherwise `/Applications/Warp.app` incorrectly renders
      // as a Warp.app folder containing another Warp item.
      for component in URL(filePath: path).standardizedFileURL.pathComponents.dropFirst().dropLast()
      {
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
  let ancestorContinuations: [Bool]
  let isLast: Bool
  let isRoot: Bool
  let inspect: (Entity) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        if isRoot {
          Image(systemName: "circle.fill")
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 18)
        } else {
          ApplicationStoryTreeConnector(
            ancestorContinuations: ancestorContinuations,
            isLast: isLast
          )
        }
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

      ForEach(Array(node.items.enumerated()), id: \.element.id) { index, item in
        ApplicationStoryTreeLeaf(
          item: item,
          ancestorContinuations: childAncestorContinuations,
          isLast: index == node.items.count - 1 && node.children.isEmpty,
          inspect: inspect
        )
      }
      ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
        ApplicationStoryTreeBranch(
          node: child,
          ancestorContinuations: childAncestorContinuations,
          isLast: index == node.children.count - 1,
          isRoot: false,
          inspect: inspect
        )
      }
    }
  }

  private var childAncestorContinuations: [Bool] {
    isRoot ? [] : ancestorContinuations + [!isLast]
  }
}

private struct ApplicationStoryTreeLeaf: View {
  let item: ApplicationStoryTreeItem
  let ancestorContinuations: [Bool]
  let isLast: Bool
  let inspect: (Entity) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      ApplicationStoryTreeConnector(
        ancestorContinuations: ancestorContinuations,
        isLast: isLast
      )
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

/// Draws the complete tree prefix in one canvas so trunks and branches share
/// endpoints instead of being assembled from disconnected symbols.
private struct ApplicationStoryTreeConnector: View {
  let ancestorContinuations: [Bool]
  let isLast: Bool

  private let columnWidth: CGFloat = 20

  var body: some View {
    Canvas { context, size in
      var path = Path()
      let midpoint = size.height / 2

      for (column, continues) in ancestorContinuations.enumerated() where continues {
        let x = (CGFloat(column) * columnWidth) + (columnWidth / 2)
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
      }

      let branchX =
        (CGFloat(ancestorContinuations.count) * columnWidth) + (columnWidth / 2)
      path.move(to: CGPoint(x: branchX, y: 0))
      path.addLine(to: CGPoint(x: branchX, y: midpoint))
      path.addLine(to: CGPoint(x: size.width, y: midpoint))
      if !isLast {
        path.move(to: CGPoint(x: branchX, y: midpoint))
        path.addLine(to: CGPoint(x: branchX, y: size.height))
      }

      context.stroke(
        path,
        with: .color(.secondary.opacity(0.34)),
        style: StrokeStyle(lineWidth: 1, lineCap: .square, lineJoin: .miter)
      )
    }
    .frame(width: CGFloat(ancestorContinuations.count + 1) * columnWidth)
  }
}
