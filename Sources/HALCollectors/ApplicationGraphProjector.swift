import Foundation
import HALDomain

public struct ApplicationGraphProjector: Sendable {
  public init() {}

  public func snapshot(
    scanID: ScanID,
    output: CollectorOutput<ApplicationBundleValue>,
    signatures: CollectorOutput<ApplicationSignatureValue>? = nil,
    provenance: CollectorOutput<ApplicationProvenanceValue>? = nil,
    associatedLocations: CollectorOutput<ApplicationAssociatedLocationValue>? = nil,
    rebuildableData: CollectorOutput<RebuildableDataValue>? = nil,
    processes: CollectorOutput<ProcessValue>? = nil,
    processResolutions: CollectorOutput<ProcessApplicationResolutionValue>? = nil,
    maxProcessesPerApplication: Int = 8,
    maxUnmatchedProcesses: Int = 0,
    persistence: CollectorOutput<PersistenceDeclarationValue>? = nil,
    persistenceResolutions: CollectorOutput<PersistenceApplicationResolutionValue>? = nil,
    homebrew: CollectorOutput<HomebrewInventoryValue>? = nil,
    runtimes: CollectorOutput<RuntimeValue>? = nil,
    packageEcosystems: CollectorOutput<PackageEcosystemInventoryValue>? = nil,
    commandLineSoftware: CollectorOutput<CommandLineSoftwareValue>? = nil,
    shellFrameworks: CollectorOutput<ShellFrameworkValue>? = nil,
    applicationClassifications: ApplicationClassificationConfiguration? = nil
  ) -> GraphSnapshot {
    let signaturesByPath = Dictionary(
      uniqueKeysWithValues: (signatures?.observations ?? []).map {
        ($0.value.applicationPath, $0.value)
      }
    )
    let provenanceByPath = Dictionary(
      uniqueKeysWithValues: (provenance?.observations ?? []).map {
        ($0.value.applicationPath, $0.value)
      }
    )
    let caskMatches:
      [String: (inventory: CollectedObservation<HomebrewInventoryValue>, cask: HomebrewCaskValue)] =
        Dictionary(
          uniqueKeysWithValues: output.observations.compactMap { application in
            let candidates = (homebrew?.observations ?? []).flatMap { inventory in
              inventory.value.casks.flatMap { cask in
                cask.artifacts.compactMap {
                  artifact
                    -> (CollectedObservation<HomebrewInventoryValue>, HomebrewCaskValue)? in
                  let bundleMatches =
                    application.value.bundleIdentifier != nil
                    && artifact.bundleIdentifier == application.value.bundleIdentifier
                  let nameMatches =
                    artifact.applicationName
                    == URL(fileURLWithPath: application.value.path).lastPathComponent
                  return bundleMatches || nameMatches ? (inventory, cask) : nil
                }
              }
            }
            guard candidates.count == 1, let match = candidates.first else { return nil }
            return (application.value.path, match)
          }
        )
    let applicationEntities = output.observations.map { observation in
      let value = observation.value
      var applicationDetails = details(
        for: value,
        signature: signaturesByPath[value.path],
        provenance: provenanceByPath[value.path]
      )
      if let match = caskMatches[value.path] {
        applicationDetails.append(
          Detail("Installed with", "Homebrew cask \(match.cask.token)")
        )
      }
      if let applicationClassifications {
        let category = applicationClassifications.category(
          forApplicationPath: value.path,
          platformBinary: signaturesByPath[value.path]?.platformBinary,
          details: applicationDetails
        )
        applicationDetails.append(Detail("Display group", category.label))
      }
      return Entity(
        id: entityID(for: observation),
        type: .application,
        name: value.name,
        summary: "An application bundle observed on this Mac.",
        details: applicationDetails
      )
    }
    let applicationIDsByPath = Dictionary(
      uniqueKeysWithValues: output.observations.map {
        ($0.value.path, entityID(for: $0))
      }
    )
    let appStoreApplications = output.observations.filter { application in
      provenanceByPath[application.value.path]?.facts.contains {
        $0.kind == .appStoreReceipt && $0.status == .present
      } == true
    }
    let appStoreManagerEntities: [Entity] =
      appStoreApplications.isEmpty
      ? []
      : [
        Entity(
          id: "package-manager:app-store",
          type: .packageManager,
          name: "App Store",
          summary: "Applications managed through observed Mac App Store receipts.",
          details: [
            Detail("Installed applications", "\(appStoreApplications.count)"),
            Detail("Ownership evidence", "Application bundle receipts"),
          ]
        )
      ]
    let appStoreRelationships = appStoreApplications.compactMap { application -> Relationship? in
      guard
        let provenanceObservation = provenance?.observations.first(where: {
          $0.value.applicationPath == application.value.path
        })
      else { return nil }
      return Relationship(
        id: RelationshipID("app-store-application:\(entityID(for: application).rawValue)"),
        source: "package-manager:app-store",
        target: entityID(for: application),
        type: .owns,
        confidence: .confirmed,
        explanation: "The application bundle contains a Mac App Store receipt.",
        evidence: [
          Evidence(
            id: "\(provenanceObservation.id.rawValue):app-store-ownership",
            kind: .observed,
            summary: "A receipt file was present at the declared Mac App Store receipt location.",
            source: "Read-only application bundle receipt location",
            observationID: provenanceObservation.id,
            observedAt: provenanceObservation.observedAt
          )
        ]
      )
    }
    let presentAssociations = preferredPresentAssociations(
      associatedLocations?.observations ?? []
    )
    let locationEntities = Dictionary(
      presentAssociations.map { association in
        let value = association.value
        return (
          locationEntityID(for: value),
          Entity(
            id: locationEntityID(for: value),
            type: .file,
            name: URL(fileURLWithPath: value.locationPath).lastPathComponent,
            summary:
              "A conventional \(value.categoryLabel.lowercased()) location observed on this Mac.",
            details: [
              Detail("Category", value.categoryLabel),
              Detail("Path", value.locationPath),
              Detail(
                "Association basis",
                associationBasis(value.match)
              ),
            ]
          )
        )
      },
      uniquingKeysWith: { first, _ in first }
    ).values.sorted { $0.id.rawValue < $1.id.rawValue }
    let relationships = presentAssociations.compactMap { association -> Relationship? in
      let value = association.value
      guard
        let applicationPath = value.applicationPath,
        let applicationID = applicationIDsByPath[applicationPath]
      else {
        return nil
      }
      let exact = value.match == .bundleIdentifier
      let applicationGroup = value.match == .applicationGroupIdentifier
      return Relationship(
        id: RelationshipID(
          "associated-location:\(applicationID.rawValue):\(value.locationID)"
        ),
        source: applicationID,
        target: locationEntityID(for: value),
        type: applicationGroup ? .shares : .mayBelongTo,
        confidence: exact || applicationGroup ? .high : .possible,
        explanation:
          applicationGroup
          ? "The application's signed entitlements authorize access to this shared group container."
          : exact
            ? "This location uses the application's exact bundle identifier, a strong conventional association that may be stale."
            : "This location matches the application name, but HAL cannot establish exclusive ownership.",
        evidence: [
          Evidence(
            id: "\(association.id.rawValue):observed",
            kind: .observed,
            summary: "The location exists at the recorded path.",
            source: "Read-only filesystem metadata",
            observationID: association.id,
            observedAt: association.observedAt
          ),
          Evidence(
            id: "\(association.id.rawValue):match",
            kind: exact || applicationGroup ? .derived : .inferred,
            summary:
              applicationGroup
              ? "The container name exactly matches a signed application-group entitlement."
              : exact
                ? "The final path component contains the exact application bundle identifier."
                : "The final path component matches the application name.",
            source:
              applicationGroup
              ? "Code-signing entitlements and associated-location manifest rule"
              : "Associated-location manifest rule",
            observationID: association.id,
            observedAt: association.observedAt,
            ruleID: value.locationID,
            ruleVersion: ApplicationAssociatedLocationCollector.version
          ),
        ]
      )
    }
    let rebuildableDataEntities = Dictionary(
      (rebuildableData?.observations ?? [])
        .filter {
          $0.value.status == .present
            && $0.value.isDirectory == true
            && $0.value.isSymbolicLink != true
        }
        .map { observation in
          let value = observation.value
          return (
            rebuildableDataEntityID(value.path),
            Entity(
              id: rebuildableDataEntityID(value.path),
              type: .file,
              name: URL(fileURLWithPath: value.path).lastPathComponent,
              summary:
                "A \(value.classificationLabel.lowercased()) location observed through a versioned detector.",
              details: [
                Detail("Classification", value.classificationLabel),
                Detail("Rebuildability", value.rebuildability.rawValue.capitalized),
                Detail("Path", value.path),
                Detail("Size", "Not collected"),
                Detail("Evidence rule", value.evidenceRuleID),
                Detail("Evidence confidence", value.evidenceConfidence.plainLanguage),
                Detail("Evidence explanation", value.evidenceExplanation),
              ]
            )
          )
        },
      uniquingKeysWith: { first, _ in first }
    ).values.sorted { $0.id.rawValue < $1.id.rawValue }
    let rebuildableManagerEntities = Dictionary(
      (rebuildableData?.observations ?? []).compactMap { observation -> (EntityID, Entity)? in
        guard
          observation.value.status == .present,
          let managerID = observation.value.managerID,
          let managerLabel = observation.value.managerLabel
        else { return nil }
        let id = packageManagerEntityID(managerID)
        return (
          id,
          Entity(
            id: id,
            type: .packageManager,
            name: managerLabel,
            summary: "A software manager inferred from one of its configured data roots."
          )
        )
      },
      uniquingKeysWith: { first, _ in first }
    )
    let rebuildableManagerRelationships = (rebuildableData?.observations ?? []).compactMap {
      observation -> Relationship? in
      guard
        observation.value.status == .present,
        let managerID = observation.value.managerID
      else { return nil }
      return Relationship(
        id: RelationshipID("manager-data:\(managerID):\(observation.value.locationID)"),
        source: packageManagerEntityID(managerID),
        target: rebuildableDataEntityID(observation.value.path),
        type: .owns,
        confidence: observation.value.evidenceConfidence,
        explanation: observation.value.evidenceExplanation,
        evidence: [
          Evidence(
            id: "\(observation.id.rawValue):manager",
            kind: .derived,
            summary: "The versioned detector identifies this as a manager-controlled root.",
            source: "Rebuildable-data detector manifest",
            observationID: observation.id,
            observedAt: observation.observedAt,
            ruleID: observation.value.evidenceRuleID,
            ruleVersion: RebuildableDataCollector.version
          )
        ]
      )
    }
    let processesByPID = Dictionary(
      uniqueKeysWithValues: (processes?.observations ?? []).map {
        ($0.value.pid, $0)
      }
    )
    let visibleProcessResolutions = preferredProcessResolutions(
      processResolutions?.observations ?? [],
      processesByPID: processesByPID,
      limit: maxProcessesPerApplication
    )
    let unresolvedProcessResolutions = preferredUnresolvedProcessResolutions(
      processResolutions?.observations ?? [],
      processesByPID: processesByPID,
      limit: maxUnmatchedProcesses
    )
    let processGroups = Dictionary(
      grouping: visibleProcessResolutions + unresolvedProcessResolutions
    ) { resolution in
      processGroupKey(resolution: resolution, processesByPID: processesByPID)
    }
    let sortedProcessGroups = processGroups.values.sorted {
      processGroupKey(resolution: $0[0], processesByPID: processesByPID)
        < processGroupKey(resolution: $1[0], processesByPID: processesByPID)
    }
    let runtimeEntities = (runtimes?.observations ?? []).map { observation in
      let matchingProcesses = (processes?.observations ?? []).filter { process in
        guard let executable = process.value.executablePath else { return false }
        return URL(filePath: executable).resolvingSymlinksInPath().standardizedFileURL.path
          == observation.value.resolvedExecutablePath
      }
      let memory = matchingProcesses.compactMap(\.value.residentMemoryBytes).reduce(0, +)
      var details = [
        Detail("Availability", "Available"),
        Detail("Executable", observation.value.executablePath),
        Detail("Resolved executable", observation.value.resolvedExecutablePath),
        Detail("Active instances", "\(matchingProcesses.count)"),
      ]
      if let version = observation.value.version {
        details.append(Detail("Version", version))
      }
      if memory > 0 {
        details.append(
          Detail(
            "Active memory at observation",
            ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
          )
        )
      }
      let entityName =
        switch observation.value.kind {
        case "toolchain": "\(observation.value.label) Toolchain"
        case "compiler": observation.value.label
        default: "\(observation.value.label) Runtime"
        }
      return Entity(
        id: EntityID("runtime-availability:\(observation.value.runtimeID)"),
        type: .package,
        name: entityName,
        summary: matchingProcesses.isEmpty
          ? "An executable tool was observed and answered a version query; no active process was observed."
          : "An executable tool was observed with \(matchingProcesses.count) active process instance(s).",
        details: [Detail("Capability kind", observation.value.kind.capitalized)] + details
      )
    }
    let runtimeInstallationRelationships = (runtimes?.observations ?? []).flatMap {
      observation in
      observation.value.packageIdentities.compactMap { identity -> Relationship? in
        guard identity.managerID == "homebrew",
          let installation = homebrew?.observations.first(where: {
            inventory in
            inventory.value.packages.contains { $0.name == identity.packageName }
          })
        else { return nil }
        return Relationship(
          id: RelationshipID(
            "package-capability:\(identity.managerID):\(identity.packageName):\(observation.value.runtimeID)"
          ),
          source: homebrewPackageEntityID(
            prefix: installation.value.prefix,
            name: identity.packageName
          ),
          target: EntityID("runtime-availability:\(observation.value.runtimeID)"),
          type: .provides,
          confidence: .confirmed,
          explanation:
            "The observed package identity is configured as providing this executable capability.",
          evidence: [
            Evidence(
              id: "\(observation.id.rawValue):package-identity",
              kind: .derived,
              summary:
                "\(identity.packageName) was observed in Homebrew and its configured executable was available.",
              source: "Runtime definition manifest and read-only software inventories",
              observationID: observation.id,
              observedAt: observation.observedAt,
              ruleID: "declared-package-capability-identity",
              ruleVersion: RuntimeCollector.version
            )
          ]
        )
      }
    }
    let processEntities = sortedProcessGroups.compactMap { resolutions -> Entity? in
      guard let firstResolution = resolutions.first,
        let firstProcess = processesByPID[firstResolution.value.processID]
      else { return nil }
      let sorted = resolutions.sorted { $0.value.processID < $1.value.processID }
      let partition = EntityInstancePartition(
        detailsByInstance: sorted.compactMap { resolution in
          guard let process = processesByPID[resolution.value.processID] else { return nil }
          return (
            id: "Process \(process.value.pid)",
            details: processDetails(process: process.value, resolution: resolution.value)
          )
        }
      )
      return Entity(
        id: processEntityID(
          resolution: firstResolution,
          process: firstProcess.value
        ),
        type: .process,
        name: firstProcess.value.name,
        summary: sorted.count == 1
          ? "A process observed in the point-in-time snapshot."
          : "\(sorted.count) instances of this process were observed in the point-in-time snapshot.",
        details: partition.sharedDetails,
        instances: sorted.count > 1 ? partition.instances : []
      )
    }
    let processRelationships = sortedProcessGroups.compactMap {
      resolutions -> Relationship? in
      guard let resolution = resolutions.first,
        let applicationPath = resolution.value.applicationPaths.first,
        let applicationID = applicationIDsByPath[applicationPath],
        let process = processesByPID[resolution.value.processID],
        let confidence = resolution.value.confidence,
        let strategyID = resolution.value.strategyID
      else { return nil }
      let processID = processEntityID(resolution: resolution, process: process.value)
      let observedEvidence = resolutions.compactMap { item -> Evidence? in
        guard let observedProcess = processesByPID[item.value.processID] else { return nil }
        return Evidence(
          id: "\(item.id.rawValue):process",
          kind: .observed,
          summary:
            "Process \(observedProcess.value.pid) and its executable path were present in one point-in-time snapshot.",
          source: "Read-only process snapshot",
          observationID: observedProcess.id,
          observedAt: observedProcess.observedAt
        )
      }
      return Relationship(
        id: RelationshipID("application-process:\(applicationID.rawValue):\(processID.rawValue)"),
        source: applicationID,
        target: processID,
        type: .launches,
        confidence: confidence,
        explanation:
          confidence == .confirmed
          ? "The observed executable exactly matches the application's main executable."
          : "The observed executable is contained inside the application bundle.",
        evidence: observedEvidence + [
          Evidence(
            id: "\(resolution.id.rawValue):resolution",
            kind: .derived,
            summary: "The executable path matched the application using a configured strategy.",
            source: "Process-to-application resolver",
            observationID: resolution.id,
            observedAt: resolution.observedAt,
            ruleID: strategyID,
            ruleVersion: ProcessApplicationResolver.version
          )
        ]
      )
    }
    let declarationsByPath = Dictionary(
      uniqueKeysWithValues: (persistence?.observations ?? []).map {
        ($0.value.declarationPath, $0)
      }
    )
    let matchedPersistence = (persistenceResolutions?.observations ?? []).filter {
      $0.value.state == .matched && $0.value.applicationPaths.count == 1
    }
    let persistenceEntities = matchedPersistence.compactMap { resolution -> Entity? in
      guard let declaration = declarationsByPath[resolution.value.declarationPath] else {
        return nil
      }
      var details = [
        Detail("Declaration", declaration.value.declarationPath),
        Detail(
          "Type",
          declaration.value.kind == .launchAgent ? "Launch agent" : "Launch daemon"
        ),
        Detail("Run at load", declaration.value.runAtLoad ? "Yes" : "No"),
        Detail("Keep alive", declaration.value.keepAlive ? "Yes" : "No"),
      ]
      if let program = declaration.value.programPath {
        details.append(Detail("Program", program))
      }
      return Entity(
        id: persistenceEntityID(declaration.value.declarationPath),
        type: .persistence,
        name: declaration.value.label,
        summary: "A startup declaration observed on this Mac.",
        details: details
      )
    }
    let persistenceRelationships = matchedPersistence.compactMap {
      resolution -> Relationship? in
      guard
        let applicationPath = resolution.value.applicationPaths.first,
        let applicationID = applicationIDsByPath[applicationPath],
        let declaration = declarationsByPath[resolution.value.declarationPath],
        let confidence = resolution.value.confidence
      else {
        return nil
      }
      return Relationship(
        id: RelationshipID(
          "application-persistence:\(applicationID.rawValue):\(declaration.value.label)"
        ),
        source: applicationID,
        target: persistenceEntityID(declaration.value.declarationPath),
        type: .persistsThrough,
        confidence: confidence,
        explanation:
          "The declaration's executable is contained inside the application bundle.",
        evidence: [
          Evidence(
            id: "\(resolution.id.rawValue):declaration",
            kind: .observed,
            summary: "HAL read the declaration label and executable without retaining arguments.",
            source: "Read-only launchd property list",
            observationID: declaration.id,
            observedAt: declaration.observedAt
          ),
          Evidence(
            id: "\(resolution.id.rawValue):match",
            kind: .derived,
            summary: "The declared executable path is contained inside the application bundle.",
            source: "Persistence-to-application resolver",
            observationID: resolution.id,
            observedAt: resolution.observedAt,
            ruleID: "declared-program-bundle-containment",
            ruleVersion: PersistenceApplicationResolver.version
          ),
        ]
      )
    }
    let homebrewManagerEntities =
      (homebrew?.observations.first).map { observation in
        [
          Entity(
            id: homebrewManagerEntityID(observation.value.prefix),
            type: .packageManager,
            name: "Homebrew",
            summary: "A Homebrew installation observed through its configured Cellar.",
            details: [
              Detail("Prefix", observation.value.prefix),
              Detail("Cellar", observation.value.cellarPath),
              Detail("Caskroom", observation.value.caskroomPath),
              Detail("Installed formulae", "\(observation.value.packages.count)"),
              Detail("Installed casks", "\(observation.value.casks.count)"),
            ]
          )
        ]
      } ?? []
    let homebrewPackageEntities = (homebrew?.observations ?? []).flatMap { observation in
      observation.value.packages.map { package in
        let installationReason =
          switch package.installedOnRequest {
          case true: "Installed on request"
          case false: "Installed as a dependency"
          case nil: "Not recorded"
          }
        var details = [
          Detail("Package manager", "Homebrew"),
          Detail("Installed versions", package.versions.joined(separator: ", ")),
          Detail("Cellar", observation.value.cellarPath),
        ]
        details.append(
          Detail(
            "Installation reason",
            installationReason
          )
        )
        if !package.runtimeDependencies.isEmpty {
          details.append(
            Detail("Runtime dependencies", package.runtimeDependencies.joined(separator: ", "))
          )
        }
        let displayGroup =
          switch package.installedOnRequest {
          case true: "User-installed packages"
          case false: "Dependencies"
          case nil: "Packages"
          }
        details.append(
          Detail(
            "Display group",
            displayGroup
          )
        )
        return Entity(
          id: homebrewPackageEntityID(prefix: observation.value.prefix, name: package.name),
          type: .package,
          name: package.name,
          summary: "A formula installed in the observed Homebrew Cellar.",
          details: details
        )
      }
    }
    let homebrewPackageRelationships = (homebrew?.observations ?? []).flatMap { observation in
      observation.value.packages.map { package in
        Relationship(
          id: RelationshipID(
            "homebrew-package:\(observation.value.prefix):\(package.name)"
          ),
          source: homebrewManagerEntityID(observation.value.prefix),
          target: homebrewPackageEntityID(
            prefix: observation.value.prefix,
            name: package.name
          ),
          type: .owns,
          confidence: .confirmed,
          explanation: "Homebrew's Cellar contains this installed formula.",
          evidence: [
            Evidence(
              id: "\(observation.id.rawValue):\(package.name)",
              kind: .observed,
              summary: "A versioned formula directory was present in the Homebrew Cellar.",
              source: "Read-only Homebrew Cellar inventory",
              observationID: observation.id,
              observedAt: observation.observedAt
            )
          ]
        )
      }
    }
    let homebrewDependencyRelationships = (homebrew?.observations ?? []).flatMap { observation in
      let installedNames = Set(observation.value.packages.map(\.name))
      return observation.value.packages.flatMap { package in
        package.runtimeDependencies.compactMap { dependency -> Relationship? in
          guard installedNames.contains(dependency) else { return nil }
          return Relationship(
            id: RelationshipID(
              "homebrew-runtime-dependency:\(observation.value.prefix):\(package.name):\(dependency)"
            ),
            source: homebrewPackageEntityID(
              prefix: observation.value.prefix,
              name: package.name
            ),
            target: homebrewPackageEntityID(
              prefix: observation.value.prefix,
              name: dependency
            ),
            type: .consumes,
            confidence: .confirmed,
            explanation:
              "\(package.name) declares \(dependency) as an installed runtime dependency.",
            evidence: [
              Evidence(
                id: "\(observation.id.rawValue):dependency:\(package.name):\(dependency)",
                kind: .observed,
                summary:
                  "The installed formula receipt lists \(dependency) in runtime_dependencies.",
                source: "Read-only Homebrew INSTALL_RECEIPT.json",
                observationID: observation.id,
                observedAt: observation.observedAt
              )
            ]
          )
        }
      }
    }
    let homebrewCaskEntities = (homebrew?.observations ?? []).flatMap { observation in
      observation.value.casks.map { cask in
        Entity(
          id: homebrewCaskEntityID(prefix: observation.value.prefix, token: cask.token),
          type: .package,
          name: cask.token,
          summary: "A cask installed in the observed Homebrew Caskroom.",
          details: [
            Detail("Package manager", "Homebrew"),
            Detail("Package kind", "Cask"),
            Detail("Installed versions", cask.versions.joined(separator: ", ")),
            Detail(
              "Declared applications", cask.artifacts.map(\.applicationName).joined(separator: ", ")
            ),
            Detail("Caskroom", observation.value.caskroomPath),
          ]
        )
      }
    }
    let homebrewCaskRelationships = (homebrew?.observations ?? []).flatMap { observation in
      observation.value.casks.map { cask in
        return Relationship(
          id: RelationshipID("homebrew-cask:\(observation.value.prefix):\(cask.token)"),
          source: homebrewManagerEntityID(observation.value.prefix),
          target: homebrewCaskEntityID(prefix: observation.value.prefix, token: cask.token),
          type: .owns,
          confidence: .confirmed,
          explanation: "Homebrew's Caskroom contains this installed cask.",
          evidence: [
            Evidence(
              id: "\(observation.id.rawValue):cask:\(cask.token)",
              kind: .observed,
              summary: "A versioned cask directory was present in the Homebrew Caskroom.",
              source: "Read-only Homebrew Caskroom inventory",
              observationID: observation.id,
              observedAt: observation.observedAt
            )
          ]
        )
      }
    }
    let homebrewApplicationRelationships = output.observations.compactMap {
      application
        -> Relationship? in
      guard let match = caskMatches[application.value.path] else { return nil }
      return Relationship(
        id: RelationshipID("homebrew-cask-application:\(entityID(for: application).rawValue)"),
        source: homebrewCaskEntityID(
          prefix: match.inventory.value.prefix,
          token: match.cask.token
        ),
        target: entityID(for: application),
        type: .owns,
        confidence: .confirmed,
        explanation:
          "The cask's installed receipt declares this application artifact and its observed bundle identity matches.",
        evidence: [
          Evidence(
            id: "\(match.inventory.id.rawValue):cask-application:\(application.id.rawValue)",
            kind: .derived,
            summary:
              "The declared application artifact matched the observed application name or bundle identifier.",
            source: "Read-only Homebrew Caskroom receipt and application inventory",
            observationID: match.inventory.id,
            observedAt: match.inventory.observedAt,
            ruleID: "declared-cask-application-artifact",
            ruleVersion: HomebrewCollector.version
          )
        ]
      )
    }
    let ecosystemManagerEntities = (packageEcosystems?.observations ?? []).map { observation in
      Entity(
        id: packageManagerEntityID(observation.value.managerID),
        type: .packageManager,
        name: observation.value.managerLabel,
        summary: "A package manager with installed packages observed in configured roots.",
        details: [Detail("Installed packages", "\(observation.value.packages.count)")]
      )
    }
    let ecosystemPackageEntities = (packageEcosystems?.observations ?? []).flatMap {
      observation in
      observation.value.packages.map { package in
        Entity(
          id: ecosystemPackageEntityID(
            managerID: observation.value.managerID,
            package: package
          ),
          type: .package,
          name: package.name,
          summary: "An installed package observed in a configured package-manager root.",
          details: [
            Detail("Package manager", observation.value.managerLabel),
            Detail("Version", package.version ?? "Unavailable"),
            Detail("Path", package.path),
          ]
        )
      }
    }
    let ecosystemRelationships = (packageEcosystems?.observations ?? []).flatMap {
      observation in
      observation.value.packages.map { package in
        Relationship(
          id: RelationshipID(
            "ecosystem-package:\(observation.value.managerID):\(package.path)"
          ),
          source: packageManagerEntityID(observation.value.managerID),
          target: ecosystemPackageEntityID(
            managerID: observation.value.managerID,
            package: package
          ),
          type: .owns,
          confidence: .confirmed,
          explanation: "The package was present in this manager's configured installation root.",
          evidence: [
            Evidence(
              id: "\(observation.id.rawValue):\(package.path)",
              kind: .observed,
              summary: "Installed-package metadata was present in the configured root.",
              source: "Read-only package ecosystem inventory",
              observationID: observation.id,
              observedAt: observation.observedAt
            )
          ]
        )
      }
    }
    let runtimeExecutablePaths = Set(
      (runtimes?.observations ?? []).flatMap {
        [$0.value.executablePath, $0.value.resolvedExecutablePath]
      })
    let commandGroups = Dictionary(
      grouping: commandLineSoftware?.observations ?? [],
      by: \.value.resolvedExecutablePath
    )
    let commandLineEntities = commandGroups.compactMap {
      resolvedPath, observations
        -> Entity? in
      guard !runtimeExecutablePaths.contains(resolvedPath),
        let first = observations.sorted(by: {
          $0.value.executablePath < $1.value.executablePath
        }).first
      else { return nil }
      let names = observations.map(\.value.name).sorted()
      var details = [
        Detail("Inventory classification", "Unclassified command-line software"),
        Detail("Executable", first.value.executablePath),
        Detail("Resolved executable", resolvedPath),
        Detail("Discovered from", first.value.sourceLabel),
      ]
      if names.count > 1 {
        details.append(Detail("Command aliases", names.joined(separator: ", ")))
      }
      if let packageName = observations.compactMap(\.value.packageName).first {
        details.append(Detail("Package", packageName))
      }
      return Entity(
        id: commandLineSoftwareEntityID(resolvedPath),
        type: .package,
        name: first.value.name,
        summary:
          "An executable discovered in a configured command directory; its capability is not yet classified.",
        details: details
      )
    }.sorted { $0.name < $1.name }
    let commandLineRelationships = commandGroups.compactMap {
      resolvedPath, observations
        -> Relationship? in
      guard !runtimeExecutablePaths.contains(resolvedPath),
        let packageObservation = observations.first(where: {
          $0.value.packageManagerID == "homebrew" && $0.value.packageName != nil
        }),
        let packageName = packageObservation.value.packageName,
        let installation = homebrew?.observations.first(where: {
          $0.value.packages.contains { $0.name == packageName }
        })
      else { return nil }
      return Relationship(
        id: RelationshipID("package-command:homebrew:\(packageName):\(resolvedPath)"),
        source: homebrewPackageEntityID(prefix: installation.value.prefix, name: packageName),
        target: commandLineSoftwareEntityID(resolvedPath),
        type: .provides,
        confidence: .confirmed,
        explanation: "The executable resolves inside this observed Homebrew formula.",
        evidence: [
          Evidence(
            id: "\(packageObservation.id.rawValue):package-path",
            kind: .derived,
            summary: "The executable symlink resolves inside the formula's Cellar directory.",
            source: "Read-only command directory and Homebrew Cellar inventories",
            observationID: packageObservation.id,
            observedAt: packageObservation.observedAt,
            ruleID: "homebrew-cellar-path-ownership",
            ruleVersion: CommandLineSoftwareCollector.version
          )
        ]
      )
    }
    let shellFrameworkEntities = (shellFrameworks?.observations ?? []).compactMap {
      observation -> Entity? in
      let value = observation.value
      guard value.installationStatus != .absent else { return nil }
      var frameworkDetails = [
        Detail("Installation", value.installationStatus.rawValue.capitalized),
        Detail("Location", value.rootPath),
        Detail("Shell configuration", value.configurationStatus.rawValue.capitalized),
        Detail("Configuration path", value.configurationPath),
        Detail(
          "Installation explanation",
          value.installationStatus == .observed
            ? "Expected framework and Git metadata were observed. This is consistent with a Git/bootstrap installation; HAL did not witness the original install command."
            : "The framework location was incomplete, unreadable, or did not match all declared identity markers."
        ),
      ]
      if let repositoryHost = value.repositoryHost {
        frameworkDetails.append(Detail("Repository provider", repositoryHost))
      }
      return Entity(
        id: shellFrameworkEntityID(value.frameworkID),
        type: .shellFramework,
        name: value.label,
        summary:
          value.installationStatus == .observed
          ? "A Git-backed shell framework observed through bounded local metadata."
          : "A possible shell framework installation that HAL could not fully establish.",
        details: frameworkDetails
      )
    }
    let shellProcessMatches = (shellFrameworks?.observations ?? []).flatMap { framework in
      guard framework.value.installationStatus == .observed,
        framework.value.configurationStatus == .active
      else {
        return [(CollectedObservation<ShellFrameworkValue>, CollectedObservation<ProcessValue>)]()
      }
      let executablePaths = Set(framework.value.associatedShellExecutablePaths)
      return (processes?.observations ?? []).filter { process in
        guard let executablePath = process.value.executablePath else { return false }
        return executablePaths.contains(
          URL(filePath: executablePath).standardizedFileURL.path
        )
      }.sorted { $0.value.pid < $1.value.pid }
        .prefix(framework.value.maximumAssociatedProcesses)
        .map { (framework, $0) }
    }
    let shellProcessEntities = shellProcessMatches.map { framework, process in
      Entity(
        id: shellProcessEntityID(framework.value.frameworkID, pid: process.value.pid),
        type: .process,
        name: process.value.name,
        summary:
          "A current shell process whose exact executable matches this framework's declared shell.",
        details: [
          Detail("PID", "\(process.value.pid)"),
          Detail("Executable", process.value.executablePath ?? "Unavailable"),
          Detail("Framework configuration", "Active"),
        ]
      )
    }
    let shellProcessRelationships = shellProcessMatches.map { framework, process in
      Relationship(
        id: RelationshipID(
          "shell-framework-process:\(framework.value.frameworkID):\(process.value.pid)"
        ),
        source: shellFrameworkEntityID(framework.value.frameworkID),
        target: shellProcessEntityID(framework.value.frameworkID, pid: process.value.pid),
        type: .provides,
        confidence: .possible,
        explanation:
          "This observed shell may load the active framework reference. HAL did not inspect its environment or prove that this process sourced the configuration.",
        evidence: [
          Evidence(
            id: "\(framework.id.rawValue):configuration-reference",
            kind: .observed,
            summary: "The declared shell configuration contains the framework reference.",
            source: "Bounded shell-framework configuration check",
            observationID: framework.id,
            observedAt: framework.observedAt
          ),
          Evidence(
            id: "\(process.id.rawValue):shell-executable",
            kind: .observed,
            summary: "A process with the exact declared shell executable is currently present.",
            source: "Point-in-time process snapshot",
            observationID: process.id,
            observedAt: process.observedAt
          ),
          Evidence(
            id: "\(framework.id.rawValue):possible-process-association:\(process.value.pid)",
            kind: .inferred,
            summary: "The active configuration may apply to this shell process.",
            source: "Shell-framework manifest rule",
            ruleID: "active-config-exact-shell-executable",
            ruleVersion: ShellFrameworkCollector.version
          ),
        ]
      )
    }
    let completedAt = [
      output.run.completedAt,
      signatures?.run.completedAt,
      provenance?.run.completedAt,
      associatedLocations?.run.completedAt,
      rebuildableData?.run.completedAt,
      processes?.run.completedAt,
      processResolutions?.run.completedAt,
      persistence?.run.completedAt,
      persistenceResolutions?.run.completedAt,
      homebrew?.run.completedAt,
      runtimes?.run.completedAt,
      packageEcosystems?.run.completedAt,
      commandLineSoftware?.run.completedAt,
      shellFrameworks?.run.completedAt,
    ]
    .compactMap { $0 }
    .max()
    let startedAt =
      [
        output.run.startedAt,
        signatures?.run.startedAt,
        provenance?.run.startedAt,
        associatedLocations?.run.startedAt,
        rebuildableData?.run.startedAt,
        processes?.run.startedAt,
        processResolutions?.run.startedAt,
        persistence?.run.startedAt,
        persistenceResolutions?.run.startedAt,
        homebrew?.run.startedAt,
        runtimes?.run.startedAt,
        packageEcosystems?.run.startedAt,
        commandLineSoftware?.run.startedAt,
        shellFrameworks?.run.startedAt,
      ].compactMap { $0 }.min() ?? output.run.startedAt
    var collectorRuns = [output.run]
    if let signatures {
      collectorRuns.append(signatures.run)
    }
    if let provenance {
      collectorRuns.append(provenance.run)
    }
    if let associatedLocations {
      collectorRuns.append(associatedLocations.run)
    }
    if let rebuildableData {
      collectorRuns.append(rebuildableData.run)
    }
    if let processes {
      collectorRuns.append(processes.run)
    }
    if let processResolutions {
      collectorRuns.append(processResolutions.run)
    }
    if let persistence {
      collectorRuns.append(persistence.run)
    }
    if let persistenceResolutions {
      collectorRuns.append(persistenceResolutions.run)
    }
    if let homebrew {
      collectorRuns.append(homebrew.run)
    }
    if let runtimes {
      collectorRuns.append(runtimes.run)
    }
    if let packageEcosystems {
      collectorRuns.append(packageEcosystems.run)
    }
    if let commandLineSoftware {
      collectorRuns.append(commandLineSoftware.run)
    }
    if let shellFrameworks {
      collectorRuns.append(shellFrameworks.run)
    }
    let concreteManagerIDs = Set(
      (homebrewManagerEntities + ecosystemManagerEntities + appStoreManagerEntities).map(\.id)
    )
    let projectedEntities =
      (applicationEntities + processEntities + persistenceEntities + locationEntities
      + rebuildableDataEntities
      + rebuildableManagerEntities.values.filter {
        !concreteManagerIDs.contains($0.id)
      }
      + homebrewManagerEntities + appStoreManagerEntities + homebrewPackageEntities
      + homebrewCaskEntities + runtimeEntities
      + ecosystemManagerEntities + ecosystemPackageEntities + commandLineEntities
      + shellFrameworkEntities + shellProcessEntities)
      .sorted { $0.id.rawValue < $1.id.rawValue }
    let projectedRelationships =
      (processRelationships + persistenceRelationships + relationships
      + rebuildableManagerRelationships + homebrewPackageRelationships
      + homebrewDependencyRelationships
      + homebrewCaskRelationships + homebrewApplicationRelationships
      + appStoreRelationships
      + ecosystemRelationships + runtimeInstallationRelationships
      + commandLineRelationships + shellProcessRelationships)
      .sorted { $0.id.rawValue < $1.id.rawValue }
    let graph = SystemGraph(
      metadata: FixtureMetadata(
        id: "live-applications-\(scanID.rawValue)",
        version: ApplicationBundleCollector.version,
        name: "This Mac",
        summary: "A read-only application inventory observed on this Mac."
      ),
      entities: projectedEntities,
      relationships: projectedRelationships
    )
    return GraphSnapshot(
      graph: graph,
      scan: ScanContext(
        id: scanID,
        environment: .liveReadOnly,
        startedAt: startedAt,
        completedAt: completedAt,
        collectorRuns: collectorRuns
      )
    )
  }

