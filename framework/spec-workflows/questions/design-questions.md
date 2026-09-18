# Design Questions

*Last updated: 2026-09-16*

Two rounds share this list. **§ Project** runs once, at bootstrap, and
writes the project's `docs/architecture/profile.md`. **§ Spec** runs in a
spec's Design Decisions sub-step and asks only what the profile and the
ADRs leave open. Triggers, ordering and the `## Design` record:
[`spec-lifecycle.md § Design Decisions sub-step`](../spec-lifecycle.md#design-decisions-triggers).

## § Project — architecture profile (bootstrap)

Ask one question per profile row. Before asking, read what already
exists — ADRs under `docs/decisions/`, `docs/architecture/*`, lint and
make targets — and offer it as the proposed answer with its source.

### How to use

1. Ask every question; none is optional. "Not decided" is a valid
   answer and leaves the row `unrecorded` with its open question.
2. Fill `Stated style` only from the human's answer or a cited source —
   never from inference over the code alone.
3. Put the source in `Source`: an ADR path, a conventions section, or an
   enforcing check. An answer with no source becomes
   `convention — <where it will be written>` only when the human names
   that place; otherwise `unrecorded`.
4. Where two sources disagree, record both under `## Contradictions`
   and ask which one holds — do not pick.

### Questions (one per row)

1. **Architectural style:** Is this a monolith, a modular monolith,
   services, or a pipeline of steps? Where is that decided?
2. **Domain modelling:** Does the code model bounded contexts (DDD), a
   shared data model, or no explicit domain layer?
3. **Code organisation:** Is code grouped by technical layer, by
   vertical slice, or by feature folder? What enforces the boundary?
4. **Programming paradigm:** Is the core written object-oriented,
   functional, or procedural?
5. **Error model:** Do failures travel as exceptions, result types, or
   error values? Where are they translated at the boundary?
6. **Immutability:** Is state immutable by default, or mutable with
   guarded writes?
7. **Concurrency:** Is work concurrent through async/await, workers and
   queues, or not at all?
8. **Integration style:** Does the project talk to other systems through
   synchronous API calls, events or messages, or batch files?

## § Spec — design decisions (Specify sub-step)

Asked only when a trigger fires. Read `docs/architecture/profile.md` and
the ADRs first.

### How to use

1. **Ask at most 5 questions per spec.** Pick the ones the trigger
   raised; reorder so the most blocking come first.
2. **Never ask what a profile row or an accepted ADR already settles.**
   Cite the row instead. Ask about a settled item only to confirm a
   departure the spec itself proposes.
3. Profile row `unrecorded`? The question may be asked, and the answer
   is a candidate for the profile — note it under `### Open Questions`
   as a profile follow-up, not a spec requirement.
4. Record answers under `## Design § Decisions` — each decision with the
   alternatives considered and why each was rejected.

### Questions (ask ≤5)

1. **Approaches weighed:** Which two or three approaches could satisfy
   the requirements, and which one is chosen?
2. **Profile conformance:** Does the chosen approach follow every
   profile row it touches? If not, which row does it depart from, and
   why is the departure worth an ADR?
3. **Boundary placement:** Which bounded context owns the new behaviour
   or data, and which contexts only read it?
4. **Data-flow direction:** Which way does data move between contexts or
   services, and is the call synchronous or event-driven?
5. **Persistence shape:** What is the stored shape, and what must
   migrate or backfill when it changes?
6. **New dependency:** What does a new library, service or pattern buy
   that the existing stack cannot, and what is the exit cost?
7. **Main risk:** What is the most likely way this design fails, and
   what mitigates it?

## Anti-patterns

- **Do not** ask "DDD or monolith?" on a spec — that is a § Project
  question, answered once.
- **Do not** leave a question in `### Open Questions` whose answer
  would change a requirement, the approach or the task breakdown —
  ask it now.
- **Do not** record a decision without its rejected alternatives.
