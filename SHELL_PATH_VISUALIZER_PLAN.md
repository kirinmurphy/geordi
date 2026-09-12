# Shell and PATH Visualizer Plan

Status: proposed major feature  
Updated: July 29, 2026

## Product question

Explain how shell startup files construct `PATH`, which file contributed each
entry, what order entries take, and where behavior is conditional or unknown.
The feature should make shell configuration understandable without executing
user configuration or pretending static analysis is complete.

## Feasibility

This is highly feasible for an explainable, deterministic subset of common
Bash and Zsh configuration. A complete static answer is impossible in general:
shell files may run commands, inspect machine state, use `eval`, compute names,
source dynamically selected files, or branch on values that only exist in a
particular terminal session.

The correct model is therefore not “fully evaluate the shell.” It is “parse
recognized constructs, preserve conditions and ordering, and display unresolved
behavior honestly.”

An LLM is not required for the core feature. It can later provide optional
plain-language explanations, but it must not be the authority for graph facts.

## User experience

The primary diagram should read left to right:

1. shell invocation context, such as Zsh interactive login;
2. startup files in their applicable order;
3. sourced files and conditional branches;
4. individual `PATH` mutations; and
5. the resulting ordered path entries.

Each resulting entry should show:

- its source file and line;
- prepend, append, replace, or remove behavior;
- literal, expanded, conditional, or unresolved state;
- duplicates;
- paths that do not currently exist; and
- command-shadowing implications when two directories contain the same known
  executable.

Dense branches should use the same counted-group and focus behavior proposed for
the main graph. A textual timeline is the accessible companion to the diagram.

## Deterministic analysis boundary

The parser must never execute or source a configuration file.

The first version should recognize:

- `PATH=...` and `export PATH=...`;
- `$PATH`, `${PATH}`, quoted strings, and literal path components;
- Zsh `path=(...)` assignments for a documented subset;
- literal `source file` and `. file` references;
- simple, statically recognizable conditionals; and
- comments and source locations needed for explanation.

Unsupported command substitutions, dynamic source paths, `eval`, functions, or
complex expansions become explicit unresolved nodes. The visualizer may show
the text shape of an expression after redaction, but must not guess its result.

Shell startup order differs by shell and invocation mode. Those rules, allowed
roots, recognized syntax adapters, and resource limits belong in versioned,
schema-validated manifests. Generic parsing, validation, and security
invariants remain in code.

## Data contract

Add a versioned declarative schema shared by synthetic and live observations.
The conceptual records are:

- analysis session and shell invocation context;
- bounded source file references;
- ordered statements with source ranges;
- conditional branches;
- source/include edges;
- environment mutations;
- normalized path entries;
- unresolved expressions; and
- diagnostics.

Every derived path entry must point back to observed source evidence. Observed
file text, derived expansions, inferences, and user-selected invocation context
remain distinct. Unknown keys, invalid enum values, duplicate statement IDs,
and broken graph endpoints must fail validation.

Committed synthetic profiles should cover login versus interactive behavior,
missing files, cycles in sourced files, conditional branches, prepend/append,
replacement, duplicates, nonexistent directories, and unresolved expressions.

## Collection and privacy

Start with an editor-like mode where the user explicitly selects or pastes
configuration. Live Mac analysis is a later, explicit read-only capability.

For live analysis:

- read only startup resources declared by the selected shell profile;
- resolve includes only within bounded, validated roots and depth;
- limit file count, size, parse time, and recursion;
- never read shell history;
- never expand arbitrary variables by invoking a shell;
- redact likely secrets before persistence or diagnostics;
- retain normalized facts rather than full file contents by default; and
- show unreadable, skipped, oversized, and unsupported inputs.

Linking a Mac must remain explicit. Ordinary first launch continues to use only
synthetic data and performs no real collection.

## Optional LLM layer

An LLM may be useful for explaining an unresolved construct or proposing a
human-readable summary. It should be a separately consented adapter with these
constraints:

- deterministic parsing runs first;
- only a minimized, redacted representation is sent;
- raw configuration is not sent by default;
- output conforms to a narrow, versioned schema;
- schema and semantic validation reject invented files, paths, or edges;
- LLM output is labeled inferred and never changes observed facts; and
- the diagram remains useful when the adapter is disabled or unavailable.

Do not use an LLM to simulate shell execution or silently fill gaps.

## Delivery phases

### Phase 1 — Synthetic model and static prototype

Define the schema, manifests, and deterministic fixtures. Build the timeline and
diagram from synthetic examples before adding filesystem access.

### Phase 2 — Deterministic parser

Parse the bounded Bash/Zsh subset, retain source ranges, emit unresolved nodes,
and add fixture-based conformance and safety tests.

### Phase 3 — Explicit live-file analysis

Add contextual read-only linking for declared startup resources, limits,
diagnostics, and a preview of what will be read.

### Phase 4 — Effective-path comparison

Compare the derived result with a separately observed environment only when its
provenance is known. Explain differences instead of treating the current geordi
process environment as the user's shell truth.

### Phase 5 — Optional explanation adapter

Evaluate an opt-in, schema-constrained LLM explanation layer only after the
deterministic experience is useful on its own.

## Acceptance boundary

The first shippable version succeeds when a user can select a synthetic or
explicitly chosen Bash/Zsh configuration and answer:

- which files participated;
- where each visible `PATH` entry came from;
- what order mutations occurred in;
- which parts geordi could not resolve; and
- why the displayed result may differ from another terminal session.

It must do so without executing shell code, collecting history, or claiming
certainty across unresolved dynamic behavior.
