# HAL User-Facing Todo

Status: prioritized product gaps discovered during hands-on use  
Updated: July 29, 2026

These items should improve questions users can answer. They are not
authorization to add broad history, arbitrary command execution, or unbounded
filesystem scanning.

## Priority 1 — Explain shell frameworks installed outside package managers

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
Mac product validation remains.

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
