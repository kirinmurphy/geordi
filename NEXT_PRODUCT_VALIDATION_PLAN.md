# Next Product Validation Plan — Application Story and Guided Proof

Status: implemented; representative product evaluation pending
Priority: user-facing proof before additional plumbing  
Constraint: use current observations and fixtures; do not start Future Phase 6

## Product question

Can HAL help a person answer, in under two minutes:

> What is this application, why is it active, where did it come from, what does
> it place on my Mac, and what should I investigate next?

The relationship and filesystem maps are ingredients. The next phase must prove
that HAL can turn them into a coherent explanation without requiring users to
learn HAL's data model first.

## Recommended experience

### 1. Task-oriented home

Replace collection-shaped navigation emphasis with questions users recognize:

- **Understand an application**
- **See what starts automatically**
- **Explore reclaimable data**
- **Browse command-line tools**
- **Understand where software lives**

Each entry should state what the user will learn. Existing destinations can be
reused; this is information architecture and presentation work, not new
collection.

### 2. Application Story page

Make a selected application open into a readable narrative before showing its
relationship map:

1. **At a glance** — identity, current state, source, and confidence
2. **Why it may be active** — observed processes and startup declarations
3. **Where it came from** — signing, receipt, download, or package evidence
4. **What HAL associates with it** — meaningful support locations, caches,
   helpers, and command-line tools
5. **What HAL does not know** — unavailable or ambiguous evidence
6. **Explore** — Relationship Map, Filesystem Map, paths, and raw evidence

Unknown and unavailable states should read as intentional product explanations,
not missing UI.

### 3. Guided fictional proof

Add a short, optional walkthrough using one strong synthetic application story.
It should demonstrate:

- direct observation versus inference;
- why a process is connected to an application;
- why something starts automatically;
- the difference between support data and rebuildable data;
- how the same item appears in relationship and filesystem context.

The walkthrough must be dismissible, replayable, keyboard accessible, and
clearly fictional.

### 4. Comparison-quality presentation

Polish the surfaces needed for a side-by-side product evaluation:

- consistent section hierarchy and typography;
- calm empty, unavailable, partial, and ambiguous states;
- application icons and compact evidence summaries;
- obvious transitions from summary to map to inspector;
- reliable Back/Home behavior;
- helpful copy actions and shareable redacted screenshots or summaries where
  existing data permits.

Do not undertake a broad visual redesign unrelated to the evaluation journey.

### 5. Product-evaluation harness

Prepare a repeatable 15-minute evaluation using the fictional profile and,
optionally, a linked Mac.

Measure:

- time to explain why an application is active;
- whether the user can identify installation/source evidence;
- whether the user distinguishes observed facts from inference;
- whether the user understands rebuildable versus personal data;
- whether the map adds clarity after the narrative summary;
- where the user becomes lost or asks for terminology help.

Record product observations in a lightweight Markdown evaluation log. Do not
build Observation History or analytics for this purpose.

## Explicit non-goals

- Local Observation History
- SQLite or another history database
- Recursive size measurement
- Growth comparisons
- Cleanup execution
- New background sampling
- Notifications
- Privileged collection
- Endpoint Security
- Broad collector expansion
- Shared relationship/filesystem selection state

## Small implementation increments

1. Define the Application Story information architecture using existing fields.
2. Implement the story for the strongest synthetic fixture.
3. Apply it to linked applications with honest missing states.
4. Rework home entry points around user questions.
5. Add the optional guided walkthrough.
6. Polish transitions, typography, accessibility, and empty states.
7. Run the evaluation and revise once before expanding scope.

## Acceptance criteria

- A first-time user can select an application and summarize its identity,
  activity, origin evidence, startup behavior, and associated locations.
- The main explanation works without opening a map.
- The map provides useful supporting context rather than being required to
  decode the page.
- Unavailable and ambiguous facts are understandable.
- The fictional walkthrough can be completed without coaching.
- At least three representative evaluation sessions are recorded.
- The outcome produces a go, revise, or stop decision for the application-story
  thesis.

Implementation status:

- The user-facing experience, guided walkthrough, tests, and evaluation
  materials are implemented.
- The requirement for three representative sessions remains open because it
  requires participant observation rather than code.

## Decision after this phase

Choose the next investment based on observed demand:

- If users value application explanation, deepen application stories and
  installation provenance.
- If users value spatial location most, polish the Filesystem Map and path
  associations.
- If users value command-line ownership most, build a dedicated command-line
  explorer.
- If users repeatedly ask “what changed?”, reconsider Future Phase 6.
- If none is meaningfully clearer than existing tools, revise the product
  thesis before adding collectors.
