import AppKit
import HALVisualization
import SwiftUI

@MainActor
final class TerminalSelectionModel: ObservableObject {
  static let shared = TerminalSelectionModel()

  @Published private(set) var activationOrder: [String] = []
  let configuration = try? TerminalAdapterConfiguration.bundled()
  private var observer: NSObjectProtocol?

  private init() {
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        let identifier = application.bundleIdentifier
      else { return }
      Task { @MainActor in self?.recordActivation(identifier) }
    }
  }

  private func recordActivation(_ identifier: String) {
    guard configuration?.adapters.contains(where: { $0.bundleIdentifier == identifier }) == true
    else { return }
    activationOrder.removeAll { $0 == identifier }
    activationOrder.insert(identifier, at: 0)
  }

  var availableAdapters: [TerminalAdapter] {
    let running = Set(
      NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
    )
    return (configuration?.adapters ?? []).filter {
      running.contains($0.bundleIdentifier)
        || NSWorkspace.shared.urlForApplication(
          withBundleIdentifier: $0.bundleIdentifier
        ) != nil
    }
    .sorted { lhs, rhs in rank(lhs) < rank(rhs) }
  }

  private func rank(_ adapter: TerminalAdapter) -> Int {
    activationOrder.firstIndex(of: adapter.bundleIdentifier)
      ?? (NSWorkspace.shared.runningApplications.contains {
        $0.bundleIdentifier == adapter.bundleIdentifier
      } ? 10_000 : 20_000)
  }
}

struct PathActionMenu: View {
  let path: String
  @StateObject private var terminals = TerminalSelectionModel.shared

  var body: some View {
    Menu {
      Button("Copy Path", systemImage: "doc.on.doc") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
      }
      Button("Reveal in Finder", systemImage: "folder") {
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
      }
      .disabled(!isSafeAbsolutePath)
      if terminals.availableAdapters.isEmpty {
        Button("Open in Terminal…", systemImage: "terminal") {
          NSWorkspace.shared.open(directoryURL)
        }
        .disabled(!isSafeAbsolutePath)
      } else {
        Menu("Open in \(terminals.availableAdapters[0].displayName)", systemImage: "terminal") {
          ForEach(terminals.availableAdapters) { adapter in
            Button(adapter.displayName) { open(in: adapter) }
          }
        }
        .disabled(!isSafeAbsolutePath)
      }
    } label: {
      HStack(spacing: 5) {
        Text(path)
          .lineLimit(2)
          .truncationMode(.middle)
          .textSelection(.enabled)
        Image(systemName: "chevron.down")
          .font(.caption2)
      }
    }
    .menuStyle(.borderlessButton)
    .accessibilityLabel("Path \(path)")
    .accessibilityHint("Shows options to copy, reveal, or open this path")
  }

  private var targetURL: URL { URL(fileURLWithPath: path).standardizedFileURL }

  private var directoryURL: URL {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    {
      return targetURL
    }
    return targetURL.deletingLastPathComponent()
  }

  private var isSafeAbsolutePath: Bool {
    path.hasPrefix("/") && !URL(fileURLWithPath: path).pathComponents.contains("..")
  }

  private func open(in adapter: TerminalAdapter) {
    guard isSafeAbsolutePath,
      let applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: adapter.bundleIdentifier
      )
    else { return }
    NSWorkspace.shared.open(
      [directoryURL],
      withApplicationAt: applicationURL,
      configuration: NSWorkspace.OpenConfiguration()
    )
  }
}
