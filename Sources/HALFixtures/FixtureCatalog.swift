import HALDomain

public enum FixtureCatalog {
  public static let all: [SystemGraph] = [
    familiarMac,
    atlasMac,
    simpleApplication,
    helperRichApplication,
    resourceIncident,
    ambiguousOwnership,
  ]

  public static let atlasMac = SystemGraph(
    metadata: FixtureMetadata(
      id: "atlas-mac",
      name: "This Mac",
      summary: "A coherent fictional Mac for exploring applications, storage, and performance."
    ),
    entities: [
      entity(
        "app.cutline", .application, "Cutline Video", "A web-downloaded video editor.",
        [
          Detail("Installed from", "Developer website"),
          Detail("Publisher", "North Coast Software"),
          Detail("Total footprint", "12.8 GB"),
          Detail("Current state", "Running"),
        ]),
      entity(
        "app.helix", .application, "Helix Code", "A code editor installed with Homebrew.",
        [
          Detail("Installed from", "Homebrew"),
          Detail("Publisher", "Helix Tools"),
          Detail("Total footprint", "4.6 GB"),
          Detail("Current state", "Running"),
        ]),
      entity(
        "app.cloudline", .application, "Cloudline Drive", "A file-sync application.",
        [
          Detail("Installed from", "App Store"),
          Detail("Total footprint", "2.1 GB"),
          Detail("Starts automatically", "Yes"),
        ]),
      entity(
        "app.photos", .application, "Photos", "A macOS system application.",
        [
          Detail("Installed from", "macOS"),
          Detail("Current state", "Not running"),
        ]),
      entity(
        "process.cutline", .process, "Cutline Video", "The editor's main running process.",
        [
          Detail("Memory now", "1.4 GB"),
          Detail("CPU now", "8%"),
        ]),
      entity(
        "process.render", .process, "Cutline render worker", "Renders previews and exports.",
        [
          Detail("Memory now", "3.8 GB"),
          Detail("CPU now", "42%"),
        ]),
      entity(
        "process.helix", .process, "Helix Code", "The editor's main process.",
        [
          Detail("Memory now", "620 MB"),
          Detail("CPU now", "3%"),
        ]),
      entity(
        "process.language", .process, "Swift language service",
        "Provides code completion and diagnostics.",
        [
          Detail("Memory now", "1.2 GB"),
          Detail("CPU now", "12%"),
        ]),
      entity(
        "process.cloudline", .process, "Cloudline sync service",
        "Keeps selected folders synchronized.",
        [
          Detail("Memory now", "310 MB"),
          Detail("CPU now", "1%"),
        ]),
      entity(
        "file.cutline-projects", .file, "Video projects", "Your original projects and media.",
        [
          Detail("Size", "84.2 GB"),
          Detail("Category", "User-created work"),
          Detail("Removal", "Protected"),
        ]),
      entity(
        "file.cutline-cache", .file, "Cutline render cache",
        "Temporary previews that Cutline can rebuild.",
        [
          Detail("Size", "9.6 GB"),
          Detail("Last used", "Today"),
          Detail("Removal", "Safe to rebuild"),
        ]),
      entity(
        "file.cutline-logs", .file, "Cutline diagnostic logs",
        "Diagnostic history produced by Cutline.",
        [
          Detail("Size", "640 MB"),
          Detail("Last used", "Yesterday"),
          Detail("Removal", "Usually safe"),
        ]),
      entity(
        "file.helix-build", .file, "Helix build cache",
        "Compiled intermediates for recent projects.",
        [
          Detail("Size", "3.7 GB"),
          Detail("Last used", "6 days ago"),
          Detail("Removal", "Safe to rebuild"),
        ]),
      entity(
        "file.cloudline-copy", .file, "Cloudline local files",
        "Local copies of synchronized documents.",
        [
          Detail("Size", "38.4 GB"),
          Detail("Removal", "Not a cleanup candidate"),
        ]),
      entity(
        "file.shared-media", .file, "Shared media support",
        "Media components used by more than one application.",
        [
          Detail("Size", "1.1 GB"),
          Detail("Ownership", "Shared"),
          Detail("Removal", "Protected"),
        ]),
      entity(
        "persistence.cloudline", .persistence, "Cloudline login item",
        "Starts Cloudline after you sign in."),
      entity(
        "persistence.cutline", .persistence, "Cutline update helper",
        "Checks for Cutline updates after sign-in."),
      entity(
        "resource.memory", .resource, "Memory pressure", "Memory pressure is currently normal.",
        [
          Detail("Current", "Normal"),
          Detail("Peak today", "Critical"),
        ]),
      entity(
        "resource.storage", .resource, "Reclaimable storage",
        "HAL estimates 13.9 GB can be safely rebuilt.",
        [
          Detail("Likely reclaimable", "13.9 GB"),
          Detail("Protected user files", "122.6 GB"),
        ]),
      entity(
        "incident.render", .incident, "Memory spike during video export",
        "Memory pressure became critical for seven minutes.",
        [
          Detail("Occurred", "Today at 2:14 PM"),
          Detail("Duration", "7 minutes"),
          Detail("Largest contributor", "Cutline render worker"),
        ]),
      entity(
        "event.export", .event, "4K export started",
        "A 4K video export began shortly before memory pressure rose."),
      entity(
        "event.project", .event, "Archive project opened",
        "A large Helix workspace was opened nearby in time."),
    ],
    relationships: [
      link(
        "cutline-main", "app.cutline", "process.cutline", .launches, .confirmed,
        "Cutline Video launched its main process.",
        [
          evidence(
            "cutline-main-observed", .observed, "The process belongs to the Cutline application.",
            "Synthetic process record")
        ]),
      link(
        "cutline-render", "process.cutline", "process.render", .launches, .confirmed,
        "Cutline launched a render worker for preview and export work.",
        [
          evidence(
            "render-parent", .observed, "Cutline is the render worker's parent process.",
            "Synthetic process tree")
        ]),
      link(
        "cutline-projects", "app.cutline", "file.cutline-projects", .readsWrites, .confirmed,
        "Cutline opens these projects, but they are your work and are protected.",
        [
          evidence(
            "project-access", .observed, "Cutline opened project files in this location.",
            "Synthetic file activity")
        ]),
      link(
        "cutline-cache", "process.render", "file.cutline-cache", .readsWrites, .confirmed,
        "The render worker produces this rebuildable preview cache.",
        [
          evidence(
            "cache-writes", .observed, "The render worker wrote the cache files.",
            "Synthetic file activity")
        ]),
      link(
        "cutline-logs", "app.cutline", "file.cutline-logs", .owns, .high,
        "These diagnostic logs belong to Cutline and are usually removable.",
        [
          evidence(
            "log-identity", .observed, "The path and file metadata identify Cutline.",
            "Synthetic filesystem observation")
        ]),
      link(
        "cutline-update", "app.cutline", "persistence.cutline", .persistsThrough, .high,
        "Cutline installed an update helper that starts after sign-in.",
        [
          evidence(
            "update-team", .observed, "The helper has Cutline's signing identity.",
            "Synthetic signing observation")
        ]),
      link(
        "cutline-shared", "app.cutline", "file.shared-media", .shares, .ambiguous,
        "Cutline uses this shared media folder, but HAL cannot assign exclusive ownership.",
        [
          evidence(
            "cutline-shared-access", .observed, "Cutline accessed this shared location.",
            "Synthetic file activity")
        ]),
      link(
        "helix-main", "app.helix", "process.helix", .launches, .confirmed,
        "Helix Code launched its main process.",
        [
          evidence(
            "helix-main-observed", .observed, "The process belongs to Helix Code.",
            "Synthetic process record")
        ]),
      link(
        "helix-language", "process.helix", "process.language", .launches, .confirmed,
        "Helix launched the Swift language service for the open workspace.",
        [
          evidence(
            "language-parent", .observed, "Helix is the service's parent process.",
            "Synthetic process tree")
        ]),
      link(
        "helix-cache", "process.language", "file.helix-build", .readsWrites, .high,
        "The language service is the likely producer of this rebuildable cache.",
        [
          evidence(
            "build-activity", .observed, "Cache writes occurred while the service was active.",
            "Synthetic file activity")
        ]),
      link(
        "cloudline-main", "app.cloudline", "process.cloudline", .launches, .confirmed,
        "Cloudline launched its sync service.",
        [
          evidence(
            "cloudline-process", .observed, "The service belongs to Cloudline.",
            "Synthetic process record")
        ]),
      link(
        "cloudline-login", "app.cloudline", "persistence.cloudline", .persistsThrough, .confirmed,
        "Cloudline is configured to start after sign-in.",
        [
          evidence(
            "cloudline-login-observed", .observed, "A login item names Cloudline.",
            "Synthetic persistence record")
        ]),
      link(
        "cloudline-files", "process.cloudline", "file.cloudline-copy", .readsWrites, .confirmed,
        "Cloudline synchronizes these files; they are not ordinary disposable cache data.",
        [
          evidence(
            "cloudline-sync", .observed, "The sync service accesses this location.",
            "Synthetic file activity")
        ]),
      link(
        "render-memory", "process.render", "resource.memory", .contributesTo, .confirmed,
        "The Cutline render worker was the largest memory contributor.",
        [
          evidence(
            "render-samples", .observed, "Memory samples show a 4.7 GB increase.",
            "Synthetic resource samples")
        ]),
      link(
        "language-memory", "process.language", "resource.memory", .contributesTo, .confirmed,
        "The Swift language service contributed 1.2 GB during the same period.",
        [
          evidence(
            "language-samples", .observed, "Memory samples identify the language service.",
            "Synthetic resource samples")
        ]),
      link(
        "memory-incident", "resource.memory", "incident.render", .contributesTo, .confirmed,
        "Critical memory pressure defines this preserved incident.",
        [
          evidence(
            "pressure-window", .observed, "Pressure remained critical for seven minutes.",
            "Synthetic incident record")
        ]),
      link(
        "export-near", "event.export", "incident.render", .occurredNear, .high,
        "The export began 18 seconds before pressure rose and is strongly correlated with the spike.",
        [
          evidence(
            "export-timeline", .observed, "The export preceded the spike by 18 seconds.",
            "Synthetic event timeline")
        ]),
      link(
        "project-near", "event.project", "incident.render", .occurredNear, .possible,
        "The workspace opened four minutes earlier; HAL has not established that it caused the spike.",
        [
          evidence(
            "project-timeline", .observed, "The project event occurred four minutes earlier.",
            "Synthetic event timeline")
        ]),
      link(
        "cache-reclaim", "file.cutline-cache", "resource.storage", .contributesTo, .confirmed,
        "Removing this rebuildable cache would reclaim 9.6 GB.",
        [
          evidence(
            "cache-size", .observed, "The synthetic inventory measures 9.6 GB.",
            "Synthetic storage snapshot")
        ]),
      link(
        "build-reclaim", "file.helix-build", "resource.storage", .contributesTo, .probable,
        "Removing this stale build cache would reclaim 3.7 GB and require rebuilding it later.",
        [
          evidence(
            "build-size", .observed, "The synthetic inventory measures 3.7 GB.",
            "Synthetic storage snapshot")
        ]),
    ]
  )

