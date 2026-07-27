# HAL Feature Catalog

This catalog records every feature discussed so far. Inclusion here does not
mean every feature belongs in the first release.

## Foundation

### System relationship model

- Model applications, packages, processes, files, persistence, identities,
  resources, events, incidents, findings, and user decisions.
- Preserve many-to-many and confidence-scored relationships.
- Retain historical state and changes.
- Separate collected facts from inferred relationships and recommendations.
- Make every inference explainable from stored evidence.

### Local history

- Store normalized inventory and time-series summaries locally.
- Record first seen, last seen, and changed timestamps.
- Compare scans.
- Provide retention controls.
- Support export for debugging and user ownership.

### Search and navigation

- Search applications, processes, paths, bundle identifiers, Team IDs, package
  receipts, and findings.
- Navigate bidirectionally across relationships.
- Filter by trust, activity, ownership, origin, change, persistence, and risk.
- Preserve a navigation history.

### Findings inbox

- Present new, changed, unrecognized, risky, and reclaimable findings.
- Include evidence, confidence, severity, and recommended review action.
- Allow approve, dismiss, defer, deny, and resolve dispositions.
- Preserve the decision history.

## Visual system atlas

- Zoomable and pannable 2D/2.5D relationship map.
- Stable semantic grouping rather than a constantly moving force graph.
- Expand and collapse entities.
- Highlight paths between selected entities.
- Switch lenses without losing selection.
- Display directional and confidence-graded edges.
- Show a time scrubber or historical comparison.
- Pair the map with a textual explanation and evidence inspector.
- Support keyboard navigation and accessibility.
- Use synthetic fixtures so the visualization can be developed independently
  from privileged or expensive collectors.

## Applications

- Inventory system, shared, and user applications.
- Read application name, icon, bundle identifier, version, path, and metadata.
- Record App Store, Homebrew, package, disk-image, or unknown provenance.
- Inspect signing authority and Team ID.
- Record Gatekeeper/notarization state where accessible.
- Track installations, removals, updates, and identity changes.
- Associate helpers and embedded executables.
- Correlate running processes.
- Correlate support files and containers.
- Show an application relationship detail page.

### Classification

Keep independent dimensions:

- Presence: installed or removed
- Trust: system, approved, unrecognized, or denied
- Origin: App Store, Homebrew, package installer, disk image, or unknown
- Runtime: running or stopped
- Change: new, updated, unchanged, or removed
- Signature: Apple, identified developer, unsigned, or invalid
- Persistence: none, login item, agent, daemon, helper, or extension

### Approvals

- Approve an exact binary.
- Approve an application bundle.
- Approve a bundle identity from a Team ID.
- Optionally approve a publisher with an explicit warning.
- Preserve approval across normal updates while still reporting the update.
- Detect unexpected signature or identity changes.

## Processes and activity

- Capture periodic process snapshots.
- Record PID, parent PID, executable, owning bundle, start time, and resource
  contribution.
- Correlate helpers and child processes with their owning applications.
- Identify processes executing from unusual locations.
- Mark unmatched processes as unresolved or unrecognized.
- Redact sensitive process arguments by default.
- Provide process inspection and relationship navigation.
- Defer continuous process-event monitoring until snapshots demonstrate a need.

## Persistence

- Inventory login items.
- Inventory user and system LaunchAgents.
- Inventory LaunchDaemons.
- Inventory privileged helpers.
- Inventory system extensions.
- Consider browser extensions and scheduled jobs where reliable.
- Trace a persistent item to its signing identity, application, package, and
  running process.
- Report orphaned persistence after application removal.
- Detect additions and changes.

## Reclaim

`reclaim` is the product-facing cleanup domain. General storage statistics
remain available as context and as a lens.

- Measure important paths and categories.
- Preserve size and growth history.
- Identify large files and directories.
- Identify old downloads.
- Recognize conventional caches, logs, build outputs, SDKs, virtual
  environments, package caches, Docker data, and temporary files.
- Associate candidate data with applications, projects, or package managers.
- Distinguish user data, shared data, rebuildable data, redownloadable data,
  and unknown data.
