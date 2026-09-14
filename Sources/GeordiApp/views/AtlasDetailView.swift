import AppKit
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiVisualization
import SwiftUI

struct AtlasDetailView: View {
  let model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      contextSummary
      GeometryReader { proxy in
        if proxy.size.width >= 1_050 {
          HSplitView {
            map
              .frame(minWidth: 620)
            inspector
              .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
          }
        } else {
          VSplitView {
            map
              .frame(minHeight: 430)
            inspector
              .frame(minHeight: 210, idealHeight: 260, maxHeight: 340)
          }
        }
      }
    }
  }

  private var map: some View {
    RelationshipCanvas(
      graph: model.presentedGraph,
      layout: model.layout,
      visibleTypes: Set(EntityType.allCases),
      selection: Binding(
        get: { model.selection },
        set: { model.selection = $0 }
      ),
      focusedEntity: Binding(
        get: { model.focusedEntity },
        set: { model.focusedEntity = $0 }
      ),
      configuration: model.configuration.layout,
      centerEntityID: centerEntityID,
      onRecenterEntity: model.focus
    )
  }

  private var centerEntityID: EntityID? {
    guard case .entity(let id) = model.destination else { return nil }
    return id
  }

  private var inspector: some View {
    InspectorView(
      graph: model.presentedGraph,
      sourceGraph: model.fixture,
      selection: model.selection,
      onShowEntityTypeInfo: { model.entityTypeReferencePresented = $0 },
      onOpenEntity: model.focus,
      canGoBack: model.canGoBackInGraphHistory,
      canGoForward: model.canGoForwardInGraphHistory,
      onGoBack: model.goBackInGraphHistory,
      onGoForward: model.goForwardInGraphHistory
    )
  }

  private var contextSummary: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text(summaryTitle)
          .font(.section.bold())
        Text(summaryText)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        model.referencePresented = true
      } label: {
        Label("How this map works", systemImage: "questionmark.circle")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("mapReferenceButton")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private var summaryTitle: String {
    switch model.destination {
    case .storage: "What could be safely removed?"
    case .applications: "What software is installed?"
    case .startup: "What starts automatically?"
    case .commandLine: "How is the command-line environment assembled?"
    case .dupeReview: "Where are duplicate files costing space?"
    case .shellPath: "How does the shell build PATH?"
    case .filesystem: "Where does observed software live?"
    case .performance:
      model.isSynthetic ? "What changed during the memory spike?" : "What is running now?"
    case .entity(let id): model.fixture.entity(id)?.name ?? "Selected item"
    case .overview: "This Mac"
    }
  }

  private var summaryText: String {
    return switch model.destination {
    case .storage:
      if model.isSynthetic {
        "24.4 GB is likely rebuildable or redownloadable. Profiles, configuration, and application data remain protected."
      } else {
        "\(AppBrand.displayName) observed configured rebuildable or redownloadable roots using metadata only. Sizes were not collected, and no removal action is enabled."
      }
    case .applications:
      if model.isSynthetic {
        "Explore familiar applications alongside Homebrew, Oh My Zsh, and an npm-installed TypeScript package."
      } else {
        "\(AppBrand.displayName) observed \(model.applicationScopeCounts.total) application bundles in the configured read-only search roots."
      }
    case .startup:
      "Startup declarations are shown separately from running processes. A declaration means software may start automatically; it does not prove the software is running now."
    case .commandLine:
      "Package managers, packages, shell frameworks, and observed processes are connected by retained ownership and runtime evidence."
    case .shellPath:
      "Analyze explicitly pasted shell configuration as a deterministic sequence. Variables \(AppBrand.displayName) cannot resolve remain visible instead of being guessed."
    case .dupeReview:
      "Duplicate groups are ranked by confidence, from identical bytes to same-name hunches. This view only reports; deletion happens from the command-line review or a future app surface."
    case .filesystem:
      "A curated hierarchy of explanatory locations and observed paths; \(AppBrand.displayName) has not indexed the whole disk."
    case .performance:
      if model.isSynthetic {
        "A Docker build, VS Code indexing, and restored Brave tabs overlapped; \(AppBrand.displayName) does not claim timing alone proves causation."
      } else {
        "\(AppBrand.displayName) retained a bounded point-in-time process sample. It has not collected performance history or inferred a past incident."
      }
    case .entity(let id):
      model.fixture.entity(id)?.summary ?? "Select a connected item to understand its role."
    case .overview:
      "Choose a system to explore."
    }
  }
}

struct SearchField: View {
  @Binding var query: String
  let results: [Entity]
  let onSelect: (Entity) -> Void
  @State private var presented = false

  var body: some View {
    TextField("Find an app, file, or event", text: $query)
      .textFieldStyle(.plain)
      .padding(.horizontal, 10)
      .frame(width: 250, height: 28)
      .background(Color(nsColor: .controlBackgroundColor))
      .overlay {
        Rectangle()
          .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
      }
      .onSubmit {
        presented = !query.isEmpty
      }
      .onChange(of: query) { _, value in
        if value.isEmpty {
          presented = false
        }
      }
      .popover(isPresented: $presented, arrowEdge: .bottom) {
        Group {
          if results.isEmpty {
            ContentUnavailableView.search(text: query)
          } else {
            List(results) { entity in
              Button {
                onSelect(entity)
                presented = false
              } label: {
                VStack(alignment: .leading) {
                  Text(entity.name)
                  if let distinguishingDetail = entity.details.first?.value {
                    Text(distinguishingDetail)
                      .font(.small)
                      .foregroundStyle(.secondary)
                  } else if entity.type != .application {
                    Text(entity.summary)
                      .font(.small)
                      .foregroundStyle(.secondary)
                  }
                }
              }
              .buttonStyle(.plain)
            }
          }
        }
        .frame(width: 400, height: min(320, CGFloat(max(results.count, 1) * 62)))
      }
  }
}
