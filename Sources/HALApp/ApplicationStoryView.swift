import AppKit
import HALDomain
import HALVisualization
import SwiftUI

struct ApplicationStoryView: View {
  let model: AppModel
  let application: Entity
  @State private var showsRelationshipMap = false

  private var story: ApplicationStoryModel {
    ApplicationStoryModel(application: application, graph: model.fixture)
  }

  var body: some View {
    if showsRelationshipMap {
      VStack(spacing: 0) {
        HStack {
          Button {
            showsRelationshipMap = false
          } label: {
            Label("Application Story", systemImage: "chevron.left")
          }
          .buttonStyle(.bordered)
          Spacer()
          Text("Relationship Map")
            .font(.headline)
        }
        .padding(12)
        .background(.bar)
        AtlasDetailView(model: model)
      }
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          storyHeader
          atAGlance
          storySection(
            title: "Why it may be active",
            symbol: "play.circle",
            emptyMessage: "No active process or startup evidence was observed.",
            connections: story.processes + story.startupItems
          )
          originSection
          storySection(
            title: "What HAL associates with it",
            symbol: "link",
            emptyMessage: "No strong support-location, package, or tool association was observed.",
            connections: story.associatedItems
          )
          unknownSection
          exploreSection
        }
        .padding(28)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity)
      }
      .background(Color(nsColor: .windowBackgroundColor))
      .accessibilityIdentifier("applicationStory")
    }
  }

  private var storyHeader: some View {
    HStack(alignment: .top, spacing: 18) {
      applicationIcon
        .frame(width: 64, height: 64)
      VStack(alignment: .leading, spacing: 6) {
        Text("APPLICATION STORY")
          .font(.caption.bold())
          .foregroundStyle(.secondary)
        Text(application.name)
          .font(.largeTitle.bold())
          .textSelection(.enabled)
        Text(application.summary)
          .font(.title3)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
      Spacer()
      if model.isSynthetic {
        Label("Fictional example", systemImage: "sparkles")
          .font(.callout.weight(.semibold))
          .foregroundStyle(.purple)
      }
    }
  }

  @ViewBuilder
  private var applicationIcon: some View {
    if let path = application.details.first(where: { $0.label == "Path" })?.value {
      Image(nsImage: NSWorkspace.shared.icon(forFile: path))
        .resizable()
        .scaledToFit()
    } else {
      Image(systemName: application.presentation?.symbol ?? "app.fill")
        .resizable()
        .scaledToFit()
        .foregroundStyle(.blue)
    }
  }

  private var atAGlance: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("At a glance", symbol: "rectangle.grid.2x2")
      HStack(spacing: 12) {
        storyFact("Current state", story.currentState, symbol: "waveform.path.ecg")
        storyFact("Where it came from", story.sourceSummary, symbol: "shippingbox")
        storyFact("Evidence", story.confidenceSummary, symbol: "checkmark.seal")
      }
    }
  }

  private var originSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Where it came from", symbol: "arrow.down.to.line.compact")
      if story.provenance.isEmpty && story.owners.isEmpty {
        calmEmpty("HAL does not have enough retained evidence to name an installation source.")
      } else {
        if let owner = story.owners.first {
          connectionRow(owner)
        }
        ForEach(story.provenance) { detail in
          HStack(alignment: .firstTextBaseline) {
            Text(detail.label)
              .foregroundStyle(.secondary)
            Spacer()
            Text(detail.value)
              .fontWeight(.semibold)
              .textSelection(.enabled)
          }
          .padding(12)
          .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        }
      }
    }
  }

  private func storySection(
    title: String,
    symbol: String,
    emptyMessage: String,
    connections: [ApplicationStoryModel.Connection]
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle(title, symbol: symbol)
      if connections.isEmpty {
        calmEmpty(emptyMessage)
      } else {
        ForEach(connections) { connectionRow($0) }
      }
    }
  }

  private func connectionRow(_ connection: ApplicationStoryModel.Connection) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: EntityVisualStyle.symbol(for: connection.entity.type))
        .foregroundStyle(EntityVisualStyle.color(for: connection.entity.type))
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(connection.entity.name)
          .font(.headline)
        Text(connection.relationship.explanation)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
        Text(
          "\(connection.relationship.confidence.plainLanguage) · \(connection.relationship.evidence.count) supporting evidence item\(connection.relationship.evidence.count == 1 ? "" : "s")"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(
          connection.relationship.confidence == .ambiguous ? Color.orange : Color.secondary
        )
      }
      Spacer()
      Button("Inspect") { model.focus(connection.entity) }
        .buttonStyle(.bordered)
    }
    .padding(14)
    .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
  }

  private var unknownSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("What HAL does not know", symbol: "questionmark.diamond")
      if story.unknowns.isEmpty {
        calmEmpty("No important missing state was identified in this point-in-time explanation.")
      } else {
        ForEach(story.unknowns, id: \.self) { message in
          Label(message, systemImage: "minus.circle")
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }
    }
  }

  private var exploreSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Explore the evidence", symbol: "safari")
      Text(
        "The story is the summary. Use the maps and inspector when you want the underlying context."
      )
      .foregroundStyle(.secondary)
      HStack {
        Button {
          showsRelationshipMap = true
        } label: {
          Label("Open Relationship Map", systemImage: "point.3.connected.trianglepath.dotted")
        }
        .buttonStyle(.borderedProminent)
        Button {
          model.navigate(to: .filesystem)
        } label: {
          Label("Open Filesystem Map", systemImage: "folder.badge.gearshape")
        }
        .buttonStyle(.bordered)
        if let path = application.details.first(where: { $0.value.hasPrefix("/") })?.value {
          PathActionMenu(path: path)
        }
      }
    }
    .padding(18)
    .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
  }

  private func sectionTitle(_ title: String, symbol: String) -> some View {
    Label(title, systemImage: symbol)
      .font(.title2.bold())
  }

  private func storyFact(_ title: String, _ value: String, symbol: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol)
        .font(.caption.bold())
        .foregroundStyle(.secondary)
      Text(value)
        .font(.headline)
        .textSelection(.enabled)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private func calmEmpty(_ message: String) -> some View {
    Label(message, systemImage: "circle.dashed")
      .foregroundStyle(.secondary)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
  }
}