  private func preferredProcessResolutions(
    _ resolutions: [CollectedObservation<ProcessApplicationResolutionValue>],
    processesByPID: [Int32: CollectedObservation<ProcessValue>],
    limit: Int
  ) -> [CollectedObservation<ProcessApplicationResolutionValue>] {
    Dictionary(
      grouping: resolutions.filter {
        $0.value.state == .matched && $0.value.applicationPaths.count == 1
      },
      by: { $0.value.applicationPaths[0] }
    )
    .values
    .flatMap { matches in
      matches.sorted {
        let left = processesByPID[$0.value.processID]?.value.residentMemoryBytes ?? 0
        let right = processesByPID[$1.value.processID]?.value.residentMemoryBytes ?? 0
        if left != right { return left > right }
        return $0.value.processID < $1.value.processID
      }.prefix(limit)
    }
    .sorted { $0.value.processID < $1.value.processID }
  }

  private func preferredUnresolvedProcessResolutions(
    _ resolutions: [CollectedObservation<ProcessApplicationResolutionValue>],
    processesByPID: [Int32: CollectedObservation<ProcessValue>],
    limit: Int
  ) -> [CollectedObservation<ProcessApplicationResolutionValue>] {
    guard limit > 0 else { return [] }
    return resolutions.filter {
      $0.value.state == .unmatched || $0.value.state == .inaccessible
    }
    .sorted {
      if $0.value.state != $1.value.state {
        return $0.value.state == .inaccessible
      }
      let left = processesByPID[$0.value.processID]?.value.residentMemoryBytes ?? 0
      let right = processesByPID[$1.value.processID]?.value.residentMemoryBytes ?? 0
      if left != right { return left > right }
      return $0.value.processID < $1.value.processID
    }
    .prefix(limit)
    .map { $0 }
  }

