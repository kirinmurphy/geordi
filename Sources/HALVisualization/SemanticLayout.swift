import CoreGraphics
import HALDomain

public struct LayoutGroup: Equatable, Sendable {
  public let id: String
  public let title: String
  public let tint: SemanticStageDefinition.Tint
  public let frame: CGRect

  public init(id: String, title: String, tint: SemanticStageDefinition.Tint, frame: CGRect) {
    self.id = id
    self.title = title
    self.tint = tint
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
  public let stageConfiguration: SemanticStageConfiguration

  public init(
    configuration: LayoutConfiguration,
    stageConfiguration: SemanticStageConfiguration? = nil
  ) {
    self.configuration = configuration
    guard let resolved = stageConfiguration ?? (try? SemanticStageConfiguration.bundled()) else {
      preconditionFailure("Bundled semantic-stage configuration failed validation.")
    }
    self.stageConfiguration = resolved
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
          tint: stage.tint,
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
    stageConfiguration.stages.map {
      Stage(id: $0.id, title: $0.title, tint: $0.tint, types: Set($0.types))
    }
  }

  private struct Stage: Sendable {
    let id: String
    let title: String
    let tint: SemanticStageDefinition.Tint
    let types: Set<EntityType>
  }
}