  public static func fixture(id: String) -> SystemGraph? {
    all.first { $0.metadata.id == id }
  }

  public static func validateManifestProfiles() throws -> Int {
    try ManifestProfileCatalog.validateAll().count
  }

  static func entity(
    _ id: String,
    _ type: EntityType,
    _ name: String,
    _ summary: String,
    _ details: [Detail] = []
  ) -> Entity {
    Entity(id: EntityID(id), type: type, name: name, summary: summary, details: details)
  }

  static func evidence(
    _ id: String,
    _ kind: EvidenceKind,
    _ summary: String,
    _ source: String
  ) -> Evidence {
    Evidence(id: id, kind: kind, summary: summary, source: source)
  }

  static func link(
    _ id: String,
    _ source: String,
    _ target: String,
    _ type: RelationshipType,
    _ confidence: Confidence,
    _ explanation: String,
    _ evidence: [Evidence]
  ) -> Relationship {
    Relationship(
      id: RelationshipID(id),
      source: EntityID(source),
      target: EntityID(target),
      type: type,
      confidence: confidence,
      explanation: explanation,
      evidence: evidence
    )
  }

  public static let simpleApplication = ManifestProfileCatalog.loadRequired(
    "simple-application"
  )

  public static let helperRichApplication = ManifestProfileCatalog.loadRequired(
    "helper-rich-application"
  )

