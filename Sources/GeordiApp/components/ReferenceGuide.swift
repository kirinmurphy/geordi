import GeordiDomain
import SwiftUI

/// One node in a "how it works" reference flow.
struct GuideNode: Identifiable, Hashable {
  let id: String
  let title: String
  let explanation: String
  let symbol: String
}

/// Solid dark blue-gray — the reference palette. Deliberately heavier
/// than every other card surface so supporting theory reads as its own
/// layer of the page; type colors are adjusted for the dark ground.
enum ReferencePalette {
  static let panel = Color(red: 0.16, green: 0.20, blue: 0.26)
  static let accent = Color(red: 0.58, green: 0.72, blue: 0.87)
  static let foreground = Color.white
  static let mutedForeground = Color.white.opacity(0.72)
  static let panelStroke = Color.white.opacity(0.16)
  static let card = Color.white.opacity(0.08)
  static let cardStroke = Color.white.opacity(0.14)
}

/// Shared styling for explanatory reference panels. Distinct from
/// observation panels — solid dark blue-gray card, an overline chip,
/// bounded width — so supporting theory never reads as interactive
/// findings. Every "how this works" surface on the destination pages
/// renders through this one component.
struct ReferencePanel<Content: View>: View {
  let title: String
  var maxWidth: CGFloat = 860
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Reference", systemImage: "text.book.closed")
        .font(.small.weight(.semibold))
        .tracking(1.2)
        .textCase(.uppercase)
        .foregroundStyle(ReferencePalette.accent)
      Text(title)
        .font(.section.bold())
        .foregroundStyle(ReferencePalette.foreground)
      content()
    }
    .padding(20)
    .frame(maxWidth: maxWidth, alignment: .leading)
    .background(ReferencePalette.panel, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16).stroke(ReferencePalette.panelStroke)
    }
  }
}

/// The node flow used by the destination reference guides: the wide
/// left-to-right connected columns are the primary layout (four nodes at
/// 170pt fit the panel's content width); the vertical stack is only a
/// narrow-window fallback. Icons are landmark-sized, arrows vertically
/// centered against the node row.
struct ReferenceFlow: View {
  /// Row height the wide-layout arrows center against; matches the flow
  /// nodes' minimum height.
  private static let nodeRowHeight: CGFloat = 150

  let nodes: [GuideNode]

  var body: some View {
    ViewThatFits(in: .horizontal) {
      wide
      compact
    }
  }

  private var wide: some View {
    HStack(alignment: .top, spacing: 10) {
      ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
        if index > 0 {
          connector("arrow.right")
            .frame(height: Self.nodeRowHeight)
        }
        flowNode(node).frame(width: 170)
      }
    }
  }

  private var compact: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
        if index > 0 { connector("arrow.down") }
        flowNode(node)
      }
    }
  }

  private func connector(_ symbol: String) -> some View {
    Image(systemName: symbol)
      .font(.system(size: 17, weight: .bold))
      .foregroundStyle(ReferencePalette.accent)
      .accessibilityHidden(true)
  }

  private func flowNode(_ node: GuideNode) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: node.symbol)
        .font(.system(size: 30, weight: .medium))
        .foregroundStyle(ReferencePalette.accent)
      Text(node.title)
        .font(.rowTitle)
        .foregroundStyle(ReferencePalette.foreground)
      Text(node.explanation)
        .font(.small)
        .foregroundStyle(ReferencePalette.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, minHeight: Self.nodeRowHeight, alignment: .topLeading)
    .padding(14)
    .background(
      ReferencePalette.card,
      in: RoundedRectangle(cornerRadius: 12)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(ReferencePalette.cardStroke)
    }
  }
}

/// The reference guide for each exploration destination. All node copy
/// lives here — one place to edit every destination's supporting theory.
enum ReferenceGuide {
  case startup
  case storage
  case commandLine

  var title: String {
    switch self {
    case .startup: "How automatic startup actually works"
    case .storage: "How reclaimable data fits into application storage"
    case .commandLine: "How command-line software becomes available"
    }
  }

  var nodes: [GuideNode] {
    switch self {
    case .startup:
      [
        GuideNode(
          id: "declaration", title: "Declaration",
          explanation: "A plist records a request to launch something.", symbol: "doc.text"),
        GuideNode(
          id: "service", title: "Launch service",
          explanation: "macOS evaluates scope, timing, and restart policy.", symbol: "gearshape.2"),
        GuideNode(
          id: "software", title: "Owning software",
          explanation:
            "\(AppBrand.displayName) connects the declaration to an app when evidence supports it.",
          symbol: "app.badge"),
        GuideNode(
          id: "process", title: "Running process",
          explanation: "A separate observation—configuration alone does not prove it ran.",
          symbol: "waveform.path.ecg"),
      ]
    case .storage:
      [
        GuideNode(
          id: "application", title: "Application",
          explanation: "Software reads, writes, downloads, and derives data.", symbol: "app"),
        GuideNode(
          id: "support", title: "Working data",
          explanation: "Settings and support data may be essential or user-authored.",
          symbol: "folder.badge.gearshape"),
        GuideNode(
          id: "rebuildable", title: "Rebuildable data",
          explanation: "Caches and derived artifacts can often be recreated.",
          symbol: "arrow.triangle.2.circlepath"),
        GuideNode(
          id: "decision", title: "Evidence before action",
          explanation: "Size and classification inform a decision; they do not authorize deletion.",
          symbol: "checklist"),
      ]
    case .commandLine:
      [
        GuideNode(
          id: "source", title: "Install source",
          explanation: "A package manager, installer, or user-local location introduces software.",
          symbol: "shippingbox"),
        GuideNode(
          id: "package", title: "Installed package",
          explanation: "A package may be requested directly or pulled in as a dependency.",
          symbol: "cube.box"),
        GuideNode(
          id: "capability", title: "Capability",
          explanation: "Runtimes and tools provide commands used by other software.",
          symbol: "hammer"),
        GuideNode(
          id: "path", title: "Command on PATH",
          explanation: "Shell search order determines which executable a name resolves to.",
          symbol: "terminal"),
      ]
    }
  }

  var panel: some View {
    ReferencePanel(title: title) {
      ReferenceFlow(nodes: nodes)
    }
  }
}
