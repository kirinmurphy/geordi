import HALVisualization
import SwiftUI

struct ShellPathVisualizerView: View {
  private let configuration = try? ShellPathConfiguration.bundled()
  @State private var source =
    """
    # Paste a shell profile here. HAL analyzes only this editor.
    export PATH="$HOME/bin:$PATH"
    source "$HOME/.tooling/path.sh"
    PATH="$PATH:/opt/example/bin"
    """
  @State private var analysis: ShellPathAnalysis?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Shell & PATH Visualizer").font(.halDisplay.bold())
          GlossaryAwareText(
            "Paste a shell profile to see how each statement changes PATH. HAL does not read your shell configuration automatically.",
            context: "shell"
          )
          .foregroundStyle(.secondary)
        }

        HStack(alignment: .top, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            Label("Explicit input", systemImage: "doc.text")
              .font(.halRowTitle)
            TextEditor(text: $source)
              .font(.system(.body, design: .monospaced))
              .frame(minHeight: 260)
              .padding(8)
              .background(.background, in: Rectangle())
              .overlay { Rectangle().stroke(.secondary.opacity(0.3)) }
            Button("Analyze pasted configuration") {
              analysis = ShellPathAnalyzer().analyze(
                source,
                maximumLines: configuration?.maximumLines ?? 500
              )
            }
            .buttonStyle(.borderedProminent)
          }
          .frame(maxWidth: .infinity)

          VStack(alignment: .leading, spacing: 8) {
            Label("Deterministic result", systemImage: "point.3.connected.trianglepath.dotted")
              .font(.halRowTitle)
            if let analysis {
              ForEach(analysis.operations) { operation in
                HStack(alignment: .top, spacing: 10) {
                  Text("\(operation.line)")
                    .font(.halSmall.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
                  Image(systemName: symbol(for: operation.kind))
                    .foregroundStyle(color(for: operation.kind))
                  VStack(alignment: .leading, spacing: 2) {
                    Text(operation.kind.rawValue.capitalized).font(.halSecondary.bold())
                    Text(operation.value).font(.halSmall.monospaced())
                  }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color(for: operation.kind).opacity(0.08))
                .overlay { Rectangle().stroke(color(for: operation.kind).opacity(0.25)) }
              }
              Divider()
              Text("Search order").font(.halRowTitle)
              ForEach(Array(analysis.resultingDirectories.enumerated()), id: \.offset) {
                index, directory in
                HStack {
                  Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 24)
                  Text(directory).font(.halSecondary.monospaced())
                }
              }
              ForEach(analysis.diagnostics, id: \.self) {
                Label($0, systemImage: "questionmark.diamond")
                  .font(.halSecondary)
                  .foregroundStyle(.orange)
              }
            } else {
              ContentUnavailableView(
                "Ready to analyze",
                systemImage: "terminal",
                description: Text("The diagram will show source operations and final search order.")
              )
              .frame(maxHeight: .infinity)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        }
      }
      .padding(28)
      .frame(maxWidth: 1_150)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.visible)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func symbol(for kind: ShellPathOperation.Kind) -> String {
    switch kind {
    case .prepend: "arrow.up.to.line"
    case .append: "arrow.down.to.line"
    case .replace: "arrow.triangle.2.circlepath"
    case .source: "doc.badge.arrow.up"
    case .unresolved: "questionmark"
    }
  }

  private func color(for kind: ShellPathOperation.Kind) -> Color {
    switch kind {
    case .prepend: .blue
    case .append: .green
    case .replace: .orange
    case .source: .purple
    case .unresolved: .gray
    }
  }
}
