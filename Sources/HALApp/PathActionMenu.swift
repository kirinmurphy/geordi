import AppKit
import HALDomain
import HALVisualization
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class TerminalSelectionModel: ObservableObject {
  static let shared = TerminalSelectionModel()

  @Published private(set) var activationOrder: [String] = []
  @Published private(set) var preferredBundleIdentifier: String?
  let configuration = try? TerminalAdapterConfiguration.bundled()
  private var observer: NSObjectProtocol?
  private let preferenceKey = "preferredTerminalBundleIdentifier"

  private init() {
    preferredBundleIdentifier = UserDefaults.standard.string(forKey: preferenceKey)
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

  var availableAdapters: [AvailableTerminalAdapter] {
    guard let configuration else { return [] }
    let installed = configuration.adapters.compactMap {
      adapter
        -> InstalledTerminalApplication? in
      guard
        let applicationURL = NSWorkspace.shared.urlForApplication(
          withBundleIdentifier: adapter.bundleIdentifier
        )
      else { return nil }
      return InstalledTerminalApplication(
        bundleIdentifier: adapter.bundleIdentifier,
        declaredURLSchemes: declaredURLSchemes(at: applicationURL)
      )
    }
    return TerminalAvailabilityResolver().availableAdapters(
      configuration: configuration,
      installedApplications: installed,
      runningBundleIdentifiers: Set(
        NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
      ),
      activationOrder: activationOrder,
      preferredBundleIdentifier: preferredBundleIdentifier
    )
  }

  func setPreferred(_ bundleIdentifier: String) {
    preferredBundleIdentifier = bundleIdentifier
    UserDefaults.standard.set(bundleIdentifier, forKey: preferenceKey)
  }

  var preferredCustomApplicationURL: URL? {
    guard let preferredBundleIdentifier,
      configuration?.adapters.contains(where: {
        $0.bundleIdentifier == preferredBundleIdentifier
      }) != true
    else { return nil }
    return NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: preferredBundleIdentifier
    )
  }

  private func declaredURLSchemes(at applicationURL: URL) -> Set<String> {
    guard let bundle = Bundle(url: applicationURL),
      let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes")
        as? [[String: Any]]
    else { return [] }
    return Set(
      types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    )
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
        Menu("Open in Terminal", systemImage: "terminal") {
          if let applicationURL = terminals.preferredCustomApplicationURL {
            Button("✓ \(applicationURL.deletingPathExtension().lastPathComponent) (Chosen)") {
              openDirectory(with: applicationURL)
            }
            Divider()
          }
          Button("Choose Another Application…") { chooseAnotherApplication() }
        }
      } else {
        Menu("Open in Terminal", systemImage: "terminal") {
          ForEach(terminals.availableAdapters) { available in
            Button(adapterLabel(available)) { open(in: available.adapter) }
          }
          if let applicationURL = terminals.preferredCustomApplicationURL {
            Button("✓ \(applicationURL.deletingPathExtension().lastPathComponent) (Chosen)") {
              openDirectory(with: applicationURL)
            }
          }
          Divider()
          Menu("Set Preferred Terminal") {
            ForEach(terminals.availableAdapters) { available in
              Button(preferenceLabel(available)) {
                terminals.setPreferred(available.adapter.bundleIdentifier)
              }
            }
          }
          Button("Choose Another Application…") { chooseAnotherApplication() }
        }
      }
    } label: {
      HStack(spacing: 5) {
        Text(path)
          .underline()
          .lineLimit(2)
          .truncationMode(.middle)
          .textSelection(.enabled)
        Image(systemName: "chevron.down")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.secondary)
      }
    }
    .menuIndicator(.hidden)
    .menuStyle(.borderlessButton)
    .accessibilityLabel("Path \(path)")
    .accessibilityHint("Shows options to copy, reveal, or open this path")
  }

  private var targetURL: URL { URL(fileURLWithPath: path).standardizedFileURL }

  private var directoryURL: URL {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
      atPath: targetURL.path,
      isDirectory: &isDirectory
    )
    let directoryPath =
      TerminalPathTarget.directoryPath(
        for: path,
        exists: exists,
        isDirectory: isDirectory.boolValue
      ) ?? targetURL.deletingLastPathComponent().path
    return URL(fileURLWithPath: directoryPath, isDirectory: true)
  }

  private var isSafeAbsolutePath: Bool {
    path.hasPrefix("/") && !URL(fileURLWithPath: path).pathComponents.contains("..")
  }

  private func open(in adapter: TerminalAdapter) {
    guard isSafeAbsolutePath else { return }
    switch adapter.strategy {
    case .workspaceOpen:
      guard
        let applicationURL = NSWorkspace.shared.urlForApplication(
          withBundleIdentifier: adapter.bundleIdentifier
        )
      else { return }
      openDirectory(with: applicationURL)
    case .warpNewWindowURL:
      var components = URLComponents()
      components.scheme = "warp"
      components.host = "action"
      components.path = "/new_window"
      components.queryItems = [URLQueryItem(name: "path", value: directoryURL.path)]
      guard let url = components.url else { return }
      NSWorkspace.shared.open(url)
    }
  }

  private func adapterLabel(_ available: AvailableTerminalAdapter) -> String {
    [
      available.isPreferred ? "✓" : nil,
      available.adapter.displayName,
      available.isRunning ? "(Running)" : nil,
    ].compactMap { $0 }.joined(separator: " ")
  }

  private func preferenceLabel(_ available: AvailableTerminalAdapter) -> String {
    "\(available.isPreferred ? "✓ " : "")\(available.adapter.displayName)"
  }

  private func chooseAnotherApplication() {
    guard isSafeAbsolutePath else { return }
    let panel = NSOpenPanel()
    panel.title = "Choose an application for this folder"
    panel.prompt = "Choose"
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    panel.allowedContentTypes = [.application]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let applicationURL = panel.url,
      let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier
    else { return }

    let alert = NSAlert()
    alert.messageText =
      "Open this folder with \(applicationURL.deletingPathExtension().lastPathComponent)?"
    alert.informativeText =
      "\(AppBrand.displayName) has not reviewed this application's folder-opening behavior. You chose it explicitly."
    alert.addButton(withTitle: "Open Once")
    alert.addButton(withTitle: "Open and Remember")
    alert.addButton(withTitle: "Cancel")
    switch alert.runModal() {
    case .alertFirstButtonReturn:
      openDirectory(with: applicationURL)
    case .alertSecondButtonReturn:
      terminals.setPreferred(bundleIdentifier)
      openDirectory(with: applicationURL)
    default:
      break
    }
  }

  private func openDirectory(with applicationURL: URL) {
    NSWorkspace.shared.open(
      [directoryURL],
      withApplicationAt: applicationURL,
      configuration: NSWorkspace.OpenConfiguration()
    )
  }
}
