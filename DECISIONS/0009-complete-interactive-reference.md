# Decision 0009: Complete interactive user-facing reference

## Status

Accepted for Phase 0.

## Context

The first reference diagram explained only the middle of HAL's model: software,
runtime, data, resources, and events. It omitted where those things live, their
identity and provenance, how observations become findings, and the user's role
in deciding what happens next. Static cards also provided too little context
for an unfamiliar concept.

## Decision

The same-window reference sheet presents the complete user-facing conceptual
model:

1. Mac and storage
2. Installation and identity
3. Software
4. Runtime
5. Persistence
6. Data
7. Resources
8. Events and incidents
9. Relationships and evidence
10. Findings and alerts
11. Decisions and safe actions

Runtime and persistence remain separate because “running now” and “able to
start or return automatically” answer materially different user questions.
Relationships and evidence are explicit because HAL must distinguish observed
facts from confidence-bearing inference.

Each concept is selectable. The diagram dims in place while the concept expands
into a centered detail card containing the question it answers, a plain-language
explanation, and examples. Closing the card restores the diagram without adding
page height or changing scroll position. This is a product reference, not an
implementation architecture diagram: collector processes, databases,
synchronization, and privileged mechanisms are intentionally excluded.

The Home page has no redundant title block. Global search lives at the trailing
edge of the native macOS toolbar, on the same row as the system-provided sidebar
toggle. A thin, full-window-width yellow fictional-environment banner occupies
the next row. It can be hidden from the banner and restored from the toolbar;
because it sits outside the split view, all page and sidebar content resizes
rather than scrolling behind it.

## Consequences

- The diagram can honestly serve as HAL's complete high-level user model.
- Users can learn concepts in place without navigating away from their work.
- Implementation architecture remains documented separately and cannot be
  mistaken for a user-facing system concept.
- The compact toolbar and banner treatment requires visual evaluation across supported
  window sizes.
