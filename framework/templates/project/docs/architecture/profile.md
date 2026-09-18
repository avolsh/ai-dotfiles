# Architecture Profile

*Last updated: YYYY-MM-DD*

How <project-name> is built, stated once. A spec's Design Decisions sub-step
reads this page and never re-asks what it settles; a spec that departs from
it links a proposed ADR. Rules:
`<system>/spec-workflows/spec-lifecycle.md` § Design Decisions sub-step.

---

## Components

<!-- One row per component: a directory with its own build. Most repositories have one row with Path `.`.
     Style and Stack name framework documents: `$AI_DOTFILES/docs/styles/<style>.md` and
     `$AI_DOTFILES/docs/stacks/<stack>.md`. This table is the single source of what each component uses. -->

| Path | Stack | Style | Purpose |
|---|---|---|---|
| `.` | <stack, e.g. nextjs> | <style, e.g. ddd-layered> | <one line> |

## Profile

<!-- Compose this table per component: copy the rows the named style settles (its § Architecture Profile
     rows), then the rows the stack binding settles, then fill the remaining rows and every `<…>` placeholder
     from project facts. With several components, prefix a row's Stated style with the component path
     where they differ. -->

<!-- One row per item; never delete a row. Fill at bootstrap from
     `<system>/spec-workflows/questions/design-questions.md` § Project.
     Source: an ADR (`docs/decisions/ADR-NNNN-…md`), a conventions section
     (`docs/architecture/code-conventions.md § …`) or an enforcing check
     (lint rule, make target). A row with no source stays `unrecorded` and
     states its open question — never fill a row from inference alone. -->

| Item | Stated style | Source | Open question |
|---|---|---|---|
| Architectural style | — | unrecorded | Monolith, modular monolith, services, or pipeline? |
| Domain modelling | — | unrecorded | DDD bounded contexts, anemic model, or none? |
| Code organisation | — | unrecorded | Layers, vertical slices, or feature folders? |
| Programming paradigm | — | unrecorded | Object-oriented, functional, or procedural core? |
| Error model | — | unrecorded | Exceptions, result types, or error values? |
| Immutability | — | unrecorded | Immutable by default, or mutable with guarded writes? |
| Concurrency | — | unrecorded | Async/await, workers and queues, or single-threaded? |
| Integration style | — | unrecorded | Sync API calls, events/messages, or batch files? |

| Check | Value |
|---|---|
| Last src verified | YYYY-MM-DD — <what was read in src/> |

## Contradictions

<!-- Sources that disagree with each other or with src/. List them; never
     resolve one silently. Write "None found." when the check turned up none. -->

- <source A> says <X>; <source B / src path> shows <Y>.
