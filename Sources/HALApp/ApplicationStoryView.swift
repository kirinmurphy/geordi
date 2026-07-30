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
        VStack(alignment: .leading, spacing: 34) {
          storyHeader
          exploreSection
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
    let status: ApplicationStoryModel.Status =
      story.status == .offline && isRunningInWorkspace ? .running : story.status
    let color: Color =
      switch status {
      case .running: .green
      case .offline: .gray
      case .warnings: .orange
      case .unhealthy: .red
      }
    return Text(status.label)
      .font(.halSmall.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 9)
      .padding(.vertical, 4)
      .background(color, in: Capsule())
      .accessibilityLabel("Application status: \(status.label)")
  }

  private var isRunningInWorkspace: Bool {
    guard
      let bundleIdentifier = application.details.first(where: {
        $0.label == "Bundle identifier"
      })?.value
    else { return false }
    return NSWorkspace.shared.runningApplications.contains {
      $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
    }
  }

  private var originSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle("Origin story", symbol: "arrow.down.to.line.compact")
      if story.provenance.isEmpty && story.owners.isEmpty {
        calmEmpty("HAL does not have enough retained evidence to name an installation source.")
      } else {
        ForEach(orderedProvenance) { detail in
          originRow(label: detail.label) {
            Text(detail.value)
              .fontWeight(.semibold)
              .textSelection(.enabled)
          }
        }
      }
      if let path = application.details.first(where: { $0.label == "Path" })?.value {
        originRow(label: "File path") {
          PathActionMenu(path: path)
            .fontWeight(.semibold)
        }
      }
      if !story.owners.isEmpty {
        ApplicationStoryFilesystemTree(
          items: story.owners.map {
            ApplicationStoryTreeItem(entity: $0.entity, relationship: $0.relationship)
          },
          inspect: model.focus
        )
      }
    }
  }

  private func originRow<Content: View>(
    label: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      content()
    }
    .padding(12)
    .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
  }

  private var orderedProvenance: [Detail] {
    story.provenance.sorted {
      let left = $0.label == "Installed with" || $0.label == "Installation source"
      let right = $1.label == "Installed with" || $1.label == "Installation source"
      return left && !right
    }
  }

  private func storySection(
    title: String,
    symbol: String,
    emptyMessage: String,
    connections: [ApplicationStoryModel.Connection]
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle(title, symbol: symbol)
      if connections.isEmpty {
        calmEmpty(emptyMessage)
      } else {
        ApplicationStoryFilesystemTree(
          items: connections.map {
            ApplicationStoryTreeItem(entity: $0.entity, relationship: $0.relationship)
          },
          inspect: model.focus
        )
      }
    }
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
      VStack(alignment: .leading, spacing: 12) {
        sectionTitle("Explore the evidence", symbol: "safari")
        GlossaryAwareText(
          "The story is the summary. Open the preview for the full node explorer and inspector.",
          context: "evidence"
        )
        .foregroundStyle(.secondary)
        Button {
          showsRelationshipMap = true
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            ApplicationRelationshipPreview(
              graph: model.presentedGraph,
              layout: model.layout,
              configuration: model.configuration.layout
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
      }
      .padding(18)
      .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

      Button {
        model.navigate(to: .filesystem)
      } label: {
        Label("Open Filesystem Map", systemImage: "folder.badge.gearshape")
      }
      .buttonStyle(.bordered)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
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
