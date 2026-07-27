# Decision 0006: Responsive, structured relationship graph

## Status

Accepted on July 26, 2026.

## Context

Large category graphs became unreadable because they displayed every compatible
entity, allocated a separate column to every entity type, and shrank the whole
surface to fit beside a fixed inspector.

## Decision

- Put the inspector beside the graph only at wide widths; move it below the
  graph when horizontal space is constrained.
- Give the map at least 620 points in the wide layout.
- Project category graphs to bounded relevant neighborhoods.
- Replace one-column-per-type layout with five semantic stages:
  Context & Sources, Software, Runtime & Startup, Data, and Impact.
- Render labeled background regions for those stages.
- Use tighter row and column spacing without shrinking node surfaces.
- Preserve a minimum readable zoom and allow overflow panning rather than
  reducing labels below useful size.

## Consequences

The graph communicates a nonliteral backbone without implying that every
relationship is strictly linear. Cross-stage and within-stage edges remain
visible. Extremely dense neighborhoods may still need additional aggregation
or expand/collapse behavior after product evaluation.
