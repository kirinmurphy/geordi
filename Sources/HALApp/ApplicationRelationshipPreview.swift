import HALDomain
import HALVisualization
import SwiftUI

struct ApplicationRelationshipPreview: View {
  let graph: SystemGraph
  let layout: LayoutResult
  let configuration: LayoutConfiguration

  var body: some View {
    GeometryReader { proxy in
      let width = min(proxy.size.width * 0.9, 750)
      RelationshipCanvas(
        graph: graph,
        layout: layout,
        visibleTypes: Set(EntityType.allCases),
        selection: .constant(nil),
        focusedEntity: .constant(nil),
        configuration: configuration,
        isReadOnlyPreview: true
      )
      .frame(width: width, height: 420)
      .position(x: proxy.size.width / 2, y: 210)
    }
    .frame(height: 420)
    .accessibilityHidden(true)
  }
}
