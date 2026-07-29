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
            .font(.halRowTitle)
        }
        .padding(12)
        .background(.bar)
        AtlasDetailView(model: model)
      }
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          storyHeader
          originSection
          storySection(
            title: "Why it may be active",
            symbol: "play.circle",
            emptyMessage: "No active process or startup evidence was observed.",
            connections: story.processes + story.startupItems
          )
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
          .font(.halSmall.bold())
          .foregroundStyle(.secondary)
        HStack(spacing: 10) {
          Text(application.name)
            .font(.halDisplay.bold())
            .textSelection(.enabled)
          statusBadge
        }
        Text(application.summary)
          .font(.halSubsection)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
      Spacer()
      if model.isSynthetic {
        Label("Fictional example", systemImage: "sparkles")
          .font(.halSecondary.weight(.semibold))
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

  private var statusBadge: some View {
    let color: Color =
      switch story.status {
      case .running: .green
      case .offline: .gray
      case .warnings: .orange
      case .unhealthy: .red
      }
    return Text(story.status.label)
      .font(.halSmall.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 9)
      .padding(.vertical, 4)
      .background(color, in: Capsule())
      .accessibilityLabel("Application status: \(story.status.label)")
  }

  private func evidenceExplanation(_ relationship: Relationship) -> String {
    let summaries = relationship.evidence.map(\.summary)
    guard !summaries.isEmpty else {
      return "HAL retained no supporting evidence details."
    }
    return summaries.prefix(2).joined(separator: " ")
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
          .font(.halRowTitle)
        Text(connection.relationship.explanation)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
        Text(
          "Why HAL connects these: \(evidenceExplanation(connection.relationship))"
        )
        .font(.halSmall)
        .foregroundStyle(
          connection.relationship.confidence == .ambiguous ? Color.orange : Color.secondary
        )
        .textSelection(.enabled)
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
        "The story is the summary. Open the preview for the full node explorer and inspector."
      )
      .foregroundStyle(.secondary)
      Button {
        showsRelationshipMap = true
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          ApplicationRelationshipPreview(
            graph: model.presentedGraph,
            layout: model.layout,
            applicationID: application.id
          )
          HStack {
            Spacer()
            Label("Open full relationship map", systemImage: "arrow.up.right")
              .font(.halSmall.weight(.semibold))
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Open the full relationship map")
      .accessibilityLabel("Open the full relationship map for \(application.name)")
      HStack {
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
      .font(.halSection.bold())
  }

  private func calmEmpty(_ message: String) -> some View {
    Label(message, systemImage: "circle.dashed")
      .foregroundStyle(.secondary)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
  }
}
