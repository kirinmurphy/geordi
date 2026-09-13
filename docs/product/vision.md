# HAL Product Vision

## Thesis

HAL is a macOS application that explains how software, processes, files,
persistence, resource consumption, installations, and system events relate to
one another.

macOS already exposes much of this information, but distributes it across
System Settings, Activity Monitor, Finder, Console, storage reports, installer
receipts, and command-line utilities. These surfaces generally provide tables
and totals rather than explanations.

HAL's job is to turn those facts into an understandable system model:

> Every important number should be connected to an owner, a history, an
> explanation, and—when appropriate—a safe action.

## Product problem

A user may see that:

- System Data is large.
- A process is consuming substantial CPU.
- Memory pressure has increased.
- An unfamiliar login item exists.
- An application occupies more space than expected.
- Removing an application left files behind.

The operating system rarely makes the relationships clear:

- Which application owns the process?
- Which helper launched it?
- Why did it become active?
- Which files is it using or growing?
- Where did the application come from?
- What persists after login or reboot?
- What changed immediately before a resource incident?
- Can the associated data be safely reclaimed?

HAL exists to answer those questions.

## The system atlas

The primary interface is a navigable, temporal relationship map—not another
dashboard of disconnected percentages.

```text
Installer/package
      |
      v
Application ---- owns ----> helper/service
      |                          |
      | launches                 | persists through
      v                          v
Processes <--------------- login item/agent/daemon
      |
      +---- consumes ----> CPU, memory, disk, network
      |
      +---- reads/writes -> files, caches, logs, user data
      |
      +---- participates -> incidents and historical patterns
```

Users can enter the map from any direction:

- Select an application to see its processes, files, footprint, helpers,
  persistence, signature, provenance, and history.
- Select a resource spike to see contributing processes and nearby events.
- Select a folder to see likely owners, active users, growth, and removability.
- Select a persistent item to see what installed and executes it.
- Select an installation to see its observed footprint.

## Interface philosophy

HAL uses progressive disclosure:

1. **Overview:** a few understandable systems and current findings.
2. **Lens:** applications, activity, resources, files, persistence, changes,
   reclaimable items, or incidents.
3. **Entity:** a single application, process, folder, helper, or incident.
4. **Evidence:** paths, signatures, timestamps, metrics, receipts, and raw
   relationships supporting the explanation.

The first layer should be understandable without hardware expertise. Evidence
must remain available for expert inspection.

The relationship map is custom, zoomable, filterable, and interactive. The
automotive 3D analogy is a product metaphor, not a literal rendering
requirement. Initial implementation should use a legible 2D or 2.5D
visualization with stable spatial organization.

## Product boundaries

HAL is:

- A system explanation tool
- A historical inventory
- A relationship visualizer
- A reclaimability investigator
- A software and persistence atlas
- An incident recorder
- A review and decision aid

HAL is not:

- A generic "Mac optimizer"
- An antivirus product
- An automatic process killer
- A one-click destructive cleaner
- A replacement for Apple's security protections
- A dashboard that merely combines existing tables

"Unrecognized" means that HAL or the user has not classified something. It
does not mean malicious.

## Platform strategy

HAL is intentionally macOS-first. Deep value requires understanding native
concepts such as:

- Application bundles and bundle identifiers
- Signing Team IDs, Gatekeeper, and notarization
- Login items, LaunchAgents, and LaunchDaemons
- App Sandbox and group containers
- XPC services and privileged helpers
- Package receipts
- Unified Logging
- FSEvents
- Memory pressure and APFS behavior
- System and Endpoint Security extensions

The domain model and collector boundaries should remain adaptable, but Windows
and Linux support are not V1 deliverables. Portability must not dilute macOS
understanding.

## Product validation

The first thesis to prove is:

> Can HAL show one real application and explain its processes, files,
> persistence, identity, footprint, and recent activity more clearly than
> existing macOS tools?

If that interaction is not meaningfully clearer, the project should pause
before adding advanced telemetry or privileged monitoring.

## Success indicators

- A nonexpert can explain why an application is active.
- A user can distinguish user data from reclaimable support data.
- A process can be traced to an application or clearly marked as unresolved.
- A persistent item can be traced to its likely owner.
- Changes between scans are understandable.
- Every cleanup recommendation explains its evidence and risk.
- Incident views provide useful context rather than merely reporting a spike.
- HAL's own resource use remains small, measurable, and visible.
