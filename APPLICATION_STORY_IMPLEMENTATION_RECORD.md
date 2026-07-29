# Application Story and Guided Proof Implementation Record

Status: implementation complete; product evaluation pending  
Specification: `NEXT_PRODUCT_VALIDATION_PLAN.md`

## Completed work

- Added a task-oriented home section organized around user questions rather
  than collector categories.
- Made application selection open a narrative Application Story before the
  relationship map.
- Added At a glance, activity/startup, origin, associations, explicit unknowns,
  and Explore the evidence sections.
- Preserved the Relationship Map as supporting evidence and the Filesystem Map
  as location context.
- Added calm missing states for absent process, startup, provenance, and
  associated-location evidence.
- Added a schema-validated, manifest-driven five-step fictional walkthrough.
- Made the walkthrough dismissible, replayable, keyboard navigable, and clearly
  fictional.
- Added a moderated evaluation guide and privacy-conscious session template.

## Decisions

### Homebrew cask ownership is independent provenance

HAL now inventories configured Homebrew Caskroom roots without running
Homebrew, reads only bounded local install receipts, and projects formulae and
casks as separate package concepts. A declared `.app` artifact is correlated
to the bounded application inventory by its artifact name or bundle identifier;
ambiguous matches are not projected. The Application Story prefers the
resulting **Installed with Homebrew cask** explanation while download-origin
metadata remains an independent optional filesystem observation.

The alternatives were continuing to rely on resolved bundle containment or
invoking Homebrew for JSON. Containment does not cover every cask installation
shape, and a subprocess was unnecessary because the installed receipt provides
the required bounded evidence.

### Terminal compatibility is declared and capability checked

The path menu now has an explicit **Open in Terminal** submenu. A versioned
manifest declares reviewed bundle identifiers, required URL schemes, and a
small closed set of launch strategies; Swift retains control of the strategies
and never executes a discovered application binary. Availability requires an
installed bundle-identifier match and any declared URL-scheme capability.

Warp uses its documented `warp://action/new_window` directory action. The
installed cmux bundle declares `public.folder` support, so it uses the native
workspace folder-open strategy. Running adapters rank before non-running ones,
and the most recently activated running adapter ranks first. A saved preference
is an explicit user decision. The standard application chooser requires a
second explicit **Open Once** or **Open and Remember** decision for an
unreviewed application.

### Shell frameworks use bounded identity evidence

Linked collection now evaluates versioned shell-framework definitions. The
first definition recognizes Oh My Zsh only when its declared root and expected
framework/Git markers are present. Git inspection is limited to a small local
metadata file and retains only a matching provider host. `.zshrc` inspection
is limited by a fixed byte budget and records only active, inactive, absent, or
unreadable state; contents and credentials are never normalized.

The Application Story describes the result as consistent with a Git/bootstrap
installation and explicitly says HAL did not witness the original install
command. General shell history was rejected because it would add sensitive,
unbounded evidence without improving the truth of this current-state claim.

The linked acceptance pass also removed the obsolete resolved-path Homebrew
cask provenance adapter after it produced a contradictory negative beside the
stronger receipt-backed ownership detail. Application classification version 4
now supports a generic `startsWith` detail rule and selects Homebrew Casks from
the receipt-backed **Installed with** value.

When an active declared shell configuration and an exact manifest-declared
shell executable are both observed, HAL projects a bounded, possible
framework/process relationship. The explanation explicitly preserves the gap
between “may load this active configuration” and “proved loaded.”

### Narrative before graph

Options considered were keeping the map as the application landing page,
placing a summary above the same map, and creating a dedicated story surface.
The dedicated story was selected because it directly tests whether HAL can
explain an application without requiring users to decode the graph.

### Homepage rows prioritize differences

Entity summaries remain part of the atomic entity and detail/story views, but
the homepage no longer repeats them beneath every entity name. Within a
homepage section those summaries were nearly identical and made the inventory
harder to scan. Rows now keep the distinguishing title, icon, and trailing
fact; alert rows retain their explanatory subtitle because each alert message
is materially different.

### Existing evidence only

The story derives every claim from existing entity details, relationships,
confidence, and evidence. No new collector, history store, measurement engine,
background sampling, or privileged source was added.

### Explicit absence

Empty sections remain visible with plain-language explanations. This makes
missing evidence part of the product model rather than allowing a sparse live
application to appear broken.

### Manifest-driven walkthrough

The walkthrough content and fictional story target live in a versioned,
validated manifest. Swift implements generic presentation and navigation.

## Verification

- Application Story model tests cover categorized relationships and honest
  missing states.
- Guided-proof tests validate the manifest, reject unknown keys, and verify the
  configured story target exists in the committed fictional profile.
- `make verify` passed with strict formatting, 120 tests across 25 suites,
  validation of all seven synthetic profiles, Debug build, native application
  packaging, and bundle smoke validation.
- The verified development build was installed at `~/Applications/HAL.app` and
  launched for manual evaluation.
- Homebrew-focused tests cover schema versioning, unknown keys, unsafe paths,
  formula inventory, Caskroom artifacts, bundle identity, and the independent
  Application Story ownership projection.
- Terminal-focused tests cover manifest validation, Warp and cmux identity,
  declared capability, installed/running availability, activation ranking,
  saved preference state, unsupported candidates, and safe file/directory
  target selection.
- Shell-framework tests cover schema validation, unknown keys, unsafe paths,
  observed, absent, inactive, unreadable, ambiguous, and symlink-escape states,
  redacted Git identity, and the non-historical user-facing explanation.

## Remaining work

- Conduct at least three representative sessions using
  `PRODUCT_EVALUATION_GUIDE.md`.
- Record a go, revise, or stop decision. Evaluation sessions require real
  participants and are not claimed by implementation completion.

## July 29 product-refinement boundary

The application story now embeds the exact relationship-canvas renderer in a
read-only preview. Its entire surface opens the full explorer, while the
relationship-map action stays inside the evidence card and filesystem/path
actions sit in page context.

The story header cross-checks the point-in-time process graph with
`NSWorkspace` bundle identity for the live status badge. This keeps an
observably running application from appearing offline when process resolution
is incomplete; it does not rewrite retained graph evidence.

Application grouping now treats installation source and installation timing as
separate facts. A versioned application-search manifest declares the bounded
Mac setup marker and tolerance. Bundle creation relative to that marker yields
**Present at setup**, **Added after setup**, or **Unknown**. Classification can
therefore show **Bundled Software** independently from **App Store managed**,
including “Present at setup · App Store managed.”

The App Store is also exposed as a manifest-selected Software Source with
clickable application children. Package-manager applications and packages
remain distinct owned entity types.

The completed refinement boundary passed strict formatting, 140 tests across
27 suites, all seven synthetic-profile validations, Debug build, native bundle
packaging, and UI bundle smoke validation. The verified build was installed at
`~/Applications/HAL.app` and launched; automated window inspection remained
unavailable because System Events does not have Accessibility access.

## Commits

- `9c23038` — Application Story, task-oriented home, guided fictional proof,
  tests, documentation, and evaluation materials.
