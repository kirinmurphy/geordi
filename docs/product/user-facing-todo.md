# HAL User-Facing Todo

Status: prioritized product gaps discovered during hands-on use  
Updated: July 30, 2026

These items should improve questions users can answer. They are not
authorization to add broad history, arbitrary command execution, or unbounded
filesystem scanning.

## Active completion milestone — product refinement

- [x] Strengthen manager, section, and nested-row hierarchy across Software
  Sources and other hierarchical lists.
- [x] Reuse the relationship explorer renderer for the read-only application
  preview, with the whole preview opening the full explorer.
- [x] Keep the full relationship-map action inside the evidence card; move
  filesystem and path actions to the page context where they belong.
- [x] Make the global path action look like underlined path text with one
  unambiguous menu affordance.
- [x] Derive **Bundled** versus **User installed** from bounded setup-time
  evidence, including “Present at setup · App Store managed,” while preserving
  an honest unknown state.
- [x] Represent App Store-managed applications as a Software Source alongside
  package managers, without conflating applications and packages.
- [x] Give every “What do you want to understand?” choice a destination that
  explains that question instead of routing aggregate questions to unbounded
  type-filtered relationship maps.
- [x] Keep high-fan-out relationship maps readable by grouping or summarizing
  large repeated branches without hiding the full evidence.
- [x] Apply a glossary-aware tooltip treatment to domain language, beginning
  with **bundle installer**, and inventory the remaining domain-specific terms.
- [x] Implement the deterministic first slice of the shell/PATH visualizer
  described in `SHELL_PATH_VISUALIZER_PLAN.md`, with explicit uncertainty and
  no implicit collection of shell-file contents.

## Priority 1 — Replace aggregate “everything graphs” with question-shaped views

Implementation status: completed. A versioned, schema-validated exploration
context catalog now selects each homepage destination. Applications open in a
searchable classified browser; startup declarations are grouped by observed
owner with an explicit unresolved section; reclaimability is summarized by
retained classification without treating rebuildable as safe to delete; and
command-line software begins in deterministic role and discovery-source
sections. Rows retain their real entity IDs and open the existing Application
Story or bounded relationship universe.

Current audit:

- **Understand an application** should begin with an application browser and
  open an individual Application Story. The complete application graph is not
  an adequate application picker.
- **See what starts automatically** should organize declarations by owning
  application and unresolved status, then offer a bounded relationship view
  for one selection.
- **Explore reclaimable data** can retain the graph where a centered storage
  concept groups repeated data nodes, but the live view needs the same
  deterministic grouping behavior as the synthetic example.
- **Browse command-line tools** should begin with structured source,
  installation-reason, runtime, shell-framework, and unclassified-command
  groups. It should not render every package and process in one graph.
- **Visualize shell PATH** and **Understand where software lives** already use
  purpose-built visualizations and are appropriate starting surfaces.

Implementation direction:

1. Add a versioned, validated exploration-context manifest. Each context
   declares its question, supported entity/relationship types, grouping detail,
   initial presentation kind, and bounded drill-in behavior.
2. Support purpose-built list/tree summaries as well as centered relationship
   maps. Do not manufacture a graph center in view code.
3. Reuse the display-policy grouping presenter for centered maps, with group
   definitions selected by the exploration manifest.
4. Keep every row and group connected to the underlying entity IDs so users can
   open the same evidence panel and bounded relationship universe.
5. Add deterministic tests proving that shuffled source observations yield the
   same context sections, member order, and graph projection.

Acceptance criteria:

- no question card initially renders a graph whose height scales directly with
  every entity of a broad type;
- each destination visibly answers the wording on its card before requiring a
  node selection;
- expanding a group or opening an entity preserves all underlying evidence;
- the same captured observations and manifest version produce identical
  sections, ordering, and group membership.

## Priority 1 — Explain background services and daemons

Roadmap: `DAEMON_EXPLAINER_PLAN.md`