  private func processDetails(
    process: ProcessValue,
    resolution: ProcessApplicationResolutionValue
  ) -> [Detail] {
    var details = [
      Detail("PID", "\(process.pid)"),
      Detail("Application resolution", resolution.state.rawValue.capitalized),
    ]
    if let parentPID = process.parentPID {
      details.append(Detail("Parent PID", "\(parentPID)"))
    }
    if let bytes = process.residentMemoryBytes {
      details.append(
        Detail(
          "Memory at observation",
          ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
        )
      )
    }
    if let path = process.executablePath {
      details.append(Detail("Executable", path))
    }
    return details
  }

  private func processGroupKey(
    resolution: CollectedObservation<ProcessApplicationResolutionValue>,
    processesByPID: [Int32: CollectedObservation<ProcessValue>]
  ) -> String {
    guard let process = processesByPID[resolution.value.processID] else {
      return "missing:\(resolution.value.processID)"
    }
    let owner = resolution.value.applicationPaths.first ?? "unresolved"
    let executable = process.value.executablePath ?? "name:\(process.value.name)"
    return "\(owner)|\(executable)"
  }

  private func processEntityID(
    resolution: CollectedObservation<ProcessApplicationResolutionValue>,
    process: ProcessValue
  ) -> EntityID {
    let owner = resolution.value.applicationPaths.first ?? "unresolved"
    let identity = process.executablePath ?? process.name
    let raw =
      "\(owner)|\(identity)"
      .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "\(process.pid)"
    return EntityID("process:group:\(raw)")
  }

