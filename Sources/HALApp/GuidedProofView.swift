import HALDomain
import HALVisualization
import SwiftUI

struct GuidedProofView: View {
  let model: AppModel
  let dismiss: () -> Void
  @State private var stepIndex = 0

  private let configuration = try? GuidedProofConfiguration.bundled()

  var body: some View {
    VStack(spacing: 0) {
      header
      if let configuration, !configuration.steps.isEmpty {
        let step = configuration.steps[stepIndex]
        VStack(spacing: 24) {
          Spacer()
          Image(systemName: step.symbol)
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(.purple)
            .accessibilityHidden(true)
          VStack(spacing: 10) {
            Text("STEP \(stepIndex + 1) OF \(configuration.steps.count)")
              .font(.caption.bold())
              .foregroundStyle(.secondary)
            Text(step.title)
              .font(.largeTitle.bold())
              .multilineTextAlignment(.center)
            Text(step.summary)
              .font(.title3)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .textSelection(.enabled)
              .frame(maxWidth: 620)
          }
          Label(step.takeaway, systemImage: "lightbulb")
            .font(.headline)
            .padding(16)
            .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .textSelection(.enabled)
          Spacer()
          progress(configuration.steps.count)
          controls(configuration)
        }
        .padding(32)
      } else {
        ContentUnavailableView(
          "Tour unavailable",
          systemImage: "exclamationmark.bubble",
          description: Text("The guided-proof presentation could not be loaded.")
        )
      }
    }
    .frame(minWidth: 760, minHeight: 600)
    .accessibilityIdentifier("guidedProof")
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(configuration?.title ?? "Guided tour")
          .font(.headline)
        Text("Fictional example · no Mac collection")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Close", action: dismiss)
        .keyboardShortcut(.cancelAction)
    }
    .padding(16)
    .background(.bar)
  }

  private func progress(_ count: Int) -> some View {
    HStack(spacing: 7) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(index == stepIndex ? Color.purple : Color.secondary.opacity(0.2))
          .frame(width: index == stepIndex ? 28 : 10, height: 7)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(stepIndex + 1) of \(count)")
  }

  private func controls(_ configuration: GuidedProofConfiguration) -> some View {
    HStack {
      Button("Back") {
        stepIndex = max(0, stepIndex - 1)
      }
      .disabled(stepIndex == 0)
      .keyboardShortcut(.leftArrow, modifiers: [])
      Spacer()
      if stepIndex == configuration.steps.count - 1 {
        Button("Open the Application Story") {
          if let entity = model.fixture.entity(EntityID(configuration.storyEntityID)) {
            model.focus(entity)
          }
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      } else {
        Button("Next") {
          stepIndex = min(configuration.steps.count - 1, stepIndex + 1)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.rightArrow, modifiers: [])
      }
    }
  }
}
