# Decision 0002: Contextual whole-machine atlas

## Status

Accepted on July 26, 2026 after the first Phase 0 product evaluation failed.

## Context

The original prototype exposed fixture selection, entity-type filters, a text
navigator, a graph, and a permanent inspector at launch. Although those pieces
exercised the domain model, the product owner could not determine what geordi was
for or how the concepts related. This failed the Phase 0 clarity thesis.

## Decision

- Replace disconnected scenarios as the primary product surface with one
  coherent fictional Mac.
- Open at a whole-machine orientation view organized around three user
  questions: reclaimable storage, installed software, and performance events.
- Use a stable sidebar and breadcrumb to preserve context while drilling in and
  back out.
- Lead with plain-language conclusions and reveal graph structure and evidence
  after the user chooses an area or application.
- Center application exploration on realistic installation origin, processes,
  produced files, startup behavior, resource impact, and incidents.
- Keep old focused fixtures as deterministic engineering coverage, not primary
  navigation.

## Consequences

Phase 0 remains synthetic and isolated, but now models one persistent world
that can be approached from multiple use cases. The next product evaluation
should judge whether users understand why geordi exists before inspecting the
details of any relationship.
