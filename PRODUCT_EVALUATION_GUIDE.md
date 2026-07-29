# HAL Application Story Evaluation Guide

Status: ready for moderated product evaluation  
Duration: approximately 15 minutes  
Build: record the tested commit in each session log

## Purpose

Test whether HAL explains one application more clearly than a raw inventory,
Activity Monitor, Finder, or several disconnected system panels.

This is a product evaluation, not a feature demonstration. Avoid teaching HAL's
terminology before the participant encounters it.

## Participant setup

- Prefer a person who did not implement the current interface.
- Start with the fictional profile.
- Confirm the participant understands that the data is fictional.
- Use a linked Mac only after the fictional journey, and only with explicit
  consent.
- Do not enable new permissions or change machine state.

## Tasks

### 1. Choose a question

Ask:

> Looking at the home screen, where would you start if you wanted to understand
> an application you do not recognize?

Record whether the participant chooses a task-oriented entry without coaching.

### 2. Explain one application

Ask the participant to open Visual Studio Code and answer:

- What is it?
- Does HAL show it as active?
- What evidence explains that activity?
- Where does HAL think it came from?
- Does anything start it automatically?
- What files, packages, or tools does HAL associate with it?
- What does HAL explicitly not know?

Do not prompt them to open a map.

### 3. Inspect supporting evidence

Ask:

> If you wanted to verify one of those claims, where would you go?

Observe whether the Relationship Map, inspector, confidence, and evidence feel
like supporting context.

### 4. Understand location

Ask the participant to use the Filesystem Map and explain:

- where the selected software or associated data lives;
- whether HAL enumerated the location; and
- the difference between “not enumerated” and “empty.”

### 5. Distinguish data safety

Ask:

> Which observed data appears rebuildable, and does HAL say it is safe to
> delete now?

The expected answer is that rebuildability is explained separately and no
deletion is authorized.

### 6. Try the guided tour

Ask the participant to replay the two-minute fictional tour and note whether it
clarifies or repeats what they already understood.

## Measures

Record:

- seconds to choose the application-understanding entry point;
- seconds to produce a correct application summary;
- whether observed facts and inference were distinguished;
- whether origin evidence was found;
- whether current activity and startup behavior were distinguished;
- whether support data and rebuildable data were distinguished;
- whether maps added clarity;
- every place the participant became lost;
- every term that required explanation; and
- the participant's one-sentence description of HAL.

## Decision rubric

### Go

At least two of three participants can explain the application story without
coaching, and the maps add useful verification or location context.

### Revise

Participants understand the promise but repeatedly miss the same section,
state, transition, or term. Revise that journey before adding collectors.

### Stop or rethink

Participants cannot articulate an advantage over existing tools, or the
relationship model creates more work than it removes.

## Session records

Copy `PRODUCT_EVALUATION_SESSION_TEMPLATE.md` for each session. Use anonymous
identifiers and do not record private machine paths, usernames, application
lists, or screen recordings without explicit consent.
