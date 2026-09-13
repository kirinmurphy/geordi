import AppKit
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiVisualization
import SwiftUI

struct ReferenceItem: Identifiable {
  let id: String
  let title: String
  let detail: String
  let explanation: String
  let question: String
  let examples: String
  let symbol: String
  let tint: Color
}

enum ReferenceCatalog {
  static let configuration: ReferenceCatalogConfiguration = {
    do {
      return try ReferenceCatalogConfiguration.bundled()
    } catch {
      preconditionFailure("Required reference catalog failed validation: \(error)")
    }
  }()

  static let items = configuration.items.map {
    ReferenceItem(
      id: $0.id,
      title: $0.title,
      detail: $0.detail,
      explanation: $0.explanation,
      question: $0.question,
      examples: $0.examples,
      symbol: $0.symbol,
      tint: color(for: $0.tint)
    )
  }

  static func item(forEntityType type: EntityType) -> ReferenceItem? {
    guard let definition = configuration.item(for: type) else { return nil }
    return items.first { $0.id == definition.id }
  }

  private static func color(for tint: EntityPresentationTint) -> Color {
    switch tint {
    case .accent: .accentColor
    case .blue: .blue
    case .cyan: .cyan
    case .green: .green
    case .mint: .mint
    case .orange: .orange
    case .purple: .purple
    case .red: .red
    }
  }
}

struct ReferenceConceptPanel: View {
  let item: ReferenceItem
  let onClose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        HStack(spacing: 9) {
          Image(systemName: item.symbol)
            .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
          Text(item.title).font(.heading.bold())
        }
        .foregroundStyle(item.tint)
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .font(.section)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close concept details")
      }
      Text(item.question).font(.subsection.bold())
      Text(item.explanation)
        .font(.paragraph)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: 5) {
        Text("Examples")
          .font(.small.weight(.semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text(item.examples).font(.secondary)
      }
    }
    .padding(26)
    .frame(maxWidth: 560, alignment: .leading)
    .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20).stroke(item.tint.opacity(0.8), lineWidth: 2)
    }
    .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("referenceConceptDetail")
  }
}

struct SystemReferenceView: View {
  let onClose: () -> Void
  @State private var selectedID: String?

