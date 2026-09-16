import GeordiDomain
import SwiftUI

/// Centered modal popup listing the CLI command inventory, grouped by
/// the manifest-declared category ("setup" or "utility"). Commands render
/// on a simulated dark terminal screen in Courier — one `$ command` line
/// per entry with a dim description underneath. Info only: dismissed by
/// the backdrop, the close button, or Escape.
struct CLIActionsPopup: View {
  let inventory: CLICommandInventory?
  let linkLocation: String
  let onClose: () -> Void

  private var groupedEntries: [(category: String, entries: [CLICommandInventory.Entry])] {
    guard let inventory else { return [] }
    let grouped = Dictionary(grouping: inventory.entries, by: \.category)
    let knownOrder = ["setup", "utility"]
    let known = knownOrder.compactMap { key in grouped[key].map { (key, $0) } }
    let unknown = grouped.keys.filter { !knownOrder.contains($0) }.sorted().compactMap {
      key in grouped[key].map { (key, $0) }
    }
    return known + unknown
  }

  private func categoryLabel(_ raw: String) -> String {
    switch raw {
    case "setup": "Setup"
    case "utility": "Utilities"
    default: raw.capitalized
    }
  }

  var body: some View {
    ZStack {
      Button {
        onClose()
      } label: {
        Color.black.opacity(0.24)
          .ignoresSafeArea()
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Close CLI actions")

      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("CLI actions")
            .font(.title3.weight(.semibold))
          Spacer()
          Button {
            onClose()
          } label: {
            Image(systemName: "xmark")
              .font(.small.bold())
          }
          .buttonStyle(.plain)
          .hoverHighlight(hPadding: 4, vPadding: 2)
          .keyboardShortcut(.cancelAction)
          .accessibilityLabel("Close")
        }

        terminalScreen

        Text(
          "All commands run through the \(AppBrand.cliCommand) link on your PATH (\(linkLocation)/\(AppBrand.cliCommand)); repair-cli restores it if the app moves."
        )
        .font(.caption)
        .foregroundStyle(.tertiary)
      }
      .padding(22)
      .frame(minWidth: 480, idealWidth: 560, maxWidth: 680, alignment: .topLeading)
      .background(
        Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.16))
      }
      .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }
  }

  /// The simulated terminal: near-black screen, Courier command lines,
  /// dim comment-style group headers. Selectable so commands can be
  /// copied straight into a shell.
  private var terminalScreen: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(groupedEntries.enumerated()), id: \.element.category) {
          index, group in
          if index > 0 {
            Divider()
              .overlay(Color.white.opacity(0.08))
              .padding(.vertical, 10)
          }
          Text("# \(categoryLabel(group.category).uppercased())")
            .font(.custom("Courier New", size: 11).bold())
            .foregroundStyle(Color(red: 0.42, green: 0.62, blue: 0.82))
            .padding(.bottom, 4)
          ForEach(group.entries) { entry in
            VStack(alignment: .leading, spacing: 2) {
              Text("$ \(entry.usage)")
                .font(.custom("Courier New", size: 12).weight(.medium))
                .foregroundStyle(Color(white: 0.93))
                .textSelection(.enabled)
              Text(entry.summary)
                .font(.custom("Courier New", size: 11))
                .foregroundStyle(Color(white: 0.58))
                .textSelection(.enabled)
            }
            .padding(.vertical, 3)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Color(red: 0.07, green: 0.08, blue: 0.09),
        in: RoundedRectangle(cornerRadius: 10)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color.white.opacity(0.12))
      }
    }
    .frame(maxHeight: 360)
  }
}