Implementation status: Slice 2 process correlation completed. Live normalization preserves
every valid retained declaration, including unresolved ownership, with its
configured scope and kind. The startup browser separates unresolved items,
LaunchDaemons, and LaunchAgents; matched sections are grouped by owning
software. Exact retained executable identity is correlated to point-in-time
process observations through a versioned matching manifest. Loaded state
remains explicitly unavailable rather than being inferred from configuration
or process presence.

Current gap:

- HAL reads bounded LaunchAgent and LaunchDaemon declarations, but the live
  graph currently projects only declarations resolved to one application;
- declaration configuration is not the same as loaded or running state;
- users cannot yet see user-session agents, system-wide agents, daemons,
  unresolved ownership, and observed activity in one purpose-built explanation;
  and
- absence from a point-in-time process sample cannot prove inactivity.

Completed first slice:

1. Project every retained valid declaration, including unmatched declarations.
2. Preserve its manifest-defined scope and kind.
3. Add a deterministic declaration browser grouped by agent/daemon, scope,
   owner, and unresolved status.
4. Explain retained activation policy as configuration rather than activity.
5. Keep loaded and declaration-specific running state explicitly unavailable
   until dedicated read-only observations exist.

Completed second slice:

1. Added a versioned, schema-validated identity-matching strategy manifest.
2. Correlated exact declaration executable paths to exact retained process
   executable paths, with multiple-instance, ambiguous, partial, unavailable,
   permission-denied, and unmatched outcomes.
3. Preserved process observation timestamps, provenance, stable entity IDs,
   deterministic relationship IDs, and inconclusive absence language.
4. Reviewed `launchctl print` and `launchctl print-disabled`. No loaded-state
   collector was added because the available output is not yet justified as a
   bounded stable machine contract and may contain prohibited arguments or
   environment payloads. See `DAEMON_EXPLAINER_PLAN.md`.

Acceptance criteria:

- every retained declaration remains reachable;
- agents, daemons, owners, and unresolved declarations are visibly distinct;
- configured, loaded, and running remain separate states;
- every current-activity claim has captured point-in-time evidence;
- shuffled equivalent observations produce identical output; and
- the first slice performs no service mutation or privileged collection.

## Priority 1 — Explain shell frameworks installed outside package managers

Implementation status: completed in the current development boundary; linked
Mac evidence validation passed; representative UI sessions remain.

Observed example: Oh My Zsh installed through its published curl/bootstrap
flow at `~/.oh-my-zsh`.

Current gap:

- live collection has no shell-framework detector;
- the Oh My Zsh entity currently exists only in the fictional profile;
- point-in-time process collection cannot reconstruct a completed curl command;
  and
- command-line directory enumeration does not include framework directories.

Recommended user-facing outcome:

- show Oh My Zsh under **Developer tools** or a dedicated **Shell environment**
  group;
- explain its observed installation location, Git-backed update mechanism,
  active shell relationship when evidence exists, and enabled configuration
  state without retaining `.zshrc` contents;
- distinguish “installed from a Git checkout/bootstrap flow” from “HAL observed
  curl perform this installation”; and
- expose missing or unreadable evidence honestly.

Implementation direction:

- add a versioned shell-framework detector manifest;
- use bounded checks for the framework root and expected Git metadata;
- if Git origin is read, retain only a normalized provider/host and declared
  framework identity, never credentials, arbitrary config values, or full
  shell configuration;
- detect a bounded, specific `.zshrc` reference without retaining the file;
- associate observed zsh processes only through explicit evidence; and
- do not add general shell-command history.

Acceptance criteria:

- a newly installed Oh My Zsh checkout appears after **Check this Mac again**;
- HAL explains what was directly observed and does not claim to have witnessed
  the earlier curl command;
- no arbitrary repository or shell configuration is ingested;
- absent, unreadable, inactive, and observed states have tests.

## Priority 1 — Make Homebrew cask provenance reliable

Implementation status: completed in the current development boundary; linked
Mac evidence validation passed; representative UI sessions remain.

Observed example: Warp installed with Homebrew cask.

Current gap:

- `Download origin` reads the optional
  `com.apple.metadata:kMDItemWhereFroms` extended attribute;
