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

### Narrative before graph

Options considered were keeping the map as the application landing page,
placing a summary above the same map, and creating a dedicated story surface.
The dedicated story was selected because it directly tests whether HAL can
explain an application without requiring users to decode the graph.

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

## Remaining work

- Conduct at least three representative sessions using
  `PRODUCT_EVALUATION_GUIDE.md`.
- Record a go, revise, or stop decision. Evaluation sessions require real
  participants and are not claimed by implementation completion.

## Commits

- `9c23038` — Application Story, task-oriented home, guided fictional proof,
  tests, documentation, and evaluation materials.
