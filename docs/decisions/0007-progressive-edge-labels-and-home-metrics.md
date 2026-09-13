# Decision 0007: Progressive edge labels and Home activity metrics

## Status

Accepted on July 26, 2026.

## Context

Relationship labels overlapped nodes and one another. Their identical blue
outlines also made inactive relationships look persistently selected. Home
lacked a concise view of current activity.

## Decision

- Show no breadcrumb on Home.
- Start detail breadcrumbs with a fully clickable **Home** item and remove the
  separate back chevron.
- Collapse unselected relationship labels to quiet arrow markers.
- Reveal relationship text on hover; reserve the strong outline for an
  explicitly selected relationship.
- Keep entity-selected edges highlighted, but do not make every related label
  look selected.
- Add a clearly synthetic Current Activity snapshot between Alerts and
  Applications: CPU, memory, running applications, and background activity.

## Consequences

The graph retains access to every relationship without showing every phrase at
once. Hover is supplemental; relationship meaning remains available through
selection, the inspector, help text, and accessibility labels.
