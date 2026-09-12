# geordi Next Exploration Refinements

Status: recommended next product sequence  
Updated: July 29, 2026

This record turns the latest hands-on findings into implementation boundaries.
It does not authorize destructive actions, arbitrary shell execution, or
unbounded collection.

## 1. Remove repeated homepage descriptions

Do not show per-row descriptions in homepage inventory lists. Within a section,
they repeat the section's meaning and make the inventory harder to scan.
Descriptions remain useful in the entity inspector, where a user has asked for
an atomic explanation.

## 2. Make installed items children of their software sources

Replace the separate **Installed Packages** section with a hierarchical
**Software Sources** section:

- each package manager or store is a clickable parent;
- each directly managed application or package is a clickable child;
- App Store is a source group whose children are applications with observed
  Mac App Store receipts;
- packages without a known manager appear in a clearly labeled **Other** or
  **Unattributed** presentation group; and
- managers with large inventories start collapsed and show their package count.

This structure answers both “what installed this?” and “what does this manager
own?” without making users reconcile two loose lists. The parent-child
relationship must be derived from observed provenance or graph relationships,
not package-name conventions. “Other” is a presentation group for missing
ownership evidence, not a fabricated package-manager entity. App Store
membership requires an observed receipt; path or developer signature alone is
insufficient.

Within a source, distinguish **Applications** from **Packages** with labeled
subgroups and different entity icons. An application is a user-facing macOS
application bundle. A package is a manager-owned installation record such as a
formula, cask, or npm package. A manager may own both kinds.

Do not merge an application and package merely because their names match. For
example, a Homebrew cask record and the application bundle it installed are
distinct entities with distinct identities and evidence, connected by an
installation/ownership relationship. Both remain clickable. This also allows a
package with no application artifact, such as TypeScript, to coexist with a
package whose artifact is a user-facing application.

Keep developer capabilities separate as well. A Go package can provide a Go
toolchain; those are different facts connected to the relevant entities rather
than alternate names for one undifferentiated row.

Large groups need search and disclosure. Rendering hundreds of children
expanded by default would reproduce the current noise in a deeper indentation.

## 3. Give question cards question-specific destinations

The cards under **What do you want to understand?** currently collapse several
different questions into the generic Installed Software destination. Each card
must retain its intent:

- **Understand an application** opens the application-oriented story/list;
- **See what starts automatically** opens persistence and launch relationships;
- **Browse command-line tools** opens the manager/package/command explorer;
- **Explore reclaimable data** opens rebuildable resources; and
- **Understand where software lives** opens the filesystem map.

Define the cards and stable intent identifiers in a versioned presentation
manifest. Swift should implement generic routing for supported intent types and
reject unknown destinations with a useful validation path. This also makes the
banner copy and destination testable as one contract.

## 4. Bound graph fan-out with progressive disclosure

The right response to a node with ten or more neighbors is not a taller canvas.
It is a summarized branch that can be explored deliberately.

Extend the existing display-policy presenter so every graph context can declare
fan-out rules by relationship and entity type:

1. Show a small ranked set of direct neighbors.
2. Replace the remainder with one counted group node, such as
   **12 support locations** or **8 installed packages**.
3. Let the group open as a searchable list or become the next focused graph.
4. Expand only one dense branch at a time.
5. Preserve evidence, count, and the reason items were grouped.

Ranking should use deterministic observed properties declared by policy, never
layout order. Edge bundling or smaller typography can supplement this behavior
but cannot solve the underlying information-density problem.

Add acceptance tests for high fan-out, stable grouping, keyboard access, group
counts, and a bounded initial viewport. The current application-detail
`mayBelongTo` grouping is a useful first case; the missing piece is consistent,
manifest-driven coverage across contexts and relationship types.

## 5. Glossary coverage

Glossary terms should look like prose, with the normal text color, a light
underline, and a small book icon. They should not resemble an inline call to
action.

SwiftUI has no browser-style mutation observer that can inspect and rewrite all
rendered text. Its view tree is declarative, and a rendered `Text` does not
expose a global DOM-like string surface. The maintainable equivalent is:

- keep aliases and definitions in the versioned glossary manifest;
- route user-facing copy through a reusable glossary-aware text renderer;
- tokenize exact manifest aliases before constructing the SwiftUI view; and
- present a shared popover or sheet from the selected attributed range.

Whole field labels can continue to use exact-alias lookup. Paragraph support
should be added once in the shared renderer rather than annotating every
occurrence by hand. Matching must prefer the longest alias, respect word
boundaries and context, and remain accessible without hover.

The repository contains **Bundle identifier** and **application bundle**, but
no occurrence of **bundle installer**. The former two are distinct domain
terms; “bundle installer” should not be introduced as an alias unless product
copy later uses that exact concept.

## Recommended order

1. Package-manager hierarchy and removal of loose Installed Packages.
2. Question-specific destinations, reusing the new command-line hierarchy.
3. Generalized graph fan-out policy and focused group exploration.
4. Glossary-aware paragraph rendering and a broader domain-language inventory.