  private func persistenceEntityID(_ path: String) -> EntityID {
    EntityID("persistence:declaration:\(path)")
  }

  private func rebuildableDataEntityID(_ path: String) -> EntityID {
    EntityID("file:rebuildable-data:\(path)")
  }

  private func homebrewManagerEntityID(_ prefix: String) -> EntityID {
    packageManagerEntityID("homebrew")
  }

  private func packageManagerEntityID(_ id: String) -> EntityID {
    EntityID("package-manager:\(id)")
  }

  private func ecosystemPackageEntityID(
    managerID: String,
    package: ManagedPackageValue
  ) -> EntityID {
    EntityID("package:\(managerID):\(package.path)")
  }

  private func commandLineSoftwareEntityID(_ resolvedPath: String) -> EntityID {
    let encoded =
      resolvedPath.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
      ?? resolvedPath
    return EntityID("command-line-software:\(encoded)")
  }

  private func homebrewPackageEntityID(prefix: String, name: String) -> EntityID {
    EntityID("package:homebrew:\(prefix):\(name)")
  }

  private func homebrewCaskEntityID(prefix: String, token: String) -> EntityID {
    EntityID("cask:homebrew:\(prefix):\(token)")
  }

  private func shellFrameworkEntityID(_ id: String) -> EntityID {
    EntityID("shell-framework:\(id)")
  }

