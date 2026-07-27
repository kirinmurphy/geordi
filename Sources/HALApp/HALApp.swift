import AppKit
import HALDomain
import HALFixtures
import HALVisualization
import SwiftUI

@main
struct HALApp: App {
  @NSApplicationDelegateAdaptor(HALApplicationDelegate.self) private var applicationDelegate

  var body: some Scene {
    WindowGroup {
      ContentView(
        configuration: .phaseZero,
        snapshotProvider: SyntheticGraphProvider(
          fixtureID: AppConfiguration.phaseZero.initialFixtureID
        )
      )
      .frame(minWidth: 1_080, minHeight: 680)
    }
    .windowStyle(.hiddenTitleBar)
    .commands {
      SidebarCommands()
      InspectorCommands()
    }
  }
}

final class HALApplicationDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

@MainActor
@Observable
final class AppModel {
  enum DataFreshness {
    case upToDate
    case aFewMinutesAgo
    case aWhileAgo
  }

  enum Destination: Hashable {
    case overview
    case storage
    case applications
    case performance
    case entity(EntityID)
  }

  let configuration: AppConfiguration
  let scanContext: ScanContext
  var fixture: SystemGraph
  var destination: Destination = .overview
  var selection: GraphSelection?
  var focusedEntity: EntityID?
  var searchQuery = ""
  var visibleTypes = Set(EntityType.allCases)
  var inspectorPresented = true
  var referencePresented = false
  var entityTypeReferencePresented: EntityType?
  private(set) var lastSuccessfulUpdate = Date()

  init(configuration: AppConfiguration, snapshotProvider: any GraphSnapshotProvider) {
    self.configuration = configuration
    let snapshot = snapshotProvider.snapshot()
    fixture = snapshot.graph
    scanContext = snapshot.scan
    lastSuccessfulUpdate = snapshot.scan.completedAt ?? snapshot.scan.startedAt
  }

  var layout: LayoutResult {
    SemanticLayout(configuration: configuration.layout).layout(presentedGraph)
  }

  var searchResults: [Entity] {
    GraphNavigator(graph: fixture).search(searchQuery, visibleTypes: visibleTypes)
  }

  var presentedGraph: SystemGraph {
    switch destination {
    case .overview:
      fixture.filtered(to: [.application, .resource, .incident])
    case .storage:
      fixture.neighborhood(around: "resource.storage", depth: 2)
    case .applications:
      fixture.filtered(to: [
        .application, .packageManager, .shellFramework, .package, .persistence,
      ])
    case .performance:
      fixture.neighborhood(around: "incident.build", depth: 2)
    case .entity(let id):
      fixture.neighborhood(around: id, depth: 2)
    }
  }

  var breadcrumb: [String] {
    switch destination {
    case .overview: ["Home"]
    case .storage: ["Home", "Storage"]
    case .applications: ["Home", "Installed software"]
    case .performance: ["Home", "Performance"]
    case .entity(let id):
      ["Home", fixture.entity(id)?.name ?? "Item"]
    }
  }

  func dataFreshness(at currentDate: Date = Date()) -> DataFreshness {
    let age = currentDate.timeIntervalSince(lastSuccessfulUpdate)
    if age < 2 * 60 {
      return .upToDate
    }
    if age < 15 * 60 {
      return .aFewMinutesAgo
    }
    return .aWhileAgo
  }

  func navigate(to destination: Destination) {
    self.destination = destination
    switch destination {
    case .overview:
      selection = nil
    case .storage:
      selection = GraphSelection(.entity("resource.storage"))
    case .applications:
      selection = nil
    case .performance:
      selection = GraphSelection(.entity("incident.build"))
    case .entity(let id):
      selection = GraphSelection(.entity(id))
    }
    focusedEntity = nil
    searchQuery = ""
  }

  func focus(_ entity: Entity) {
    if !visibleTypes.contains(entity.type) {
      visibleTypes.insert(entity.type)
    }
    destination = .entity(entity.id)
    selection = GraphSelection(.entity(entity.id))
    focusedEntity = entity.id
  }
}
