# ADR Conventions

*Last updated: 2026-09-16*

Naming convention, status values, and minimal template for Architecture Decision Records. Consulted only when an ADR is being authored or amended.

---

## Location & naming

```
docs/decisions/
    ADR-NNNN-<kebab-case-title>.md
```

- `NNNN`: zero-padded sequential number.
- Title: lowercase, hyphen-separated, max 50 characters.

## Status values

`proposed` → `accepted` | `rejected` | `superseded`

Superseded ADRs must link to the replacement ADR.

## When a spec must write one

A spec whose Design Decisions sub-step records a decision that **departs from a row of
`docs/architecture/profile.md`** or **sets a new project-wide convention** links a `proposed` ADR from that
decision's bullet under `## Design § Decisions` before the requirements gate is requested. The ADR's
`## Alternatives Considered` carries the same rejected alternatives. When the spec closes, the ADR becomes `accepted`
and the profile row cites it; a rejected spec leaves the ADR `rejected`. Rule:
[`spec-lifecycle.md § Design Decisions sub-step`](../framework/spec-workflows/spec-lifecycle.md#design-departure-adr).

A decision inside the profile's existing style needs no ADR — the spec's `### Decisions` bullet is the record.

## Template

```markdown
# ADR-NNNN: <title>

- Date: YYYY-MM-DD
- Status: proposed | accepted | rejected | superseded

## Context
Why is a decision needed?

## Decision
What was decided.

## Alternatives Considered
- Alternative A — why rejected.
- Alternative B — why rejected.

## Consequences
What follows from the decision.
```
