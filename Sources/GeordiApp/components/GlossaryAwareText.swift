import GeordiVisualization
import SwiftUI

struct GlossaryAwareText: View {
  let text: String
  let context: String
  private let glossary = try? Glossary.bundled()

  init(_ text: String, context: String) {
    self.text = text
    self.context = context
  }

  var body: some View {
    if let glossary {
      GlossaryFlowLayout(spacing: 4) {
        ForEach(Array(words(from: glossary).enumerated()), id: \.offset) { _, token in
          switch token {
          case .text(let value):
            Text(value)
          case .term(let label, let term):
            GlossaryTermToggle(
              label: label,
              term: term,
              delayMilliseconds: glossary.hoverDelayMilliseconds
            )
          }
        }
      }
    } else {
      Text(text)
    }
  }

  private func words(from glossary: Glossary) -> [GlossaryToken] {
    glossary.tokens(in: text, context: context).flatMap {
      token -> [GlossaryToken] in
      switch token {
      case .term:
        [token]
      case .text(let value):
        value.split(whereSeparator: \.isWhitespace).map { .text(String($0)) }
      }
    }
  }
}

private struct GlossaryFlowLayout: Layout {
  let spacing: CGFloat

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    arrange(proposal: proposal, subviews: subviews).size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    let arrangement = arrange(
      proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
      subviews: subviews
    )
    for (index, point) in arrangement.points.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
        anchor: .topLeading,
        proposal: .unspecified
      )
    }
  }

  private func arrange(
    proposal: ProposedViewSize,
    subviews: Subviews
  ) -> (size: CGSize, points: [CGPoint]) {
    let width = proposal.width ?? .infinity
    var points: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > width {
        x = 0
        y += lineHeight + spacing
        lineHeight = 0
      }
      points.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    return (CGSize(width: min(width, max(x - spacing, 0)), height: y + lineHeight), points)
  }
}
