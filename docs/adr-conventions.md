# ADR Conventions

*Last updated: 2026-05-14*

Naming convention, status values, and minimal template for Architecture Decision Records. Consulted only when an ADR is being authored or amended.

---

## Location & naming

```
docs/adr/
    ADR-NNNN-<kebab-case-title>.md
```

- `NNNN`: zero-padded sequential number.
- Title: lowercase, hyphen-separated, max 50 characters.

## Status values

`proposed` → `accepted` | `rejected` | `superseded`

Superseded ADRs must link to the replacement ADR.

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
