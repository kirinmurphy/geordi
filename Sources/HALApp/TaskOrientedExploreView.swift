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
          Text("Start with a question. HAL will show the summary before the technical evidence.")
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
        columns: [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 12)],
        spacing: 12
      ) {
        questionCard(
          "Understand an application",
          explanation:
            "See why it may be active, where it came from, and what HAL associates with it.",
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
    .padding(18)
    .background(.blue.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16).stroke(.blue.opacity(0.16))
    }
    .accessibilityIdentifier("taskOrientedExplore")
  }

  private func questionCard(
    _ title: String,
    explanation: String,
    symbol: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 9) {
        Image(systemName: symbol)
          .font(.halSection)
          .foregroundStyle(.blue)
        Text(title)
          .font(.halRowTitle)
          .multilineTextAlignment(.leading)
        GlossaryAwareText(explanation, context: "overview")
          .font(.halSecondary)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
        Label("Explore", systemImage: "arrow.right")
          .font(.halSmall.bold())
          .foregroundStyle(.blue)
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
  }
}