  public static let resourceIncident = SystemGraph(
    metadata: FixtureMetadata(
      id: "resource-incident",
      name: "Resource incident",
      summary: "A memory-pressure event with multiple contributors and nearby context."
    ),
    entities: [
      entity("app.canvas", .application, "Canvas Pro", "A synthetic design application."),
      entity("process.canvas", .process, "Canvas Pro process", "The main design process."),
      entity(
        "process.render", .process, "Canvas render worker",
        "A child process rendering a large document."),
      entity(
        "process.sync", .process, "Cloud sync helper",
        "A separate helper active during the incident."),
      entity(
        "resource.memory", .resource, "Memory pressure",
        "Memory pressure rose from normal to critical.",
        [
          Detail("Peak", "Critical"),
          Detail("Duration", "8 minutes"),
        ]),
      entity(
        "incident.memory", .incident, "July design-session incident",
        "A preserved synthetic memory-pressure event."),
      entity(
        "event.document", .event, "Large document opened",
        "A 4.2 GB design document was opened nearby in time."),
      entity("event.wake", .event, "Mac woke", "The computer woke shortly before the incident."),
    ],
    relationships: [
      link(
        "canvas-main", "app.canvas", "process.canvas", .launches, .confirmed,
        "Canvas Pro launched its main process.",
        [
          evidence(
            "canvas-main-process", .observed, "The process belongs to Canvas Pro.",
            "Synthetic process observation")
        ]),
      link(
        "canvas-render", "process.canvas", "process.render", .launches, .confirmed,
        "Canvas Pro launched a render worker.",
        [
          evidence(
            "canvas-render-parent", .observed, "The render worker records Canvas Pro as parent.",
            "Synthetic process tree")
        ]),
      link(
        "render-memory", "process.render", "resource.memory", .contributesTo, .confirmed,
        "The render worker added 4.8 GB during the pressure event.",
        [
          evidence(
            "render-memory-sample", .observed,
            "Memory samples attribute a 4.8 GB increase to this process.",
            "Synthetic resource samples")
        ]),
      link(
        "sync-memory", "process.sync", "resource.memory", .contributesTo, .confirmed,
        "Cloud sync added 1.1 GB during the same event.",
        [
          evidence(
            "sync-memory-sample", .observed,
            "Memory samples attribute a 1.1 GB increase to this helper.",
            "Synthetic resource samples")
        ]),
      link(
        "memory-incident", "resource.memory", "incident.memory", .contributesTo, .confirmed,
        "Critical memory pressure defines this recorded incident.",
        [
          evidence(
            "incident-threshold", .observed, "Pressure remained critical for the incident window.",
            "Synthetic incident record")
        ]),
      link(
        "document-near", "event.document", "incident.memory", .occurredNear, .probable,
        "Opening the large document happened shortly before pressure rose; HAL has not established causation.",
        [
          evidence(
            "document-time", .observed, "The document event preceded the incident by 42 seconds.",
            "Synthetic event timeline"),
          evidence(
            "document-correlation", .inferred,
            "Temporal proximity supports correlation, not causation.",
            "Incident explanation rule v1"),
        ]),
      link(
        "wake-near", "event.wake", "incident.memory", .occurredNear, .possible,
        "The Mac woke three minutes earlier, but evidence is too weak to call it a trigger.",
        [
          evidence(
            "wake-time", .observed, "Wake occurred three minutes before pressure rose.",
            "Synthetic event timeline")
        ]),
    ]
  )

