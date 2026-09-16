import GeordiDomain
import SwiftUI

/// Home-page entry cards: one question per card, answered visually —
/// a large symbol and a title. The former one-line explanations remain
/// only as hover tooltips so the page stays scannable without walls of
/// text (detail lives one click away in each destination view).
struct TaskOrientedExploreView: View {
  let model: AppModel
  let startTour: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("What do you want to understand?")
          .font(.section.bold())
        Spacer()
        if model.isSynthetic {
          Button {
            startTour()
          } label: {
            Label("Take the 2-minute tour", systemImage: "sparkles")
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("guidedProofButton")
        }
      }

      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(minimum: 220), spacing: 16),
          count: 3
        ),
        spacing: 16
      ) {
        QuestionCard(
          title: "See what starts automatically",
          explanation: "Trace startup declarations to the software they may activate.",
          symbol: "power"
        ) {
          model.navigate(to: .startup)
        }
        QuestionCard(
          title: "Explore reclaimable data",
          explanation: "Understand rebuildable locations without implying that deletion is safe.",
          symbol: "arrow.3.trianglepath"
        ) {
          model.navigate(to: .storage)
        }
        QuestionCard(
          title: "Browse command-line tools",
          explanation: "Find runtimes, packages, ownership, aliases, and unclassified commands.",
          symbol: "terminal"
        ) {
          model.navigate(to: .commandLine)
        }
        QuestionCard(
          title: "Visualize shell PATH",
          explanation:
            "Paste a shell profile and trace source, prepend, append, and replacement operations.",
          symbol: "point.3.connected.trianglepath.dotted"
        ) {
          model.navigate(to: .shellPath)
        }
        QuestionCard(
          title: "Understand where software lives",
          explanation: "Explore a curated filesystem hierarchy without indexing the entire disk.",
          symbol: "folder.badge.gearshape"
        ) {
          model.navigate(to: .filesystem)
        }
      }
    }
    .accessibilityIdentifier("taskOrientedExplore")
  }
}

private struct QuestionCard: View {
  let title: String
  let explanation: String
  let symbol: String
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: symbol)
          .font(.system(size: 40, weight: .semibold))
          .foregroundStyle(.blue)
          .frame(height: 48, alignment: .top)
        Text(title)
          .font(.subsection.bold())
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 4)
        if isHovering {
          HStack {
            Spacer()
            Label("Explore", systemImage: "arrow.right")
              .font(.secondary.bold())
              .foregroundStyle(.blue)
          }
          .transition(.opacity)
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
      .background(
        isHovering ? Color.accentColor.opacity(0.11) : Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(
            isHovering ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.22),
            lineWidth: isHovering ? 1.5 : 1
          )
      }
      .shadow(color: .black.opacity(isHovering ? 0.1 : 0.04), radius: isHovering ? 8 : 3, y: 2)
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .pointerCursor()
    .help(explanation)
    .onHover { isHovering = $0 }
    .animation(.easeInOut(duration: 0.15), value: isHovering)
  }
}
