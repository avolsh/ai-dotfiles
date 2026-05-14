# Baseline Citations

*Last updated: 2026-05-14*

How to read, write, and cite **per-feature requirements baselines** under `<project>/docs/requirements/`: file structure, ID convention, verification pointers, citation format, current-state authority, ownership, and anti-patterns.

Origin spec:
`tobevisit-content/docs/specs/archived/IMP-20260428-requirements-baseline-for-specify.md`.

---

## What a baseline is

One Markdown file per **logical small feature** — finer than a bounded
context, broader than a single pipeline step. Captures the "what the
system must do today" layer that complements `docs/architecture/` (how
it's built) and `docs/reference/` (data shapes).

Baselines are **lazy-fill**: a feature gets a baseline file when a CR
or IMP first touches it, not by retroactive backfill.

---

## File structure

Required parts, in this order:

1. Header info table before the first `##` section.
2. `## Why`
3. `## Functional Requirements`
4. `## Invariants`
5. `## Non-Functional Requirements`
6. `## Out of Scope`
7. `## Source References`

The header info table MUST include these rows: `Owns`,
`Pipeline step`, `Bounded context(s)`, `ID prefix`,
`Originating spec(s)`, `Source files read`, `Source docs read`,
`Depends on baselines`, and `Last src verified`.

`## Why` captures the user need, business decision, or constraint that
motivates the feature. Keep it to one paragraph and cite the source
documents in `## Source References`.

Every entry in the four content sections begins with an RFC 2119
keyword: `MUST`, `MUST NOT`, `SHOULD`, `MAY`. Every entry is
addressable by a heading slug or an explicit ID.

Seed example:
[`tobevisit-content/docs/requirements/place-catalog-enrichment.md`](../../../src/github.com/tobeverse/tobevisit-content/docs/requirements/place-catalog-enrichment.md).

---

## Optional ID Convention

Format: `REQ-<feature-prefix>-NNN` (e.g., `REQ-PCE-005`).

- Prefix derives from the feature, not the bounded context (`PCE` =
  Place Catalog Enrichment).
- Unique within the file.
- Optional per entry. A heading slug (`#functional-requirements`) is a
  valid anchor on its own.

Use IDs when the feature is referenced often by other specs; skip them
for one-off baselines.

Lifecycle rules for numbering, deletion, supersession, and
cross-baseline citation live in
[`req-id-lifecycle.md`](req-id-lifecycle.md). In short: continue from
`max(existing) + 1`, do not fill gaps, tombstone deleted IDs, do not
reuse IDs, and record supersession inline with a `Why` note.

---

## Optional Verification Pointers

FR and Invariant entries MAY end with an optional test pointer:

```markdown
- REQ-PCE-005 MUST copy provider coordinates into the catalog place. *(Verified by: src/contexts/place-content-generation/application/__tests__/enrich-place-catalog.use-case.test.ts)*
```

Existing baselines MAY omit `Verified by:` entries. Future baselines and
baselines updated under
[`spec-lifecycle.md` Rule 11](../framework/spec-workflows/spec-lifecycle.md)
SHOULD include the suffix when a real test exists. Authors MUST omit the
suffix rather than inventing a test path when no test exists.

---

## Citation format

In a CR/IMP/BUG front-matter:

```yaml
cites-reqs:
  - REQ-PCE-005                                            # numeric ID
  - requirements/place-catalog-enrichment.md#invariants    # path-anchor
```

Both forms are accepted; mix freely.

When the spec is **net-new** (no existing baseline applies), omit the
field and add a one-line justification in `Problem Statement` /
`Current State` / `Bug Description`. Typical wording: *"net-new
feature, no existing baseline REQ-IDs"*.

---

## Current-state authority

Requirements baselines are authoritative current-state documents.
At closure, any changed baseline MUST describe the system after the
spec's changes are applied -- not desired future behaviour. Future
CR/IMP/BUG Specify stages treat cited baselines as the starting point
for new requirements unless the agent finds a concrete drift between
baseline text and `src`.

When a closing spec updates a baseline, it MUST also bump the
`Last src verified` row in the header info table to the closure date,
even when the baseline body is unchanged after re-checking `src`.

---

## Ownership

| When | Who | What |
|---|---|---|
| Specify stage | Spec author | Read the relevant baseline (Step 1 of `create-spec.prompt.md`); cite the touched REQ-IDs in `cites-reqs:`; ask the situational REQ-touch question. |
| Closure | Spec author | If the spec changed baseline behavior, update the touched `docs/requirements/<feature>.md` in the same change; cite the diff in `## Closure Evidence`. May seed a brand-new baseline file when introducing a feature that will likely be touched again. |

The closure rule is enforced by:
[`spec-lifecycle.md` Rule 11](../framework/spec-workflows/spec-lifecycle.md)
(workspace) and each project's `.github/copilot/instructions/general.md`
(project boundary).

---

## Anti-patterns

- **Bulk backfill without rationale capture** — produces stale,
  low-confidence text. When backfill is necessary (e.g., to seed an
  existing system per
  `IMP-20260429-requirements-baseline-backfill`), the extended
  template's `## Why` section, `## Source References` footer, and the
  rationale-gap escalation rule MUST be honoured to prevent the
  staleness this anti-pattern targets.
- **Skipping `## Why` because the rationale feels self-evident from
  src** — src answers *how*, not *why*. The Why section is
  non-optional.
- **One baseline per bounded context** — too coarse; multiple unrelated
  features end up entangled.
- **One baseline per pipeline step** — too fine; cross-step features
  lose their natural home.
- **Citing without changing** — if the spec doesn't actually touch a
  REQ-ID, leave it out of `cites-reqs:`.
- **Restating code in the baseline** — capture *behaviour rules*, not
  type definitions or data shapes (those belong in `docs/reference/`).
