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

Filesystem story sections now render only path ancestors as folders. The final
path component remains the observed entity leaf, so an application such as
`/Applications/Warp.app` is not represented as a synthetic `Warp.app` folder
containing a second Warp item. A single connector canvas draws each row's
continuous ancestor trunks and branch, stopping each trunk at its last
descendant.

Application evidence maps now use display-policy schema version 2. A
relationship rule may request a bounded traversal depth; the application
policy uses two ownership hops so confirmed provenance such as
Homebrew → cask → application remains visible as its real chain. This does not
flatten provenance into an invented direct relationship.

Dense relationship groups now retain the stable identifiers of their members
as display-only metadata. Group nodes use a stacked-card treatment, and their
inspector replaces generic technical details with a top-level **Includes**
section. Each member uses its entity icon and color and can be opened to reset
the map around that real entity; grouping therefore reduces height without
making the underlying nodes inaccessible.

Application classification schema version 9 separates matching priority from
manifest-defined display order. User-installed applications consequently lead
both the homepage filter and App Store source groups. App Store receipt remains
management provenance, not evidence that a third-party application was bundled.
Bundle dates older than `.AppleSetupDone` are described as **Predates setup
marker**, because migration or restoration can preserve a date older than the
current Mac setup marker.

## July 30 software-architecture refinement

HAL's projected live graph is canonically ordered by stable entity and
relationship IDs before it reaches any view. Dictionary and filesystem
enumeration order therefore cannot change the displayed ordering. Labels,
classifications, grouping, stages, and thresholds come from validated versioned
manifests or directly observed system metadata; presentation code does not
LLM-generate system facts. Time-sensitive values such as processes and
freshness remain explicitly observed facts. Given the same captured
observations and manifests, HAL produces the same graph and presentation.

HAL now requires a successful, timeout-bounded version response before
presenting an executable as an installed runtime. This prevents Apple's
`/usr/bin/java` and `/usr/bin/javac` launcher stubs from appearing as available
Java installations when they report that no Java runtime exists.

Homebrew formula inventory remains filesystem-only and now reads bounded local
`INSTALL_RECEIPT.json` files. The receipt's `installed_on_request` property
separates **User-installed packages** from **Dependencies**, while
`runtime_dependencies` creates confirmed package-to-dependency relationships.
These are Homebrew receipt claims, not LLM classifications and not a claim that
dependency formulae were bundled with Homebrew itself.

The semantic graph columns moved to a versioned, validated manifest. The former
Software column is split into **Applications & Frameworks** and **Packages &
Developer Tools** without inventing new entity types. Dense ownership grouping
can use a manifest-selected entity detail, allowing Homebrew and App Store
views to group nodes by the same categories shown on the homepage.

Changing the graph's center is now a separate lifecycle action from selecting a
node in the current graph. Nodes offer **See all** to redraw around that entity,
and the inspector retains back/forward history for those universe changes.

The application Origin Story presents its ordinary application path as a
compact path-action row. Separate provenance artifacts, such as Homebrew
Caskroom nodes, retain the filesystem tree treatment.

HAL's shared visual scale now defines `sm`, `base`, `large`, `xl`, and `2xl`
text sizes plus small, base, large, and extra-large icon sizes. The minimum text
role increased to 14 points, homepage list icons use the larger shared base
scale, and generic application nodes use the idiomatic multiple-window symbol.

The completed refinement boundary passed strict formatting, 149 tests across
27 suites, all seven synthetic-profile validations, Debug build, native bundle
packaging, and UI bundle smoke validation. The verified build was installed at
`~/Applications/HAL.app` and launched; automated window inspection remained
unavailable because System Events does not have Accessibility access.

## Commits

- `9c23038` — Application Story, task-oriented home, guided fictional proof,
  tests, documentation, and evaluation materials.
