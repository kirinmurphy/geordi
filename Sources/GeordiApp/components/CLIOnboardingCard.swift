import GeordiDomain
import SwiftUI

/// The Part C onboarding card: dismissible first-launch card with an
/// "Enable CLI" CTA, an info tooltip listing the CLI inventory before
/// deciding, and the same inventory re-shown in the success state.
/// Display copy lives here as manifest-derived values; the card is
/// never shown as a modal launch-time dialog.
struct CLIOnboardingCard: View {
  @Bindable var model: CLIEnablementModel
  let inventory: CLICommandInventory?
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "terminal")
          .foregroundStyle(.secondary)
        Text("Run agent-friendly actions via our CLI")
          .font(.rowTitle.weight(.semibold))
        Spacer()
        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.small.bold())
        }
        .buttonStyle(.plain)
        .help("Dismiss — you can enable the CLI later from the Tools section")
        .accessibilityLabel("Dismiss CLI onboarding")
      }

      Text(
        "Enables \(AppBrand.cliCommand) on your PATH so terminal sessions and agents can use the same tools this window shows. No sudo; the app never enables it without your press."
      )
      .font(.small)
      .foregroundStyle(.secondary)

      switch model.phase {
      case .succeeded:
        successInventory
      default:
        HStack(spacing: 10) {
          Button("Enable CLI") {
            Task { await model.enable() }
          }
          .disabled(model.phase == .running)
          if case .running = model.phase {
            ProgressView()
              .controlSize(.small)
          }
          if case .failed(let message) = model.phase {
            Text(message)
              .font(.small)
              .foregroundStyle(.red)
              .lineLimit(2)
          }
          Spacer()
          inventoryHelp
        }
      }
    }
    .padding(14)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(.quaternary, lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("cliOnboardingCard")
  }

  /// Info icon with the full command inventory — shown BEFORE enabling
  /// (tooltip) and again in the success state (below).
  @ViewBuilder private var inventoryHelp: some View {
    if let inventory, !inventory.entries.isEmpty {
      Image(systemName: "info.circle")
        .foregroundStyle(.secondary)
        .help(inventory.entries.map { "\($0.usage) — \($0.summary)" }.joined(separator: "\n"))
        .accessibilityLabel(
          "CLI commands: "
            + inventory.entries.map { "\($0.usage): \($0.summary)" }.joined(separator: "; "))
    }
  }

  @ViewBuilder private var successInventory: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label {
        Text("CLI enabled — \(AppBrand.cliCommand) is on your PATH")
          .font(.small.weight(.semibold))
      } icon: {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
      }
      if let inventory {
        VStack(alignment: .leading, spacing: 3) {
          ForEach(inventory.entries) { entry in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text(entry.usage)
                .font(.system(size: 11, design: .monospaced).weight(.medium))
              Text(entry.summary)
                .font(.small)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.leading, 22)
      }
      Text("Link: \(model.linkLocation)/\(AppBrand.cliCommand)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
}