  private func shellProcessEntityID(_ frameworkID: String, pid: Int32) -> EntityID {
    EntityID("shell-process:\(frameworkID):\(pid)")
  }

  private func preferredPresentAssociations(
    _ observations: [CollectedObservation<ApplicationAssociatedLocationValue>]
  ) -> [CollectedObservation<ApplicationAssociatedLocationValue>] {
    let present = observations.filter {
      $0.value.status == .present
        && $0.value.applicationPath != nil
        && ($0.value.match == .bundleIdentifier || $0.value.match == .applicationName
          || $0.value.match == .applicationGroupIdentifier)
    }
    return Dictionary(
      grouping: present,
      by: { "\($0.value.applicationPath ?? "")|\($0.value.locationPath)" }
    )
    .values
    .compactMap { candidates in
      candidates.sorted {
        matchPriority($0.value.match) > matchPriority($1.value.match)
      }.first
    }
    .sorted {
      if $0.value.applicationPath != $1.value.applicationPath {
        return ($0.value.applicationPath ?? "") < ($1.value.applicationPath ?? "")
      }
      return $0.value.locationPath < $1.value.locationPath
    }
  }

  private func matchPriority(_ match: AssociatedLocationMatch) -> Int {
    switch match {
    case .bundleIdentifier: 2
    case .applicationGroupIdentifier: 2
    case .applicationName: 1
    case .unmatched, .groupIdentifierUnavailable: 0
    }
  }

