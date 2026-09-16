import GeordiDomain
import SwiftUI

/// The Part C onboarding card: dismissible first-launch card with an
/// "Enable CLI" CTA, an inline "View CLI Actions" link (click opens a
/// centered popup listing the CLI inventory) and the same inventory
/// re-shown in the success state. Display copy lives here as
/// manifest-derived values; the card is never shown as a modal
/// launch-time dialog.
struct CLIOnboardingCard: View {
  @Bindable var model: CLIEnablementModel
  let inventory: CLICommandInventory?
  let onDismiss: () -> Void
  let onShowActions: () -> Void

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
        .hoverHighlight(hPadding: 4, vPadding: 2)
        .help("Dismiss — you can enable the CLI later from the Home page")
        .accessibilityLabel("Dismiss CLI onboarding")
      }

      descriptionText
        .font(.small)
        .onHover { hovering in
          withAnimation(.easeInOut(duration: 0.12)) { linkUnderlined = hovering }
        }
        .environment(
          \.openURL,
          OpenURLAction { url in
            if url.absoluteString == Self.actionsURL.absoluteString {
              onShowActions()
              return .handled
            }
            return .systemAction
          })

      switch model.phase {
      case .succeeded:
        successInventory
      default:
        HStack(spacing: 10) {
          Button("Enable CLI") {
            Task { await model.enable() }
          }
          .buttonStyle(AppButtonStyle(.standard))
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

  /// The description with the "View CLI Actions" link embedded IN the
  /// text flow (true inline — it wraps with the paragraph). SwiftUI Text
  /// cannot restyle one substring on hover precisely, so the whole
  /// paragraph tracks hover and toggles the link's underline — the hover
  /// affordance the user asked for. Click is intercepted via the openURL
  /// environment action and opens the CLI actions popup.
  private static let actionsURL = URL(string: "geordi://cli-actions")!
  @State private var linkUnderlined = false

  private var descriptionText: Text {
    var attributed = AttributedString(
      "Enables \(AppBrand.cliCommand) on your PATH for terminal sessions and agents — no sudo, only when you press Enable. "
    )
    attributed.foregroundColor = Color.secondary
    if inventoryAvailable {
      var link = AttributedString("View CLI Actions")
      link.foregroundColor = Color.accentColor
      if linkUnderlined {
        link.underlineStyle = .single
      }
      link.link = Self.actionsURL
      attributed += link
    }
    return Text(attributed)
  }

  private var inventoryAvailable: Bool {
    guard let inventory else { return false }
    return !inventory.entries.isEmpty
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
        TerminalCommandList(
          groups: [
            TerminalCommandList.Group(
              id: "",
              entries: inventory.entries.enumerated().map { index, entry in
                TerminalCommandList.Item(
                  id: "success-\(index)-\(entry.usage)",
                  usage: entry.usage,
                  summary: entry.summary
                )
              }
            )
          ])
      }
      Text("Link: \(model.linkLocation)/\(AppBrand.cliCommand)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
}
