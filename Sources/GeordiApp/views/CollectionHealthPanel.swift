import AppKit
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiVisualization
import SwiftUI

struct CollectionHealthPanel: View {
  let model: AppModel
  let exportAction: () -> Void

  var body: some View {
    let freshness = model.dataFreshness()
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Collection Health")
          .font(.section.bold())
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: statusSymbol(freshness))
            .foregroundStyle(statusColor(freshness))
          VStack(alignment: .leading, spacing: 3) {
            Text(statusTitle(freshness))
              .font(.rowTitle)
            Text(statusExplanation(freshness))
              .font(.secondary)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor(freshness).opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .stroke(statusColor(freshness).opacity(0.28))
        }
        Text(
          "\(AppBrand.displayName) only read configured sources. It did not change applications or machine data."
        )
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        ForEach(Array(model.scanContext.collectorRuns.enumerated()), id: \.offset) { _, run in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(run.collectorID.rawValue)
                .font(.rowTitle)
              Spacer()
              Text(run.state.rawValue.capitalized)
                .foregroundStyle(run.state == .complete ? Color.secondary : Color.orange)
            }
            Text(impact(for: run))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
            if !run.issues.isEmpty {
              DisclosureGroup(
                "\(run.issues.count) issue\(run.issues.count == 1 ? "" : "s") logged for future updates"
              ) {
                ForEach(Array(run.issues.enumerated()), id: \.offset) { _, issue in
                  Text(issue.summary)
                    .textSelection(.enabled)
                }
              }
            }
          }
          Divider()
        }
        HStack {
          if model.isSynthetic {
            Button(model.isCollecting ? "Linking…" : "Link to This Mac") {
              model.linkToMac()
            }
            .disabled(model.isCollecting)
          } else {
            Button(model.isCollecting ? "Checking…" : "Check This Mac Again") {
              model.refreshLiveData()
            }
            .disabled(model.isCollecting)
          }
          Button("Export Redacted Diagnostics…") { exportAction() }
        }
        .buttonStyle(.bordered)
      }
      .padding(20)
    }
    .frame(width: 520, height: 520)
  }

  private func statusTitle(_ freshness: FreshnessState) -> String {
    if model.isSynthetic { return "Deterministic fixture is current" }
    return switch freshness {
    case .fresh: "Observation is current"
    case .aging: "Observation is getting older"
    case .stale: "Observation is stale"
    case .partial: "Observation is partial"
    case .unavailable: "Data is unavailable"
    case .permissionDenied: "Permission limits this observation"
    case .neverCollected: "This Mac has not been observed"
    }
  }

  private func statusExplanation(_ freshness: FreshnessState) -> String {
    if model.isSynthetic {
      return
        "This reproducible example does not read this Mac. Link explicitly to collect current read-only observations."
    }
    let timestamp =
      model.scanContext.completedAt.map {
        " Last completed \($0.formatted(date: .abbreviated, time: .shortened))."
      } ?? ""
    let explanation =
      switch freshness {
      case .fresh:
        "\(AppBrand.displayName) completed a recent read-only check."
      case .aging:
        "The retained snapshot may no longer reflect recent changes. You can check again now."
      case .stale:
        "The retained snapshot is old enough that \(AppBrand.displayName) recommends checking again."
      case .partial:
        "One or more configured sources did not complete normally. Existing observations remain usable."
      case .unavailable:
        "Configured sources were unavailable during the last check."
      case .permissionDenied:
        "macOS denied access to at least one configured source. Checking again can retry after permissions change."
      case .neverCollected:
        "Run a read-only check to create the first observation."
      }
    return explanation + timestamp
  }

  private func statusSymbol(_ freshness: FreshnessState) -> String {
    switch freshness {
    case .fresh: "checkmark.circle.fill"
    case .aging: "clock.fill"
    case .stale: "exclamationmark.circle.fill"
    case .partial: "circle.lefthalf.filled"
    case .unavailable: "questionmark.circle.fill"
    case .permissionDenied: "lock.circle.fill"
    case .neverCollected: "circle.dashed"
    }
  }

  private func statusColor(_ freshness: FreshnessState) -> Color {
    switch freshness {
    case .fresh: .green
    case .aging, .partial, .permissionDenied: .orange
    case .stale: .red
    case .unavailable, .neverCollected: .secondary
    }
  }

  private func impact(for run: CollectorRun) -> String {
    if run.state == .complete && run.availability == .available {
      return "This source was observed normally."
    }
    if run.availability == .permissionDenied {
      return "macOS access limits this source; granting access may improve coverage."
    }
    if run.issues.allSatisfy({ $0.severity == .information }) {
      return
        "\(AppBrand.displayName) logged a parser or coverage detail; no Mac repair is required."
    }
    return "Some observations from this source may be missing. Existing results remain usable."
  }
}

