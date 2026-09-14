import Foundation
import GeordiDomain

/// Outcome of enabling (or checking) the bundled CLI link at the PATH
/// location. Mirrors the CLI installer's preflight semantics — the app
/// never overwrites an unrelated target and never enables without an
/// explicit user action.
enum CLILinkStatus: Equatable {
  case notInstalled
  case installed(target: String)
  case dangling(previousTarget: String?)
  case wrongTarget(previousTarget: String)
  case occupied(description: String)
}

/// Runs the bundled `geordi install-cli` command (same Installer as
/// scripts/install-cli.py — reused, not forked) and classifies the
/// current PATH link state. Filesystem inspection is read-only; the
/// mutating step is only ever triggered by an explicit user action.
@MainActor
@Observable
final class CLIEnablementModel {
  enum Phase: Equatable {
    case idle
    case running
    case succeeded
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  private(set) var status: CLILinkStatus = .notInstalled
  let linkLocation: String

  private let processRunner: (String, [String]) async -> (Int32, String, String)

  static let defaultLinkDirectory = "/opt/homebrew/bin"

  init(
    linkLocation: String = CLIEnablementModel.defaultLinkDirectory,
    processRunner: @escaping (String, [String]) async -> (Int32, String, String) =
      CLIEnablementModel.defaultProcessRunner
  ) {
    self.linkLocation = linkLocation
    self.processRunner = processRunner
  }

  var onboardingCardVisible: Bool {
    if case .succeeded = phase { return false }
    return status != .installed(target: linkLocation + "/" + AppBrand.cliCommand)
  }

  func refresh() async {
    status = await Self.classify(
      linkDirectory: linkLocation, command: AppBrand.cliCommand)
  }

  func enable() async {
    guard phase != .running else { return }
    phase = .running
    let (code, _, stderr) = await processRunner(
      bundledInstallCLIPath(), ["--prefix", CLIEnablementModel.defaultLinkDirectory])
    if code == 0 {
      phase = .succeeded
      await refresh()
    } else {
      phase = .failed(stderr.isEmpty ? "Installer exited with code \(code)." : stderr)
    }
  }

  func bundledInstallCLIPath() -> String {
    // Bundled layout: Contents/Resources/geordi/cli/bin/install-cli
    // (declared by bundle-layout.json); repo fallback for development.
    let bundle = Bundle.main.bundleURL
    let staged =
      bundle
      .appendingPathComponent("Contents/Resources/geordi/cli/bin/install-cli")
    if FileManager.default.isExecutableFile(atPath: staged.path) {
      return staged.path
    }
    return "/usr/bin/env python3"
  }

  // MARK: - Path classification (read-only)

  static func classify(
    linkDirectory: String, command: String,
    fileManager: FileManager = .default
  ) -> CLILinkStatus {
    let target = URL(fileURLWithPath: linkDirectory)
      .appendingPathComponent(command).path
    guard fileManager.fileExists(atPath: target) else {
      // distinguish "nothing there" from "dangling symlink"
      if let destination = try? fileManager.destinationOfSymbolicLink(
        atPath: target)
      {
        return .dangling(previousTarget: destination)
      }
      return .notInstalled
    }
    guard
      let destination = try? fileManager.destinationOfSymbolicLink(
        atPath: target)
    else {
      return .occupied(description: "a non-symlink file exists at \(target)")
    }
    let resolved = URL(fileURLWithPath: target).resolvingSymlinksInPath().path
    if resolved.contains("Contents/MacOS") || resolved.contains("Contents/Resources") {
      return .installed(target: destination)
    }
    return .wrongTarget(previousTarget: destination)
  }

  nonisolated static func defaultProcessRunner(
    _ launchPath: String, _ arguments: [String]
  ) async -> (Int32, String, String) {
    // The bundled entry point is a Python script; run it with env python.
    let executable: String
    let finalArguments: [String]
    if launchPath.hasSuffix("install-cli") {
      executable = "/usr/bin/python3"
      finalArguments = [launchPath] + arguments
    } else {
      executable = launchPath
      finalArguments = arguments
    }
    return await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = finalArguments
      let stdout = Pipe()
      let stderr = Pipe()
      process.standardOutput = stdout
      process.standardError = stderr
      do {
        try process.run()
      } catch {
        continuation.resume(returning: (-1, "", "\(error)"))
        return
      }
      process.terminationHandler = { _ in
        let out =
          String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err =
          String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        continuation.resume(returning: (process.terminationStatus, out, err))
      }
    }
  }
}