  private func associationBasis(_ match: AssociatedLocationMatch) -> String {
    switch match {
    case .bundleIdentifier: "Exact bundle identifier"
    case .applicationName: "Application name convention"
    case .applicationGroupIdentifier: "Signed application-group entitlement"
    case .unmatched: "Unmatched"
    case .groupIdentifierUnavailable: "Application-group identifier unavailable"
    }
  }

  private func locationEntityID(
    for value: ApplicationAssociatedLocationValue
  ) -> EntityID {
    EntityID("file:associated-location:\(value.locationPath)")
  }

  private func entityID(
    for observation: CollectedObservation<ApplicationBundleValue>
  ) -> EntityID {
    let primary = observation.subject.primary
    return EntityID("application:\(primary.kind.rawValue):\(primary.value)")
  }

  private func details(
    for value: ApplicationBundleValue,
    signature: ApplicationSignatureValue?,
    provenance: ApplicationProvenanceValue?
  ) -> [Detail] {
    var details = [Detail("Path", value.path)]
    let evidenceFactCount = (signature == nil ? 0 : 1) + (provenance?.facts.count ?? 0)
    details.append(Detail("Evidence facts", "\(evidenceFactCount)"))
    if let bundleIdentifier = value.bundleIdentifier {
      details.append(Detail("Bundle identifier", bundleIdentifier))
    }
    if let version = value.version {
      details.append(Detail("Version", version))
    }
    if let buildVersion = value.buildVersion {
      details.append(Detail("Build", buildVersion))
    }
    if let executableName = value.executableName {
      details.append(Detail("Executable", executableName))
    }
    if let bundleCreatedAt = value.bundleCreatedAt, let setupCompletedAt = value.setupCompletedAt {
      let tolerance = TimeInterval(value.setupToleranceSeconds ?? 0)
      let timing =
        bundleCreatedAt <= setupCompletedAt.addingTimeInterval(tolerance)
        ? "Predates setup marker" : "Added after setup"
      details.append(Detail("Installation timing", timing))
      details.append(
        Detail(
          "Timing evidence",
          timing == "Predates setup marker"
            ? "Bundle creation date predates this Mac's setup marker; migration or restoration may preserve that date"
            : "Bundle was created after Mac setup completed"
        ))
    } else {
      details.append(Detail("Installation timing", "Unknown"))
    }
    if let signature {
      details.append(Detail("Signature", signature.status.rawValue.capitalized))
      if let signingIdentifier = signature.signingIdentifier {
        details.append(Detail("Signing identifier", signingIdentifier))
      }
      if let teamIdentifier = signature.teamIdentifier {
        details.append(Detail("Team identifier", teamIdentifier))
      }
      if !signature.authorities.isEmpty {
        details.append(
          Detail(
            "Signing authorities",
            signature.authorities.joined(separator: " → ")
          )
        )
      }
      if let platformBinary = signature.platformBinary {
        details.append(Detail("Platform binary", platformBinary ? "Yes" : "No"))
      }
    }
    for fact in provenance?.facts ?? [] {
      details.append(
        Detail(
          fact.displayLabel,
          provenanceDescription(for: fact)
        )
      )
    }
    return details
  }

  private func provenanceDescription(for fact: ApplicationProvenanceFact) -> String {
    switch fact.status {
    case .present:
      fact.detail ?? "Present"
    case .absent:
      "Not observed"
    case .unreadable:
      "Unavailable — metadata could not be read"
    }
  }
}
