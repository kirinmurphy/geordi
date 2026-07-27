# Decision 0004: Inventory-first homepage

## Status

Accepted on July 26, 2026.

## Context

Even with familiar software and a whole-machine orientation, presenting the
relationship map at the start remained too demanding. The user first needs a
recognizable inventory and a reason to inspect an item.

## Decision

- Make the homepage a scannable inventory.
- Lead with recent alerts, user-installed applications, and a reclaim summary.
- Show application source, current behavior, footprint, and notable background
  activity directly in the inventory.
- Phrase the storage alert as “reclaimable storage is getting large”; Phase 0
  has not actually reclaimed or removed anything.
- Open the relational map only after the user selects an alert, application, or
  reclaim candidate.

## Consequences

The map becomes supporting context instead of the product's front door. HAL can
later add sorting, grouping, history, and real observations without changing
the basic information architecture.
