# geordi Background Services and Daemon Explainer

Status: Slice 2 process correlation complete; loaded-state collection deferred
Updated: July 30, 2026

## Product promise

geordi should explain background software in plain language without treating every
startup declaration as suspicious or every configured service as currently
running.

The starting surface answers:

> What background services are configured, and what are they observed doing
> now?

It must separate four kinds of fact:

1. **Declared** — a bounded configuration record exists.
2. **Loaded** — a read-only system source reports that macOS currently knows
   about the service.
3. **Running** — a point-in-time process observation matches retained identity
   evidence.
4. **Owned** — evidence connects the declaration or executable to an
   application, package, or other software entity.

None of these states implies the others unless geordi retains evidence for the
relationship.

## First-screen design

Begin with a structured browser, not an aggregate relationship graph.

Deterministic sections:

- user LaunchAgents;
- system-wide LaunchAgents;
- LaunchDaemons;
- login items and other supported persistence kinds as they become available;
- currently observed background processes with a declaration match;
- configured declarations not currently observed running;
- unresolved ownership;
- unreadable or partially observed declarations.

Rows show only retained facts:

- display label;
- persistence kind and scope;
- declared executable when retained;
- activation policy summarized from explicitly supported keys;
- loaded-state evidence and observation time when available;
- matched running-instance count and observation time;
- owning software and relationship confidence;
- signature or package evidence when collected; and
- a clear uncertainty explanation.

Selecting a row opens its evidence and bounded relationship universe. Aggregate
groups preserve access to every underlying entity.

## Manifest-driven composition

Add a versioned, schema-validated background-service definition manifest. It
declares:

- stable persistence kinds and display language;
- supported scopes;
- retained activation keys and their plain-language explanations;
- section order and grouping;
- identity-matching strategies and priorities;
- supported relationship types;
- initial presentation budget;
- empty, unavailable, partial, inactive, and unresolved states; and
- bounded drill-in behavior.

Growable service kinds, activation labels, grouping rules, and matching
strategies do not belong in Swift switches. Swift implements generic adapters,
schema-backed factories, validators, and presenters. Security invariants remain
in code.

## Observation model

Extend the canonical profile schema only when the first runtime-state collector
is ready. Synthetic and live profiles use the same contract.

Required distinctions:

- declaration presence is observed configuration metadata;
- loaded state is a separate time-sensitive observation;
- process presence is a separate point-in-time observation;
- ownership is derived or inferred with evidence and confidence;
- absence from one process snapshot is not proof that a service is disabled,
  unloaded, or never runs;
- a restart policy is configuration, not proof that restarts occurred; and
- geordi never infers purpose or safety from a label, executable name, or path
  alone.

## Delivery slices

### Slice 1 — Honest declaration browser

Implementation status: completed in the current development boundary.

- Project every valid retained declaration, including unmatched declarations.
- Preserve declaration kind and configured scope.
- Group declarations deterministically by scope, kind, owner, and unresolved
  state.
- Explain `RunAtLoad` and retained `KeepAlive` evidence as configuration only.
- Link matched declarations to existing application evidence.
- Keep all unresolved declarations navigable.

Exit: the browser explains all retained declarations without implying that they
are loaded or running.

### Slice 2 — Point-in-time activity

- [x] Correlate exact observed executable identity to existing process
  snapshots through a versioned, schema-validated strategy manifest.
- [x] Show observed running instances separately from loaded state, retaining
  point-in-time observation timestamps, process entity IDs, and evidence.
- [x] Represent unavailable, permission-denied, partial, unmatched, and
  ambiguous process-correlation results without treating absence as
  inactivity.
- [ ] Add loaded-service observation. The feasibility review below did not
  justify a collector in this slice.

Process-correlation exit: complete. Loaded state remains explicitly unavailable.

#### Loaded-state feasibility result

The reviewed built-in candidate was `launchctl print` for a specific launchd
domain or service target. It is read-only and can be timeout-limited, but its
human-oriented output is not a stable, documented machine schema; a domain
print can be broad; and output may expose arguments, environment values, and
other payload geordi is prohibited from retaining. Enumerating targets would also
require a separately bounded and manifest-defined source of loaded identifiers.
`launchctl print-disabled` reports disabled overrides, not loaded state, and
process presence cannot substitute for either source.

No loaded-state collector is added. Before reconsideration, geordi needs a reviewed
field allowlist and parser, manifest-defined domains and record budgets,
fixtures for OS output variants, deterministic normalization, explicit timeout
and permission outcomes, and proof that prohibited payloads are discarded
before persistence. Ordinary synthetic launch remains non-collecting.

### Slice 3 — Ownership and provenance

- Connect services to applications, package managers, installer receipts, and
  signing identities using retained evidence.
- Explain shared helpers and multi-owner ambiguity.
- Identify orphan candidates only when the owning software is absent and the
  evidence rule is explicit; do not recommend deletion.

Exit: representative third-party services have an evidence-backed owner or a
specific unresolved explanation.

### Slice 4 — Change history

- Defer until the local history milestone is authorized.
- Record first seen, last seen, declaration changes, loaded-state changes, and
  identity changes.
- Distinguish a changed declaration from a newly observed process.

Exit: geordi can explain what changed without retaining arbitrary property-list
contents or process arguments.

## Privacy and safety

- Read only configured, bounded persistence roots.
- Retain only allowlisted declaration fields.
- Never retain arbitrary environment dictionaries, arguments, secrets, or
  property-list payloads.
- Do not enumerate Apple system service directories unless separately reviewed
  and explicitly configured.
- Do not invoke service mutation, unload, disable, bootout, delete, or repair
  operations.
- Do not label a service malicious, unnecessary, or safe from its name.
- Keep privileged collection out of the first slices.

## Determinism

- Stable section, service, instance, relationship, and group ordering.
- Stable group IDs and membership.
- No dependence on dictionary, set, filesystem, or process enumeration order.
- Shuffled equivalent observations produce identical presentation output.
- Observation timestamps remain explicit facts and do not change identity.

## Verification

Add tests for:

- manifest schema validation, unknown keys, invalid enums, and versions;
- required context and section coverage;
- LaunchAgent versus LaunchDaemon and user versus system scope;
- deterministic section/member ordering and stable group IDs;
- shuffled declaration, loaded-state, process, and ownership observations;
- matched, unmatched, ambiguous, inactive, unavailable, partial, and
  permission-denied states;
- declaration-versus-loaded-versus-running language;
- preservation of every declaration and source entity ID;
- bounded first-screen size and drill-in graph size;
- synthetic/live schema parity; and
- ordinary synthetic launch performing no live collection.

## Acceptance criteria

- Every retained third-party declaration is visible or represented in an
  explicit unavailable/partial state.
- The first screen separates agents, daemons, scope, ownership, and observed
  activity.
- geordi never equates configuration with a running process.
- Every “running” claim has a point-in-time process observation.
- Every “loaded” claim has a dedicated loaded-state observation.
- Users can reach the evidence and bounded relationships for every item.
- Identical observations and manifest versions reproduce identical output.
- No mutation or privileged helper is introduced.
