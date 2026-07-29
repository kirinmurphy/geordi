import HALVisualization
import SwiftUI

struct GlossaryTermToggle: View {
  let label: String
  let term: GlossaryTerm
  let delayMilliseconds: Int
  @State private var presented = false
  @State private var hoverTask: Task<Void, Never>?

  var body: some View {
    Button {
      hoverTask?.cancel()
      presented.toggle()
    } label: {
      HStack(spacing: 3) {
        Text(label)
        Image(systemName: "questionmark.circle")
          .font(.caption2)
      }
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      hoverTask?.cancel()
      guard hovering else { return }
      hoverTask = Task {
        try? await Task.sleep(for: .milliseconds(delayMilliseconds))
        guard !Task.isCancelled else { return }
        presented = true
      }
    }
    .popover(isPresented: $presented) {
      VStack(alignment: .leading, spacing: 8) {
        Text(term.displayTerm).font(.headline)
        Text(term.description).textSelection(.enabled)
        if let explanation = term.explanation {
          Text(explanation).foregroundStyle(.secondary).textSelection(.enabled)
        }
      }
      .padding(14)
      .frame(width: 310, alignment: .leading)
    }
    .accessibilityLabel("\(label), glossary term")
    .accessibilityHint("Shows a plain-language explanation")
  }
}
