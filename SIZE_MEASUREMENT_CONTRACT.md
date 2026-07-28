# Bounded Size Measurement Contract

This contract defines the prerequisites for a future read-only size collector.
It does not authorize traversal, deletion, trashing, or cleanup. The current
collector stops after metadata inspection of each configured root.

## Scope and budgets

Every traversal must begin at a validated rebuildable-data manifest location
and enforce all versioned `measurementPolicy` limits:

- stop after `maxEntriesPerLocation` visited entries;
- stop below `maxDepth`;
- stop after `maxDurationMilliseconds` wall-clock time;
- check cooperative task cancellation at least every
  `cancellationCheckIntervalEntries` entries;
- remain on the root's filesystem device;
- never follow symbolic links.

Reaching any limit produces a partial observation with the exact stop reason,
visited-entry count, elapsed time, and incomplete byte totals. A partial total
must never be presented as the full size of a location.

Cancellation is a normal partial outcome. The collector returns promptly with
observations accumulated so far and does not convert cancellation into a
configuration or permission failure.

## Byte semantics

A future observation must keep these values distinct:

- logical bytes: file length, useful for explaining apparent content size;
- allocated bytes: filesystem blocks attributed to the visited entry;
- unique allocated bytes: allocated bytes after hard-link deduplication;
- completeness: complete or partial, with a stop reason when partial.

Directory entry sizes are not content totals. Totals are derived only from
visited non-directory entries.

Hard-linked files are counted once per filesystem file identity (device and
inode) within a measurement run. The identity set is bounded by the same entry
budget. If identity cannot be read, the entry is retained as unavailable rather
than guessed.

APFS clone extents may share physical storage without exposing enough
user-space information to attribute uniquely reclaimable blocks. HAL therefore
reports allocated bytes as potentially overlapping for clones and must not call
their sum "bytes that will be freed." Expected reclaimed bytes remain
unavailable until a separately reviewed filesystem-aware estimator exists.

## Boundaries and exclusions

Traversal may inspect descendants only after confirming the root still resolves
inside the linked user home. It must not cross mount/device boundaries, follow
symbolic links, or traverse a manifest-excluded descendant name. Exclusions are
matched as exact path components, not substrings or patterns.

Permission-denied, unreadable, disappeared-during-scan, and filesystem-boundary
entries remain explicit outcomes. Concurrent filesystem changes may make totals
approximate and must be disclosed.

## Safety and product behavior

Size measurement remains read-only and cannot enable cleanup by itself.
Rebuildability is detector evidence, size is an observation, and a removal
decision is a separate user-approved policy outcome. User data, shared data,
ambiguous ownership, symbolic links, partial measurements, and unknown
classifications default to protected.

Implementation requires deterministic tests for every budget stop, prompt
cancellation, symlink and mount boundaries, hard-link deduplication, clone
disclosure, permission changes, concurrent disappearance, and zero-content
directories before live traversal may be enabled.
