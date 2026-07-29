import HALDomain
import HALVisualization
import SwiftUI

struct ApplicationRelationshipPreview: View {
  let graph: SystemGraph
  let layout: LayoutResult
  let configuration: LayoutConfiguration

  var body: some View {
    RelationshipCanvas(
      graph: graph,
      layout: layout,
      visibleTypes: Set(EntityType.allCases),
      selection: .constant(nil),
      focusedEntity: .constant(nil),
      configuration: configuration,
      isReadOnlyPreview: true
    )
    .frame(height: 300)
    .accessibilityHidden(true)
  }
}