  public static let ambiguousOwnership = SystemGraph(
    metadata: FixtureMetadata(
      id: "ambiguous-ownership",
      name: "Ambiguous ownership",
      summary:
        "Two applications plausibly own a shared helper and folder; evidence is inconclusive."
    ),
    entities: [
      entity(
        "app.orbit", .application, "Orbit Writer", "A writing application from Example Cooperative."
      ),
      entity(
        "app.quill", .application, "Quill Review", "A review application from Example Cooperative."),
      entity(
        "persistence.shared", .persistence, "Document update helper",
        "A login helper shared or left behind by one of two applications.",
        [
          Detail("State", "Unresolved"),
          Detail("Why unresolved", "Two durable identities agree equally"),
        ]),
      entity(
        "file.shared", .file, "Shared document services", "Support data used by both applications.",
        [
          Detail("Ownership", "Shared or ambiguous"),
          Detail("Action", "Protected from automatic removal"),
        ]),
      entity(
        "process.shared", .process, "Document service process",
        "A running process started by the helper."),
    ],
    relationships: [
      link(
        "orbit-helper", "persistence.shared", "app.orbit", .mayBelongTo, .ambiguous,
        "Orbit Writer is one plausible owner, but the evidence does not distinguish it from Quill Review.",
        [
          evidence(
            "orbit-team", .observed, "Orbit and the helper share a signing Team ID.",
            "Synthetic signing observation"),
          evidence(
            "orbit-name", .inferred, "The helper serves document features used by Orbit.",
            "Ownership resolver v1"),
        ]),
      link(
        "quill-helper", "persistence.shared", "app.quill", .mayBelongTo, .ambiguous,
        "Quill Review is equally plausible; HAL cannot select a confident owner.",
        [
          evidence(
            "quill-team", .observed, "Quill and the helper share a signing Team ID.",
            "Synthetic signing observation"),
          evidence(
            "quill-name", .inferred, "The helper serves document features used by Quill.",
            "Ownership resolver v1"),
        ]),
      link(
        "helper-process", "persistence.shared", "process.shared", .launches, .confirmed,
        "The login helper launched the document service process.",
        [
          evidence(
            "helper-process-tree", .observed, "The process record identifies the helper as parent.",
            "Synthetic process tree")
        ]),
      link(
        "orbit-folder", "app.orbit", "file.shared", .shares, .ambiguous,
        "Orbit accesses this folder, but the folder is not exclusively its data.",
        [
          evidence(
            "orbit-folder-use", .observed, "Orbit accessed files in the shared folder.",
            "Synthetic file event")
        ]),
      link(
        "quill-folder", "app.quill", "file.shared", .shares, .ambiguous,
        "Quill also accesses this folder, so HAL cannot assign exclusive ownership.",
        [
          evidence(
            "quill-folder-use", .observed, "Quill accessed files in the shared folder.",
            "Synthetic file event")
        ]),
      link(
        "process-folder", "process.shared", "file.shared", .readsWrites, .confirmed,
        "The shared service process reads and writes this support folder.",
        [
          evidence(
            "shared-folder-event", .observed, "File events identify the document service process.",
            "Synthetic file event")
        ]),
    ]
  )
}