enum AppButtonKind {
  case standard
  case inline
  case inlineCTA
  case cta
}

struct AppButtonStyle: ButtonStyle {
  let kind: AppButtonKind

  init(_ kind: AppButtonKind = .standard) {
    self.kind = kind
  }

  func makeBody(configuration: Configuration) -> some View {
    AppButtonStyleBody(
      configuration: configuration,
      kind: kind
    )
  }

  private struct AppButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: AppButtonKind
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
      configuration.label
        .font(.secondary.weight(kind == .cta ? .semibold : .medium))
        .underline(kind == .inline || kind == .inlineCTA)
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, isInline ? 0 : 13)
        .padding(.vertical, isInline ? 3 : 7)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
          RoundedRectangle(cornerRadius: 7)
            .stroke(borderColor, lineWidth: isInline ? 0 : 1)
        }
        .opacity(isEnabled ? 1 : 0.45)
        .scaleEffect(configuration.isPressed && !isInline ? 0.98 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        .onHover { hovering in
          isHovering = hovering
          if isEnabled && hovering {
            NSCursor.pointingHand.set()
          } else {
            NSCursor.arrow.set()
          }
        }
    }

    private var foregroundColor: Color {
      switch kind {
      case .standard:
        isHovering ? .primary : .primary.opacity(0.9)
      case .inline:
        isHovering ? Color.primary.opacity(0.7) : .primary
      case .inlineCTA:
        isHovering ? Color.accentColor.opacity(0.72) : .accentColor
      case .cta:
        .white
      }
    }

    private var backgroundColor: Color {
      switch kind {
      case .standard:
        Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 1 : 0.72)
      case .inline, .inlineCTA:
        .clear
      case .cta:
        Color.accentColor.opacity(
          configuration.isPressed ? 0.72 : (isHovering ? 0.86 : 1)
        )
      }
    }

    private var borderColor: Color {
      switch kind {
      case .standard:
        Color.secondary.opacity(isHovering ? 0.42 : 0.25)
      case .inline, .inlineCTA:
        .clear
      case .cta:
        Color.accentColor.opacity(0.9)
      }
    }

    private var isInline: Bool {
      kind == .inline || kind == .inlineCTA
    }
  }
}

struct ApplicationFilterOption: View {
  let label: String
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(.secondary.weight(isSelected ? .bold : .regular))
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.small.bold())
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .background(
        !isSelected && isHovering ? Color.accentColor.opacity(0.13) : .clear,
        in: RoundedRectangle(cornerRadius: 7)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovering = hovering
      if !isSelected && hovering {
        NSCursor.pointingHand.set()
      } else {
        NSCursor.arrow.set()
      }
    }
  }
}

struct InventoryRow: View {
  let symbol: String
  let tint: Color
  let title: String
  var subtitle: String? = nil
  let trailing: String
  var applicationPath: String? = nil
  var compact = false
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        if let applicationPath {
          Image(nsImage: NSWorkspace.shared.icon(forFile: applicationPath))
            .resizable()
            .scaledToFit()
            .frame(
              width: compact ? IconSize.base : IconSize.large,
              height: compact ? IconSize.base : IconSize.large
            )
        } else {
          Image(systemName: symbol)
            .font(.system(size: IconSize.base, weight: .semibold))
            .foregroundStyle(tint)
            .frame(
              width: compact ? IconSize.base : IconSize.large,
              height: compact ? IconSize.base : IconSize.large
            )
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.rowTitle)
          if let subtitle {
            Text(subtitle)
              .font(.secondary)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
          }
        }
        Spacer()
        Text(trailing)
          .font(.secondary.weight(.medium))
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, compact ? 6 : 11)
      .frame(maxWidth: .infinity)
      .background(
        isHovering
          ? Color.accentColor.opacity(compact ? 0.14 : 0.11)
          : (compact ? Color.secondary.opacity(0.025) : Color.clear)
      )
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(Color.secondary.opacity(isHovering ? 0.3 : 0.16))
          .frame(height: 1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .pointerCursor()
    .padding(.horizontal, -16)
    .onHover { isHovering = $0 }
  }
}
