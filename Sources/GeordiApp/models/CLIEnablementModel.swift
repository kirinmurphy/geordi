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

/// Runs the bundled `geordi repair-cli` command (same Installer as
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
  /// What `--prefix` means to the installer: it appends `/bin` itself.
  static let defaultInstallPrefix = "/opt/homebrew"

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
    guard let installerPath = bundledInstallCLIPath() else {
      phase = .failed(
        "The CLI installer is not present in this build of \(AppBrand.displayName)."
      )
      return
    }
    phase = .running
    let (code, _, stderr) = await processRunner(
      installerPath, ["--prefix", CLIEnablementModel.defaultInstallPrefix])
    if code == 0 {
      phase = .succeeded
      await refresh()
    } else {
      phase = .failed(stderr.isEmpty ? "Installer exited with code \(code)." : stderr)
    }
  }

  /// Locates the bundled `repair-cli` script. Returns nil (never a
  /// multi-token command string) when no staged installer exists, so the
  /// caller can surface a clear message instead of a launch failure.
  func bundledInstallCLIPath() -> String? {
    let staged =
      Bundle.main.bundleURL
      .appendingPathComponent("Contents/Resources/geordi/cli/bin/repair-cli")
    if FileManager.default.isExecutableFile(atPath: staged.path) {
      return staged.path
    }
    // Development layouts: a bare SwiftPM binary or the unpackaged
    // .build/<config>/<App>.app both live inside the repo's .build
    // directory — the repo's staged CLI is at <repo>/cli/bin/repair-cli.
    var directory = Bundle.main.bundleURL
    for _ in 0..<3 {
      directory.deleteLastPathComponent()
    }
    let repoCandidate = directory.appendingPathComponent("cli/bin/repair-cli")
    if FileManager.default.isExecutableFile(atPath: repoCandidate.path) {
      return repoCandidate.path
    }
    return nil
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
    if launchPath.hasSuffix("repair-cli") {
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