- Explain why an item may be removable.
- Show current use and recent activity where evidence exists.
- Support configurable thresholds and growth alerts.
- Provide dry-run cleanup plans.
- Confirm each destructive action.
- Prefer Trash and application-native uninstallers.
- Record actions and recovery information.
- Protect system paths, unresolved symlinks, shared data, and user documents.

Proposed commands:

```text
hal reclaim scan
hal reclaim candidates
hal reclaim explain <path>
hal reclaim clean --dry-run
hal reclaim clean
```

## Overall storage lens

- Show filesystem capacity and available space.
- Explain major categories.
- Visualize historical growth.
- Distinguish reclaimability from mere size.
- Link every category to owning applications and files where possible.
- Avoid copying the opaque "System Data" classification without explanation.

## Installation footprints

This is a V2 feature.

- Import package receipts.
- Correlate conventional support paths with bundle IDs and Team IDs.
- Run an observed installation session with before/after snapshots.
- Observe filesystem changes during installation and first launch.
- Associate changes with installer and application process trees when possible.
- Assign confidence and evidence to file ownership.
- Track later files created by updates and runtime use.
- Show an application footprint.
- Generate an uninstall plan.
- Separate private, shared, ambiguous, rebuildable, persistent, privileged, and
  user-created data.
- Never automatically remove shared or ambiguous files.

## Resource telemetry

This is a V2 feature.

- Sample CPU, memory, memory pressure, swap, disk I/O, network throughput, and
  relevant thermal/power state where accessible.
- Sample per-process CPU, memory, thread, and I/O contribution.
- Use low-rate baseline sampling.
- Increase resolution around a detected incident.
- Downsample historical normal periods.
- Bound database size with retention policies.
- Measure and report HAL's own overhead.

## Incidents and behavioral correlation

This is a V2 feature.

- Detect sustained resource pressure and meaningful changes.
- Capture an event window around a spike.
- Rank contributing processes and applications.
- Record nearby launches, exits, wake events, installations, updates, and
  explicitly enabled user-context events.
- Allow manual markers such as `hal mark "started export"`.
- Compare incidents for repeated sequences.
- Report correlations and possible triggers without claiming unsupported
  causation.
- Start with explainable thresholds, rolling baselines, median deviations, and
  change-point detection.
- Add statistical pattern discovery only after sufficient history exists.
- Notify only for severe, sustained, or meaningfully recurrent behavior.

## Notifications and scheduling

- Lightweight periodic checks.
- Notification Center alerts.
- Persistent notification history.
- Configurable categories, thresholds, and quiet hours.
- Deep-link from notification to the relevant entity or incident.
- Explain why the notification fired.
- Use supported macOS background-service registration.

## CLI

The desktop app is the primary experience; the CLI supports automation,
diagnostics, inspection, testing, and export.

Candidate surface:

```text
hal map
hal status
hal health
hal explain <entity>
hal inspect <entity>
hal changes

hal apps
hal processes
hal persistence
hal reclaim
hal incidents
hal telemetry
hal doctor
```

The exact CLI is provisional and should emerge from real workflows rather than
be treated as a frozen contract.

## Dashboard/application views

- System overview
- Relationship atlas
- Applications
- Activity
- Resources
- Files
- Persistence
- Changes
- Reclaimable items
- Incidents
- Findings inbox
- Application footprint
- Settings, privacy, retention, and permissions
- HAL health and overhead

## Privacy and safety

- Local-only by default.
- No automatic malware verdicts.
- No automatic process termination.
- No automatic removal of unrecognized software.
- Sensitive process arguments disabled or redacted.
- Network destination collection optional and minimized.
- User activity and project-context collection explicitly opt-in.
- Clear permission explanations.
- Least privilege.
- Privileged helpers added only when proven necessary.
- Audit trail for user-authorized changes.

## Deferred possibilities

- Real-time Endpoint Security monitoring
- Finder or Quick Look extensions
- Menu-bar status view
- Shortcuts integration
- Widgets
- Native app uninstallation workflows
- Remote fleet management
- Windows and Linux collectors
- Cross-device comparison
- Optional local machine-learning models

These are not initial commitments.
