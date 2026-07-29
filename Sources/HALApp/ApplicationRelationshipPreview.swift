import HALDomain
import HALVisualization
import SwiftUI

struct ApplicationRelationshipPreview: View {
  let graph: SystemGraph
  let layout: LayoutResult
  let applicationID: EntityID

  var body: some View {
    GeometryReader { proxy in
      let inset = 48.0
      let mapped: (EntityID) -> CGPoint? = { id in
        guard let point = layout.positions[id] else { return nil }
        return CGPoint(
          x: inset + (point.x / max(layout.size.width, 1)) * max(proxy.size.width - 2 * inset, 1),
          y: 22 + (point.y / max(layout.size.height, 1)) * max(proxy.size.height - 44, 1)
        )
      }

      ZStack {
        Canvas { context, _ in
          for relationship in graph.relationships {
            guard let start = mapped(relationship.source), let end = mapped(relationship.target)
            else { continue }
            var path = Path()
            path.move(to: start)
            let midpoint = (start.x + end.x) / 2
            path.addCurve(
              to: end,
              control1: CGPoint(x: midpoint, y: start.y),
              control2: CGPoint(x: midpoint, y: end.y)
            )
            let color = relationship.confidence == .ambiguous ? Color.orange : Color.accentColor
            context.stroke(
              path,
              with: .color(color.opacity(0.48)),
              style: StrokeStyle(
                lineWidth: relationship.source == applicationID
                  || relationship.target == applicationID ? 2 : 1,
                dash: relationship.confidence == .ambiguous ? [5, 4] : []
              )
            )
          }
        }
        .allowsHitTesting(false)

        ForEach(graph.entities) { entity in
          if let point = mapped(entity.id) {
            VStack(spacing: 2) {
              Image(systemName: EntityVisualStyle.symbol(for: entity.type))
              Text(entity.name)
                .font(.halSmall.weight(entity.id == applicationID ? .semibold : .regular))
                .lineLimit(1)
            }
            .foregroundStyle(
              entity.id == applicationID ? Color.primary : EntityVisualStyle.color(for: entity.type)
            )
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
              EntityVisualStyle.color(for: entity.type).opacity(
                entity.id == applicationID ? 0.2 : 0.1
              ),
              in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
              RoundedRectangle(cornerRadius: 8)
                .stroke(
                  EntityVisualStyle.color(for: entity.type).opacity(
                    entity.id == applicationID ? 0.8 : 0.35
                  )
                )
            }
            .frame(maxWidth: 112)
            .position(point)
          }
        }
      }
      .clipped()
    }
    .frame(height: 190)
    .accessibilityHidden(true)
  }
}