- Homebrew installation does not guarantee that attribute exists;
- current cask detection relies on an application bundle resolving inside a
  configured Caskroom path; normal Homebrew casks can place a real bundle in
  `/Applications`, so that path rule is insufficient; and
- the formula collector enumerates `Cellar`, not installed casks in `Caskroom`.

Recommended user-facing outcome:

- show **Installed with Homebrew cask** as separate provenance evidence;
- keep **Download origin not observed** when the extended attribute is absent;
- explain that Homebrew ownership and browser/Finder download origin are
  different evidence sources; and
- connect the application to its owning cask without inventing a web origin.

Implementation direction:

- extend the Homebrew installation manifest with validated Caskroom resources;
- add bounded read-only cask inventory from Caskroom metadata or a fixed,
  versioned, timeout-bounded Homebrew JSON adapter;
- correlate casks to application bundles using declared artifacts, bundle
  identity, and validated canonical paths;
- never invoke an update or installation command; and
- preserve formula and cask concepts separately.

Acceptance criteria:

- Warp installed by Homebrew appears as a cask-owned application;
- removing `kMDItemWhereFroms` does not remove Homebrew provenance;
- `Download origin` remains explicitly unavailable rather than copying the
  Homebrew source into the wrong field;
- Intel and Apple Silicon prefixes, missing Caskroom, multiple versions, and
  ambiguous artifacts have deterministic tests.

## Priority 1 — Discover and offer compatible terminal applications

Implementation status: completed in the current development boundary; chooser
and reviewed-adapter behavior still need hands-on product validation.

Observed examples:

- Apple Terminal
- iTerm2
- Warp (`dev.warp.Warp-Stable`)
- cmux (`com.cmuxterm.app`)
- Ghostty

Current gap:

- the terminal adapter manifest lists only Apple Terminal, iTerm2, and Ghostty;
- HAL checks installed/running applications only against those known bundle
  identifiers;
- the menu title emphasizes one preferred terminal and nests the remaining
  adapters, making availability easy to miss; and
- a generic `NSWorkspace` folder-open request is not guaranteed to produce the
  desired new-window/current-directory behavior in every terminal.

Recommended user-facing outcome:

- the path menu visibly lists every installed compatible terminal;
- running terminals are ranked first;
- when several are running, the most recently activated supported terminal is
  preferred;
- the user can override and save a preference;
- unsupported installed terminal-like applications can be reported as
  candidates without being launched through an unverified strategy; and
- users can see why a candidate is supported or unavailable.

Discovery and adapter direction:

1. Enumerate installed applications from HAL's existing bounded application
   inventory and running applications from `NSWorkspace`.
2. Match bundle identifiers and declared URL schemes against a versioned,
   schema-validated terminal capability manifest.
3. Keep launch behavior in reviewed Swift strategies such as:
   - native folder open when the application declares support;
   - a validated application URL scheme;
   - an application-specific Apple event only when reviewed and permission-safe.
4. Do not execute a discovered terminal binary or infer capability from an
   application name alone.
5. Add an **Other Application…** fallback through the standard macOS chooser;
   remember it only with explicit consent.

Menu direction:

- show **Open in Terminal** as a submenu with all compatible installed apps;
- mark the preferred app;
- annotate running apps;
- include **Choose Another Application…**; and
- avoid hiding the complete list behind a label that looks like a single
  action.

Acceptance criteria:

- Warp and cmux appear when their reviewed adapters are installed;
- every displayed adapter has a verified directory-opening strategy;
- unknown bundle identifiers are never launched using guessed commands;
- ranking and saved preference are deterministic and tested;
- no Accessibility permission or terminal-window inspection is used.

## Product sequencing

These gaps should be evaluated alongside the Application Story sessions:

- prioritize shell frameworks if users ask where their shell environment came
  from;
- prioritize cask provenance if “where did this app come from?” remains
  unanswered; and
- prioritize adaptable terminal actions if path investigation is a frequent
  next step.

Observation History remains parked. These improvements can use current-state,
read-only evidence.
