import CoreGraphics
import HALDomain

public struct LayoutGroup: Equatable, Sendable {
  public let id: String
  public let title: String
  public let frame: CGRect

  public init(id: String, title: String, frame: CGRect) {
    self.id = id
    self.title = title
    self.frame = frame
  }
}

public struct LayoutResult: Equatable, Sendable {
  public let positions: [EntityID: CGPoint]
  public let groups: [LayoutGroup]
  public let size: CGSize

  public init(
    positions: [EntityID: CGPoint],
    groups: [LayoutGroup] = [],
    size: CGSize
  ) {
    self.positions = positions
    self.groups = groups
    self.size = size
  }
}

public struct SemanticLayout: Sendable {
  public let configuration: LayoutConfiguration

  public init(configuration: LayoutConfiguration) {
    self.configuration = configuration
  }

  public func layout(_ graph: SystemGraph) -> LayoutResult {
    let populatedStages = stages.compactMap { stage -> (Stage, [Entity])? in
      let entities = graph.entities.filter { stage.types.contains($0.type) }
        .sorted {
          if $0.type.rawValue == $1.type.rawValue {
            return $0.id.rawValue < $1.id.rawValue
          }
          return $0.type.rawValue < $1.type.rawValue
        }
      return entities.isEmpty ? nil : (stage, entities)
    }

    let rowSpacing = max(configuration.nodeHeight + 22, min(configuration.rowSpacing, 104))
    let columnSpacing = max(configuration.nodeWidth + 32, min(configuration.columnSpacing, 224))
    let maximumRows = populatedStages.map { $0.1.count }.max() ?? 1
    let contentHeight =
      configuration.nodeHeight + 92 + Double(max(maximumRows - 1, 0)) * rowSpacing

    var positions: [EntityID: CGPoint] = [:]
    var groups: [LayoutGroup] = []
    for (columnIndex, item) in populatedStages.enumerated() {
      let (stage, entities) = item
      let originX = 20 + Double(columnIndex) * columnSpacing
      let stageWidth = configuration.nodeWidth + 24
      groups.append(
        LayoutGroup(
          id: stage.id,
          title: stage.title,
          frame: CGRect(x: originX, y: 18, width: stageWidth, height: contentHeight - 36)
        ))
      for (rowIndex, entity) in entities.enumerated() {
        positions[entity.id] = CGPoint(
          x: originX + stageWidth / 2,
          y: 76 + configuration.nodeHeight / 2 + Double(rowIndex) * rowSpacing
        )
      }
    }

    return LayoutResult(
      positions: positions,
      groups: groups,
      size: CGSize(
        width: max(
          configuration.nodeWidth + 64,
          40 + Double(max(populatedStages.count - 1, 0)) * columnSpacing
            + configuration.nodeWidth + 24
        ),
        height: max(contentHeight, 220)
      )
    )
  }

  private var stages: [Stage] {
    [
      Stage(id: "context", title: "CONTEXT & SOURCES", types: [.event, .packageManager]),
      Stage(
        id: "software", title: "SOFTWARE",
        types: [.application, .shellFramework, .package]),
      Stage(id: "runtime", title: "RUNTIME & STARTUP", types: [.process, .persistence]),
      Stage(id: "data", title: "DATA", types: [.file]),
      Stage(id: "impact", title: "IMPACT", types: [.resource, .incident]),
    ]
  }

  private struct Stage: Sendable {
    let id: String
    let title: String
    let types: Set<EntityType>
  }
}
