import GeordiDomain
import SwiftUI

/// Centered modal popup listing the CLI command inventory, grouped by
/// the manifest-declared category ("setup" or "utility"): a two-column
/// table — command column at 33% width, description at 67% — over a
/// dimmed backdrop. Info only: dismissed by the backdrop, the close
/// button, or Escape.
struct CLIActionsPopup: View {
  let inventory: CLICommandInventory?
  let linkLocation: String
  let onClose: () -> Void

  /// The command column is 33% of the table width; the description takes
  /// the remaining 67%. The default matches the panel's ideal width so
  /// the first frame is already proportioned.
  @State private var tableWidth: CGFloat = 516

  private var commandColumnWidth: CGFloat {
    tableWidth * 0.33
  }

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

        ScrollView {
          Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
              Text("Command")
              Text("Description")
            }
            .font(.small.weight(.semibold))
            .foregroundStyle(.secondary)

            GridRow {
              Divider()
              Divider()
            }

            ForEach(groupedEntries, id: \.category) { group in
              GridRow {
                Text(categoryLabel(group.category).uppercased())
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.tertiary)
                  .gridCellColumns(2)
              }
              ForEach(group.entries) { entry in
                GridRow {
                  Text(entry.usage)
                    .font(.system(size: 11, design: .monospaced).weight(.medium))
                    .textSelection(.enabled)
                    .frame(minWidth: commandColumnWidth, alignment: .leading)
                  Text(entry.summary)
                    .font(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                  Divider()
                  Divider()
                }
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            GeometryReader { geo in
              Color.clear
                .onAppear { tableWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, new in tableWidth = new }
            }
          )
        }
        .frame(maxHeight: 360)

        Text(
          "Setup commands run through the geordi command on your PATH — Enable CLI installs that link, and repair-cli repairs it (for example after moving the app)."
        )
        .font(.caption)
        .foregroundStyle(.tertiary)

        Text(
          "After enabling, \(AppBrand.cliCommand) is linked at \(linkLocation)/\(AppBrand.cliCommand)."
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
}
