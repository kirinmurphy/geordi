# Decision 0008: Contextual reference sheet

## Status

Accepted on July 26, 2026.

## Context

The generic system-model reference was presented as a sidebar destination with
a nonfunctional `Reference` breadcrumb namespace. That incorrectly made quick
help feel like workflow navigation and made the sidebar its exclusive entry
point.

## Decision

- Remove Reference from the destination and breadcrumb models.
- Remove the Reference sidebar section.
- Place **How this map works** directly beside each map summary.
- Present the generic model in a closable sheet attached to the current geordi
  window.
- Preserve destination, selection, map position, and zoom beneath the sheet.
- Support explicit Close and the Escape key.

## Consequences

Conceptual help is available where it is needed without changing navigation or
opening another application window. The same sheet can later be linked from
other contextual help affordances without creating a Reference namespace.