  private let items = ReferenceCatalog.items

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        HStack(alignment: .top, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Text("How \(AppBrand.displayName) fits together")
              .font(.display.bold())
            Text(
              "The complete user-facing model, from what exists on a Mac to an informed decision. Select any section for context. Collector and implementation internals are intentionally omitted."
            )
            .font(.subsection)
            .foregroundStyle(.secondary)
          }
          Spacer()
          Button {
            onClose()
          } label: {
            Label("Close", systemImage: "xmark")
          }
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("closeMapReference")
        }

        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 16) {
            Label(
              "What \(AppBrand.displayName) observes on this Mac", systemImage: "desktopcomputer"
            )
            .font(.rowTitle)

            HStack(spacing: 12) {
              referenceCard("mac")
              referenceCard("source")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
              Text("Inside the machine: one software example")
                .font(.rowTitle)
              Text(
                "The single Software card below is one installed item. Every connected line represents one specific relationship."
              )
              .font(.small)
              .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 0) {
              softwareHubCard()
                .frame(width: 245)

              VStack(spacing: 0) {
                relationshipPath(
                  verb: "launches",
                  targetID: "runtime",
                  followOnVerb: "consumes",
                  followOnTargetID: "resources"
                )
                persistenceRuntimeConnector()
                relationshipPath(
                  verb: "registers startup",
                  targetID: "persistence"
                )
                Spacer().frame(height: 12)
                relationshipPath(
                  verb: "reads and writes",
                  targetID: "data",
                  targetAtFarRight: true
                )
              }
            }

            HStack(spacing: 10) {
              Text("Changes to any component above are recorded as")
                .font(.secondary)
                .foregroundStyle(.secondary)
              connectedArrow("")
              referenceCard("history")
                .frame(width: 310)
            }
          }
          .padding(16)
          .background(
            Color(nsColor: .windowBackgroundColor).opacity(0.6),
            in: RoundedRectangle(cornerRadius: 18)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 18)
              .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
          }

          VStack(alignment: .leading, spacing: 12) {
            Text("How \(AppBrand.displayName) turns observations into guidance")
              .font(.rowTitle)
            Text(
              "This is \(AppBrand.displayName)’s review workflow, not another set of components inside the computer."
            )
            .font(.small)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
              workflowStep(1, itemID: "evidence")
              Image(systemName: "chevron.right").foregroundStyle(.tertiary)
              workflowStep(2, itemID: "findings")
              Image(systemName: "chevron.right").foregroundStyle(.tertiary)
              workflowStep(3, itemID: "decisions")
            }
          }
          .padding(16)
          .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
          .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(Color.secondary.opacity(0.16))
          }
        }
        .padding(22)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedID)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

        VStack(alignment: .leading, spacing: 12) {
          Text("Important distinctions")
            .font(.section.bold())
          distinction(
            "User data is not cache",
            "A large project or browser profile may belong to an application without being safe to remove."
          )
          distinction(
            "Installed is not running",
            "An application bundle can exist without any active process or performance impact.")
          distinction(
            "Nearby is not necessarily causal",
            "An event can overlap a slowdown without proving that it caused the slowdown.")
          distinction(
            "Uncertain ownership stays protected",
            "\(AppBrand.displayName) should expose ambiguous or shared data instead of making a confident-looking guess."
          )
        }
      }
      .padding(28)
      .frame(maxWidth: 1_160, alignment: .leading)
    }
    .frame(minWidth: 900, minHeight: 680)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.28), radius: 30, y: 12)
    .overlay {
      if let selectedItem {
        ZStack {
          Button {
            closeConcept()
          } label: {
            Color.black.opacity(0.16)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Close concept details")

          ReferenceConceptPanel(item: selectedItem, onClose: closeConcept)
            .padding(36)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
      }
    }
  }

  private var selectedItem: ReferenceItem? {
    items.first { $0.id == selectedID }
  }

  private func closeConcept() {
    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
      selectedID = nil
    }
  }

  private func referenceRow(_ itemIDs: [String]) -> some View {
    HStack(spacing: 12) {
      ForEach(itemIDs, id: \.self) { itemID in
        if let item = items.first(where: { $0.id == itemID }) {
          Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
              selectedID = item.id
            }
          } label: {
            VStack(alignment: .leading, spacing: 7) {
              Label(item.title, systemImage: item.symbol)
                .font(.rowTitle)
                .foregroundStyle(item.tint)
              Text(item.detail)
                .font(.secondary)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(14)
            .background(
              item.tint.opacity(selectedID == item.id ? 0.18 : 0.1),
              in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
              RoundedRectangle(cornerRadius: 14)
                .stroke(
                  item.tint.opacity(selectedID == item.id ? 0.9 : 0.3),
                  lineWidth: selectedID == item.id ? 2 : 1)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(item.title). \(item.detail)")
          .accessibilityHint("Shows more context")
        }
      }
    }
  }

  private func referenceCard(_ itemID: String) -> some View {
    Group {
      if let item = items.first(where: { $0.id == itemID }) {
        Button {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selectedID = item.id
          }
        } label: {
          HStack(spacing: 10) {
            Image(systemName: item.symbol)
              .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
              .foregroundStyle(item.tint)
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.rowTitle)
              Text(item.detail)
                .font(.small)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
          .padding(12)
          .background(item.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
          .overlay {
            RoundedRectangle(cornerRadius: 13).stroke(item.tint.opacity(0.42))
          }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more context")
      }
    }
  }

  private func relationshipLane(from sourceID: String, verb: String, to targetID: String)
    -> some View
  {
    HStack(spacing: 10) {
      referenceCard(sourceID)
      horizontalArrow(verb)
        .frame(width: 150)
      referenceCard(targetID)
    }
  }

  private func connectedArrow(_ label: String) -> some View {
    HStack(spacing: 0) {
      Rectangle()
        .fill(Color.secondary.opacity(0.45))
        .frame(height: 1)
      if !label.isEmpty {
        Text(label)
          .font(.small.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.78)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(.regularMaterial, in: Capsule())
      }
      Rectangle()
        .fill(Color.secondary.opacity(0.45))
        .frame(height: 1)
      Image(systemName: "arrowtriangle.right.fill")
        .font(.small)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label.isEmpty ? "connects to" : label)
  }

  private func softwareHubCard() -> some View {
    Group {
      if let item = items.first(where: { $0.id == "software" }) {
        Button {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selectedID = item.id
          }
        } label: {
          VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
              Image(systemName: item.symbol)
                .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
              Text(item.title).font(.rowTitle)
            }
            .foregroundStyle(item.tint)
            Text(item.detail)
              .font(.small)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .padding(12)
          .background(item.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
          .overlay {
            RoundedRectangle(cornerRadius: 13).stroke(item.tint.opacity(0.42))
          }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more context")
      }
    }
  }

  private func relationshipPath(
    verb: String,
    targetID: String,
    followOnVerb: String? = nil,
    followOnTargetID: String? = nil,
    targetAtFarRight: Bool = false
  ) -> some View {
    HStack(spacing: 0) {
      if let followOnVerb, let followOnTargetID {
        connectedArrow(verb)
          .frame(width: 150)
        referenceCard(targetID)
          .frame(width: 210)
        connectedArrow(followOnVerb)
          .frame(width: 150)
        referenceCard(followOnTargetID)
          .frame(width: 210)
      } else if targetAtFarRight {
        connectedArrow(verb)
          .frame(maxWidth: .infinity)
        referenceCard(targetID)
          .frame(width: 210)
      } else {
        connectedArrow(verb)
          .frame(width: 150)
        referenceCard(targetID)
          .frame(width: 210)
        Spacer(minLength: 360)
      }
    }
  }

  private func persistenceRuntimeConnector() -> some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: 150)
      VStack(spacing: 1) {
        Image(systemName: "arrowtriangle.up.fill")
          .font(.small)
        Rectangle().frame(width: 1)
        Text("can start later")
          .font(.small.weight(.medium))
          .lineLimit(1)
      }
      .foregroundStyle(.secondary)
      .frame(width: 210, height: 44)
      Spacer()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Persistence can start Runtime later")
  }

  private func workflowStep(_ number: Int, itemID: String) -> some View {
    Group {
      if let item = items.first(where: { $0.id == itemID }) {
        Button {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selectedID = item.id
          }
        } label: {
          HStack(spacing: 10) {
            Text("\(number)")
              .font(.small.bold())
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
              .background(Color.secondary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.secondary.bold())
              Text(item.detail)
                .font(.small)
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
          .padding(10)
          .background(
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18))
          }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more context")
      }
    }
  }

  private func horizontalArrow(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label.isEmpty ? " " : label)
        .font(.small.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Image(systemName: "arrow.right")
        .foregroundStyle(.secondary)
    }
    .fixedSize()
  }

  private func flowArrow(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(.small)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
  }

  private func flowBranch(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(.small)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func distinction(_ title: String, _ explanation: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.rowTitle)
      Text(explanation)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }

}
