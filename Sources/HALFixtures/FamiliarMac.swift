import HALDomain

extension FixtureCatalog {
  public static let familiarMac = SystemGraph(
    metadata: FixtureMetadata(
      id: "familiar-mac",
      name: "This Mac",
      summary: "A fictional developer Mac shaped around familiar installed software."
    ),
    entities: [
      entity(
        "app.docker", .application, "Docker Desktop",
        "Runs containers through a Linux virtual machine on this fictional Mac.",
        [
          Detail("Installed with", "Web download"),
          Detail("Synthetic footprint", "31.8 GB"),
          Detail("Current state", "Running"),
        ]),
      entity(
        "app.vscode", .application, "Visual Studio Code",
        "A code editor with extensions and language services.",
        [
          Detail("Installed with", "Homebrew Cask"),
          Detail("Synthetic footprint", "5.4 GB"),
          Detail("Current state", "Running"),
        ]),
      entity(
        "app.cmux", .application, "cmux",
        "A native terminal with workspaces, panes, and an embedded browser.",
        [
          Detail("Installed with", "Web download"),
          Detail("Synthetic footprint", "420 MB"),
          Detail("Current state", "Running"),
        ]),
      entity(
        "app.chatgpt", .application, "ChatGPT", "The ChatGPT desktop application.",
        [
          Detail("Installed with", "Web download"),
          Detail("Synthetic footprint", "1.6 GB"),
          Detail("Current state", "Running"),
        ]),
      entity(
        "app.brave", .application, "Brave Browser",
        "A web browser with separate renderer and GPU processes.",
        [
          Detail("Installed with", "Homebrew Cask"),
          Detail("Synthetic footprint", "3.2 GB"),
          Detail("Current state", "Running"),
        ]),
      entity(
        "tool.homebrew", .packageManager, "Homebrew",
        "Installs command-line formulae and macOS application casks.",
        [
          Detail("Synthetic prefix", "/opt/homebrew"),
          Detail("Synthetic Cellar", "18.6 GB"),
          Detail("Download cache", "4.1 GB"),
        ]),
      entity(
        "tool.ohmyzsh", .shellFramework, "Oh My Zsh",
        "Shell configuration, themes, and plugins loaded by zsh.",
        [
          Detail("Synthetic location", "~/.oh-my-zsh"),
          Detail("Configuration", "~/.zshrc"),
          Detail("Synthetic footprint", "280 MB"),
        ]),
      entity(
        "package.typescript", .package, "TypeScript (npm)",
        "A globally installed npm package providing the tsc command.",
        [
          Detail("Installed with", "npm"),
          Detail("Command", "tsc"),
          Detail("Synthetic footprint", "96 MB"),
        ]),
      entity(
        "process.docker", .process, "Docker backend",
        "Coordinates the Linux VM, networking, and container operations.",
        [
          Detail("Synthetic memory", "2.4 GB"),
          Detail("Synthetic CPU", "18%"),
        ]),
      entity(
        "process.vm", .process, "Docker Linux VM",
        "The virtual machine where Docker Engine and containers run.",
        [
          Detail("Synthetic memory", "5.8 GB"),
          Detail("Synthetic CPU", "24%"),
        ]),
      entity("process.vscode", .process, "VS Code window", "The main editor window."),
      entity(
        "process.extension", .process, "VS Code extension host",
        "Runs installed editor extensions separately."),
      entity(
        "process.tsserver", .process, "TypeScript language service",
        "Provides JavaScript and TypeScript code intelligence.",
        [
          Detail("Synthetic memory", "1.3 GB"),
          Detail("Synthetic CPU", "31% during incident"),
        ]),
      entity("process.cmux", .process, "cmux", "The native terminal application process."),
      entity(
        "process.zsh", .process, "zsh session", "An interactive shell running inside a cmux pane."),
      entity("process.chatgpt", .process, "ChatGPT", "The desktop application's main process."),
      entity("process.brave", .process, "Brave Browser", "The browser's main process."),
      entity(
        "process.brave-renderer", .process, "Brave tab renderer",
        "Renders one group of browser tabs."),
      entity(
        "file.docker-disk", .file, "Docker virtual disk",
        "Stores synthetic container images, containers, volumes, and build cache.",
        [
          Detail("Synthetic size", "29.4 GB"),
          Detail("Removal", "Review inside Docker"),
        ]),
      entity(
        "file.docker-build", .file, "Docker build cache",
        "Rebuildable layers from local image builds.",
        [
          Detail("Synthetic size", "11.2 GB"),
          Detail("Removal", "Rebuildable after review"),
        ]),
      entity(
        "file.vscode-extensions", .file, "VS Code extensions", "Installed editor extensions.",
        [
          Detail("Synthetic size", "2.3 GB"),
          Detail("Removal", "Remove individual extensions"),
        ]),
      entity(
        "file.vscode-cache", .file, "VS Code workspace cache",
        "Rebuildable indexes and cached workspace state.",
        [
          Detail("Synthetic size", "2.1 GB"),
          Detail("Removal", "Safe to rebuild"),
        ]),
      entity(
        "file.cmux-state", .file, "cmux workspace state",
        "Synthetic workspace, pane, and application state.",
        [
          Detail("Synthetic size", "180 MB"),
          Detail("Removal", "Keep unless resetting cmux"),
        ]),
      entity(
        "file.chatgpt-cache", .file, "ChatGPT cache and logs",
        "Synthetic rebuildable cache and diagnostic logs.",
        [
          Detail("Synthetic size", "920 MB"),
          Detail("Removal", "Usually safe after quitting"),
        ]),
      entity(
        "file.brave-profile", .file, "Brave profile",
        "Bookmarks, settings, extensions, and browsing data.",
        [
          Detail("Synthetic size", "6.8 GB"),
          Detail("Removal", "Protected user data"),
        ]),
      entity(
        "file.brave-cache", .file, "Brave browser cache", "Rebuildable web resources.",
        [
          Detail("Synthetic size", "3.4 GB"),
          Detail("Removal", "Safe to rebuild"),
        ]),
      entity(
        "file.brew-cellar", .file, "Homebrew Cellar", "Versioned formula installations.",
        [
          Detail("Synthetic size", "18.6 GB"),
          Detail("Removal", "Manage with Homebrew"),
        ]),
      entity(
        "file.brew-cache", .file, "Homebrew download cache",
        "Downloaded packages that Homebrew can fetch again.",
        [
          Detail("Synthetic size", "4.1 GB"),
          Detail("Removal", "Safe to redownload"),
        ]),
      entity(
        "file.zsh-config", .file, "Shell configuration",
        "Your .zshrc, themes, and enabled Oh My Zsh plugins.",
        [
          Detail("Removal", "Protected configuration")
        ]),
      entity(
        "file.npm-global", .file, "Global npm packages",
        "Packages installed for use from any shell.",
        [
          Detail("Synthetic size", "1.4 GB"),
          Detail("Removal", "Manage with npm"),
        ]),
      entity(
        "file.npm-cache", .file, "npm cache", "Downloaded package content npm can fetch again.",
        [
          Detail("Synthetic size", "2.7 GB"),
          Detail("Removal", "Safe to redownload"),
        ]),
      entity(
        "persistence.docker", .persistence, "Docker login item",
        "Can start Docker Desktop after sign-in."),
      entity(
        "persistence.chatgpt", .persistence, "ChatGPT login item",
        "Can start ChatGPT after sign-in."),
      entity(
        "resource.storage", .resource, "Reclaimable developer storage",
        "HAL estimates 24.4 GB is rebuildable or redownloadable.",
        [
          Detail("Likely reclaimable", "24.4 GB"),
          Detail("Requires app-specific review", "Docker build cache"),
        ]),
      entity(
        "resource.memory", .resource, "Memory pressure",
        "Memory pressure became critical during a container build.",
        [
          Detail("Current", "Normal"),
          Detail("Synthetic peak", "Critical"),
        ]),
      entity(
        "incident.build", .incident, "Container build slowdown",
        "Docker, VS Code, and Brave competed for memory during a build.",
        [
          Detail("Synthetic time", "Today at 3:42 PM"),
          Detail("Duration", "9 minutes"),
        ]),
      entity(
        "event.docker-build", .event, "Docker image build started",
        "A multi-stage container build began."),
      entity(
        "event.vscode-index", .event, "VS Code indexed the repository",
        "The TypeScript service refreshed a large workspace."),
      entity(
        "event.brave-tabs", .event, "Brave restored 24 tabs",
        "A browser window restored shortly before pressure increased."),
    ],
    relationships: [
      link(
        "docker-backend", "app.docker", "process.docker", .launches, .confirmed,
        "Docker Desktop launched its backend.",
        [
          evidence(
            "docker-backend-record", .observed, "The synthetic process belongs to Docker Desktop.",
            "Synthetic process record")
        ]),
      link(
        "docker-vm", "process.docker", "process.vm", .launches, .confirmed,
        "The Docker backend manages a Linux virtual machine.",
        [
          evidence(
            "docker-vm-record", .observed, "The synthetic backend reports a managed VM.",
            "Synthetic Docker observation")
        ]),
      link(
        "docker-disk", "process.vm", "file.docker-disk", .readsWrites, .confirmed,
        "Docker stores images, containers, volumes, and build cache inside this virtual disk.",
        [
          evidence(
            "docker-disk-observed", .observed, "The VM uses the synthetic disk image.",
            "Synthetic storage observation")
        ]),
      link(
        "docker-build-cache", "process.vm", "file.docker-build", .readsWrites, .confirmed,
        "Container builds produced this rebuildable cache.",
        [
          evidence(
            "docker-cache-observed", .observed, "Build records identify these layers.",
            "Synthetic Docker observation")
        ]),
      link(
        "docker-login", "app.docker", "persistence.docker", .persistsThrough, .confirmed,
        "Docker Desktop is configured to start after sign-in.",
        [
          evidence(
            "docker-login-observed", .observed, "A synthetic login item names Docker.",
            "Synthetic persistence record")
        ]),
      link(
        "vscode-main", "app.vscode", "process.vscode", .launches, .confirmed,
        "Visual Studio Code launched its editor window.",
        [
          evidence(
            "vscode-process", .observed, "The synthetic process belongs to VS Code.",
            "Synthetic process record")
        ]),
      link(
        "vscode-extensions", "process.vscode", "process.extension", .launches, .confirmed,
        "VS Code launched a separate extension host.",
        [
          evidence(
            "extension-host-record", .observed, "The editor reports an extension host.",
            "Synthetic process tree")
        ]),
      link(
        "vscode-tsserver", "process.extension", "process.tsserver", .launches, .confirmed,
        "The extension host launched the TypeScript language service.",
        [
          evidence(
            "tsserver-parent", .observed, "The extension host is the synthetic parent.",
            "Synthetic process tree")
        ]),
      link(
        "vscode-extension-files", "app.vscode", "file.vscode-extensions", .owns, .confirmed,
        "These installed extensions add capabilities to VS Code.",
        [
          evidence(
            "vscode-extension-path", .observed,
            "The synthetic inventory identifies VS Code extensions.",
            "Synthetic filesystem observation")
        ]),
      link(
        "vscode-cache", "process.tsserver", "file.vscode-cache", .readsWrites, .high,
        "The language service is the likely producer of this rebuildable workspace cache.",
        [
          evidence(
            "vscode-cache-write", .observed, "Cache writes overlap language-service activity.",
            "Synthetic file activity")
        ]),
      link(
        "cmux-main", "app.cmux", "process.cmux", .launches, .confirmed,
        "cmux launched its native application process.",
        [
          evidence(
            "cmux-process-record", .observed, "The synthetic process belongs to cmux.",
            "Synthetic process record")
        ]),
      link(
        "cmux-shell", "process.cmux", "process.zsh", .launches, .confirmed,
        "A cmux pane launched this interactive zsh session.",
        [
          evidence(
            "cmux-shell-tree", .observed, "The shell records cmux as its synthetic parent.",
            "Synthetic process tree")
        ]),
      link(
        "cmux-state", "app.cmux", "file.cmux-state", .owns, .high,
        "cmux uses this state to restore its workspace context.",
        [
          evidence(
            "cmux-state-observed", .observed, "The synthetic state belongs to cmux.",
            "Synthetic filesystem observation")
        ]),
      link(
        "zsh-framework", "process.zsh", "tool.ohmyzsh", .owns, .high,
        "This zsh session loaded the Oh My Zsh framework.",
        [
          evidence(
            "zsh-framework-config", .observed, "The synthetic shell configuration loads Oh My Zsh.",
            "Synthetic shell observation")
        ]),
      link(
        "zsh-config", "tool.ohmyzsh", "file.zsh-config", .readsWrites, .confirmed,
        "Oh My Zsh reads your protected shell configuration.",
        [
          evidence(
            "zsh-config-read", .observed, "The framework loaded the synthetic configuration.",
            "Synthetic shell observation")
        ]),
      link(
        "homebrew-vscode", "tool.homebrew", "app.vscode", .owns, .confirmed,
        "Homebrew installed Visual Studio Code as a cask.",
        [
          evidence(
            "brew-cask-vscode", .observed,
            "The synthetic Homebrew inventory contains the VS Code cask.",
            "Synthetic package inventory")
        ]),
      link(
        "homebrew-brave", "tool.homebrew", "app.brave", .owns, .confirmed,
        "Homebrew installed Brave Browser as a cask.",
        [
          evidence(
            "brew-cask-brave", .observed,
            "The synthetic Homebrew inventory contains the Brave cask.",
            "Synthetic package inventory")
        ]),
      link(
        "homebrew-cellar", "tool.homebrew", "file.brew-cellar", .owns, .confirmed,
        "Homebrew stores versioned formula installations in its Cellar.",
        [
          evidence(
            "brew-cellar-path", .observed, "The synthetic prefix identifies the Cellar.",
            "Synthetic package inventory")
        ]),
      link(
        "homebrew-cache", "tool.homebrew", "file.brew-cache", .owns, .confirmed,
        "Homebrew can redownload the contents of this cache.",
        [
          evidence(
            "brew-cache-path", .observed, "The synthetic cache is managed by Homebrew.",
            "Synthetic package inventory")
        ]),
      link(
        "npm-typescript", "file.npm-global", "package.typescript", .owns, .confirmed,
        "The global npm installation contains TypeScript and its tsc command.",
        [
          evidence(
            "npm-global-record", .observed, "The synthetic npm inventory lists TypeScript.",
            "Synthetic package inventory")
        ]),
      link(
        "typescript-service", "package.typescript", "process.tsserver", .launches, .high,
        "VS Code uses TypeScript tooling to provide language intelligence.",
        [
          evidence(
            "typescript-service-record", .observed,
            "The synthetic service loads TypeScript libraries.", "Synthetic process observation")
        ]),
      link(
        "npm-cache", "package.typescript", "file.npm-cache", .shares, .probable,
        "npm used its shared cache while installing this package.",
        [
          evidence(
            "npm-cache-record", .observed, "The synthetic installation accessed npm's cache.",
            "Synthetic package event")
        ]),
      link(
        "chatgpt-main", "app.chatgpt", "process.chatgpt", .launches, .confirmed,
        "ChatGPT launched its desktop process.",
        [
          evidence(
            "chatgpt-process", .observed, "The synthetic process belongs to ChatGPT.",
            "Synthetic process record")
        ]),
      link(
        "chatgpt-cache", "app.chatgpt", "file.chatgpt-cache", .owns, .high,
        "ChatGPT produced this synthetic cache and diagnostic data.",
        [
          evidence(
            "chatgpt-cache-path", .observed, "The synthetic files identify ChatGPT.",
            "Synthetic filesystem observation")
        ]),
      link(
        "chatgpt-login", "app.chatgpt", "persistence.chatgpt", .persistsThrough, .confirmed,
        "ChatGPT is configured to start after sign-in.",
        [
          evidence(
            "chatgpt-login-record", .observed, "A synthetic login item names ChatGPT.",
            "Synthetic persistence record")
        ]),
      link(
        "brave-main", "app.brave", "process.brave", .launches, .confirmed,
        "Brave launched its main browser process.",
        [
          evidence(
            "brave-process", .observed, "The synthetic process belongs to Brave.",
            "Synthetic process record")
        ]),
      link(
        "brave-renderer", "process.brave", "process.brave-renderer", .launches, .confirmed,
        "Brave launched a separate renderer for web content.",
        [
          evidence(
            "brave-renderer-tree", .observed, "The browser is the renderer's synthetic parent.",
            "Synthetic process tree")
        ]),
      link(
        "brave-profile", "app.brave", "file.brave-profile", .owns, .confirmed,
        "This protected profile contains your browser settings and data.",
        [
          evidence(
            "brave-profile-path", .observed, "The synthetic profile belongs to Brave.",
            "Synthetic filesystem observation")
        ]),
      link(
        "brave-cache", "process.brave-renderer", "file.brave-cache", .readsWrites, .confirmed,
        "Brave's renderer produced this rebuildable web cache.",
        [
          evidence(
            "brave-cache-write", .observed, "The synthetic renderer wrote the cache.",
            "Synthetic file activity")
        ]),
      link(
        "docker-memory", "process.vm", "resource.memory", .contributesTo, .confirmed,
        "The Docker VM was the largest memory contributor during the incident.",
        [
          evidence(
            "docker-memory-samples", .observed, "Synthetic samples show a 5.8 GB contribution.",
            "Synthetic resource samples")
        ]),
      link(
        "vscode-memory", "process.tsserver", "resource.memory", .contributesTo, .confirmed,
        "The TypeScript service contributed 1.3 GB while indexing.",
        [
          evidence(
            "vscode-memory-samples", .observed, "Synthetic samples identify the language service.",
            "Synthetic resource samples")
        ]),
      link(
        "brave-memory", "process.brave-renderer", "resource.memory", .contributesTo, .confirmed,
        "Restored Brave tabs contributed 2.1 GB.",
        [
          evidence(
            "brave-memory-samples", .observed, "Synthetic samples identify the renderer.",
            "Synthetic resource samples")
        ]),
      link(
        "memory-incident", "resource.memory", "incident.build", .contributesTo, .confirmed,
        "Critical memory pressure defines this preserved slowdown.",
        [
          evidence(
            "incident-pressure", .observed,
            "Synthetic pressure remained critical for nine minutes.", "Synthetic incident record")
        ]),
      link(
        "build-event", "event.docker-build", "incident.build", .occurredNear, .high,
        "The container build began shortly before memory pressure rose.",
        [
          evidence(
            "build-timeline", .observed, "The synthetic build preceded the spike by 22 seconds.",
            "Synthetic event timeline")
        ]),
      link(
        "index-event", "event.vscode-index", "incident.build", .occurredNear, .probable,
        "VS Code indexing overlapped the slowdown; HAL does not claim it caused the incident.",
        [
          evidence(
            "index-timeline", .observed, "Synthetic indexing overlapped the incident.",
            "Synthetic event timeline")
        ]),
      link(
        "tabs-event", "event.brave-tabs", "incident.build", .occurredNear, .possible,
        "Brave restored 24 tabs nearby in time, but evidence is insufficient to call it a trigger.",
        [
          evidence(
            "tabs-timeline", .observed, "The synthetic restore occurred two minutes earlier.",
            "Synthetic event timeline")
        ]),
      link(
        "docker-reclaim", "file.docker-build", "resource.storage", .contributesTo, .probable,
        "Docker can rebuild these layers after app-specific review.",
        [
          evidence(
            "docker-cache-size", .observed, "The synthetic cache measures 11.2 GB.",
            "Synthetic storage snapshot")
        ]),
      link(
        "vscode-reclaim", "file.vscode-cache", "resource.storage", .contributesTo, .confirmed,
        "VS Code can rebuild this 2.1 GB workspace cache.",
        [
          evidence(
            "vscode-cache-size", .observed, "The synthetic cache measures 2.1 GB.",
            "Synthetic storage snapshot")
        ]),
      link(
        "brave-reclaim", "file.brave-cache", "resource.storage", .contributesTo, .confirmed,
        "Brave can rebuild this 3.4 GB web cache.",
        [
          evidence(
            "brave-cache-size", .observed, "The synthetic cache measures 3.4 GB.",
            "Synthetic storage snapshot")
        ]),
      link(
        "brew-reclaim", "file.brew-cache", "resource.storage", .contributesTo, .confirmed,
        "Homebrew can redownload this 4.1 GB cache.",
        [
          evidence(
            "brew-cache-size", .observed, "The synthetic cache measures 4.1 GB.",
            "Synthetic storage snapshot")
        ]),
      link(
        "npm-reclaim", "file.npm-cache", "resource.storage", .contributesTo, .confirmed,
        "npm can redownload this 2.7 GB cache.",
        [
          evidence(
            "npm-cache-size", .observed, "The synthetic cache measures 2.7 GB.",
            "Synthetic storage snapshot")
        ]),
    ]
  )
}
