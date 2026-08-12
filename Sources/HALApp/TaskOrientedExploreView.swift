import HALDomain
import SwiftUI

struct TaskOrientedExploreView: View {
  let model: AppModel
  let startTour: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("What do you want to understand?")
            .font(.halSection.bold())
          Text(
            "Start with a question. \(AppBrand.displayName) will show the summary before the technical evidence."
          )
          .foregroundStyle(.secondary)
        }
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
        questionCard(
          "Understand an application",
          explanation:
            "See why it may be active, where it came from, and what \(AppBrand.displayName) associates with it.",
          symbol: "app.badge.checkmark"
        ) {
          model.navigate(to: .applications)
        }
        questionCard(
          "See what starts automatically",
          explanation: "Trace startup declarations to the software they may activate.",
          symbol: "power"
        ) {
          model.navigate(to: .startup)
        }
        questionCard(
          "Explore reclaimable data",
          explanation: "Understand rebuildable locations without implying that deletion is safe.",
          symbol: "arrow.3.trianglepath"
        ) {
          model.navigate(to: .storage)
        }
        questionCard(
          "Browse command-line tools",
          explanation: "Find runtimes, packages, ownership, aliases, and unclassified commands.",
          symbol: "terminal"
        ) {
          model.navigate(to: .commandLine)
        }
        questionCard(
          "Visualize shell PATH",
          explanation:
            "Paste a shell profile and trace source, prepend, append, and replacement operations.",
          symbol: "point.3.connected.trianglepath.dotted"
        ) {
          model.navigate(to: .shellPath)
        }
        questionCard(
          "Understand where software lives",
          explanation: "Explore a curated filesystem hierarchy without indexing the entire disk.",
          symbol: "folder.badge.gearshape"
        ) {
          model.navigate(to: .filesystem)
        }
      }
    }
    .accessibilityIdentifier("taskOrientedExplore")
  }

  private func questionCard(
    _ title: String,
    explanation: String,
    symbol: String,
    action: @escaping () -> Void
  ) -> some View {
    QuestionCard(
      title: title,
      explanation: explanation,
      symbol: symbol,
      action: action
    )
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
          .font(.system(size: 38, weight: .semibold))
          .foregroundStyle(.blue)
          .frame(height: 46, alignment: .top)
        Text(title)
          .font(.halSubsection.bold())
          .multilineTextAlignment(.leading)
        Text(explanation)
          .font(.halBody)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 10)
        HStack {
          Spacer()
          Label("Explore", systemImage: "arrow.right")
            .font(.halSecondary.bold())
            .foregroundStyle(.blue)
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
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
    .onHover { isHovering = $0 }
  }
}
