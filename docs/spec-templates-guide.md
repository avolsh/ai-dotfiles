# Spec Templates Guide

*Last updated: 2026-06-17*

Companion to the slimmed spec templates at
[`framework/spec-workflows/templates/`](../framework/spec-workflows/templates/).
The templates carry only the structural skeleton needed to author a spec;
this guide documents the explainer content that previously lived inline
as HTML comments, organized by template section.

Read this guide once when you start authoring a new spec, or jump to a
section by anchor when you reach that part of the template. For
status / gate / schema rules, see
[`framework/spec-workflows/spec-lifecycle.md`](../framework/spec-workflows/spec-lifecycle.md);
this guide does not restate them.

---

## Front-matter optional fields

The slimmed templates list only the required front-matter fields. Three
optional fields are added when their trigger fires. Each is YAML-list
shaped and lives at the top level alongside the required fields.

### `domain-refs:`

Add when the spec touches existing baseline REQ-IDs. Two reference
styles are accepted and may be mixed:

```yaml
domain-refs:
  - REQ-PCE-005                                       # numeric ID from a baseline file
  - domain/place-catalog-enrichment.md#invariants     # path-anchor reference
```

Omit when the spec is net-new and no baseline exists yet. When omitted,
justify in one line inside the spec body (in `## Problem Statement`,
`## Bug Description`, or `## Current State` per spec type) — typically:
"net-new feature, no existing baseline REQ-IDs". See
[`baseline-citations.md`](baseline-citations.md) and
[`req-id-lifecycle.md`](req-id-lifecycle.md).

### `siblings:`

Add when the Specify-stage Split check (see
[`splitting-specs.md`](splitting-specs.md)) splits the work across
multiple sibling specs. List every sibling's spec ID, including the
current spec's siblings on the current spec.

```yaml
siblings:
  - IMP-20260513-slim-system-templates
  - IMP-20260513-slim-skill-bodies
```

Omit when the spec is autonomous (no split).

### `depends-on:`

Add when the spec MUST wait for a prerequisite spec to reach `done`
before it can advance from `specify` to `plan`. List the prerequisite
spec IDs.

```yaml
depends-on:
  - IMP-20260513-slim-framework-prompts
```

Per [`spec-lifecycle.md`](../framework/spec-workflows/spec-lifecycle.md)
§ Rules item 10, a spec with unmet `depends-on:` MUST stay at `specify`
until all listed prerequisites reach `done`.

---

### RES-only front-matter fields

When `type: RES`, four additional front-matter fields are required (see [`spec-lifecycle.md § RES exception`](../framework/spec-workflows/spec-lifecycle.md#res-exception) for the canonical contract). These fields are RES-only; the validator MUST NOT require them on CR/BUG/IMP.

```yaml
hypothesis: <One sentence. Concrete, falsifiable claim being tested.>
kill-criteria: <Single shape — time-box OR token-budget OR iteration-count. Mixing shapes is rejected by `make validate-specs`.>
code-location: research/<spec-id>/   # default; MUST be outside every repo's src/
outcome:                              # left blank at Specify; filled at status: done
                                      # one of: confirmed | refuted | inconclusive | promoted-to-<spec-id>
```

Constraints enforced by `scripts/validate-specs.py`:

| Field | Constraint |
|---|---|
| `hypothesis:` | non-empty string |
| `kill-criteria:` | matches exactly one shape (time-box: `hour`/`day`/`min`/`week`/`by YYYY-MM-DD`; token-budget: contains `token`; iteration-count: `backflip`/`iteration`/`round`/`loop`) |
| `code-location:` | no `src` path segment (e.g. `src/...`, `.../src/...` both rejected) |
| `outcome:` at `status: done` | in `{confirmed, refuted, inconclusive, promoted-to-<spec-id>}`; if `promoted-to-<id>` the referenced spec MUST exist in `docs/specs/active/` or `docs/specs/archived/` |

RES specs do NOT carry `risk:` or `severity:` — risk is bounded by `kill-criteria:` instead.

### `## Iteration Log` section (RES only)

RES specs add an `## Iteration Log` H2 section between `## Kill Criteria` and `## Decision`. Each `in-progress → specify` backflip MUST add one row before resuming `in-progress`:

```markdown
## Iteration Log

| # | Date | Cause | Decision |
|---|---|---|---|
| 1 | 2026-05-20 | Vector-search benchmark missed MRR@10 target on cold mix | Narrowed hypothesis: limit to high-traffic cities |
| 2 | 2026-05-21 | Cold-mix sample size too small (n=12) | Expand to n=200, re-run |
```

Row format:
- **#** — sequential index starting at 1
- **Date** — `YYYY-MM-DD` of the backflip
- **Cause** — one-line reason the loop returned to specify
- **Decision** — what changed in the spec on this iteration

The validator reports backflips without a corresponding row as drift (best-effort static check; see `scripts/validate-specs.py` for the current heuristic).

## `## Design` — Visualize trigger rules

The `## Design` section is filled during the Visualize sub-step
of Specify. Fill it when **any** of these apply:

- Risk is `medium` or `high` (CR / IMP only).
- The spec adds, removes, or reshapes a bounded context.
- The spec changes data flow between contexts or services.
- The spec changes a schema (database, type/interface definition, API
  contract).
- The spec adds a new pipeline step or modifies step ordering.
- The spec adds or changes a user-facing UI surface (screen, view,
  component).
- (IMP-specific) The refactor crosses bounded contexts or changes
  public module boundaries (barrel exports, ports).

If none apply, replace the section body with a single line:

```markdown
Skipped — <reason>
```

When filled, embed Mermaid diagrams (`flowchart`, `sequenceDiagram`,
`erDiagram`) for structure/flow/schema — under 30 nodes per diagram per
[`writing-docs.md`](writing-docs.md) § Core rules. For **UI surfaces**,
use Figma instead: link the frames (file key + node IDs) and embed
screenshots rather than drawing the visual design in Mermaid.

**BUG specs** usually skip Design. Fill it only if the fix
reveals an architectural issue (e.g., a boundary violation that must be
corrected as part of the fix). Otherwise leave the section as
`Skipped — isolated bug fix`.

Canonical lifecycle rule:
[`spec-lifecycle.md § Visualize sub-step`](../framework/spec-workflows/spec-lifecycle.md#visualize-sub-step-specify).

---

## `## Split Decision` — wording variants

Filled during the Specify-stage Split check, before the requirements
gate. Choose exactly one wording. Use the variant that matches the
outcome.

**Kept as one spec — explicit exception:**

```markdown
Kept as one spec — <E1|E2|E3|E4> <reason, referencing splitting-rules.md § 4>.
```

**Kept as one spec — no trigger matched:**

```markdown
Kept as one spec — no § 2 trigger matched.
```

**Split:**

```markdown
Split into: <sibling-id-1>, <sibling-id-2>. This spec owns FRs <N, M>.
```

For BUG specs, the equivalent multi-defect check uses:

```markdown
Single defect.
```

or

```markdown
Split into: <sibling-BUG-ids>. This spec owns the <defect-name> defect.
```

Canonical rules and triggers:
[`splitting-specs.md`](splitting-specs.md).

---

## `## Tasks` — placeholder rule

While `status: specify`, the section MUST hold exactly one placeholder
line:

```markdown
Pending — Plan stage only.
```

Do not draft tasks during Specify. When the spec moves to `plan`,
replace the placeholder with the approved task table per
[`spec-lifecycle.md`](../framework/spec-workflows/spec-lifecycle.md)
§ Rule 2. For BUG specs, Task 1 is always
`Reproduce & write failing test`.

---

## Non-spec closure artifacts — `archived/artifacts/`

`validate-specs` globs `docs/specs/{active,archived}/*.md` flat and
requires spec front-matter on every match. Non-spec markdown produced at
closure (baseline tables, narratives, captures) therefore MUST NOT live
directly in `archived/` — place it under `docs/specs/archived/artifacts/`
and link it from the owning spec's Closure Evidence.

---

## `## Agent instructions` content

The slimmed templates point at `<system>/boundaries.md` and
`<system>/docs/agent-protocol.md` rather than inlining the rules. The pointer expands to:

**Before each task — post in chat (mandatory before any edit):**

- Task # being implemented
- Precedent files read (paths)
- Loaded skill files (full `SKILL.md` paths — system or project scope)

**After each task — before proceeding:**

- Run build/test per project `AGENTS.md` § Build and Run.
- Post **"The Bottom Line"** using the canonical format in
  [`agent-protocol.md § The Bottom Line — canonical format`](agent-protocol.md#the-bottom-line--canonical-format)
  and wait for explicit human approval.
- Update the task row's Status column in the spec.

Per-spec overrides of these rules are not supported. If a spec needs to
add task-local guidance, attach it to the relevant task row's
description or to a dedicated body section, not to `## Agent
instructions`.

---

## Why this guide exists

Templates used to inline ~30 lines of HTML-comment explainers per file
(60–80 lines across the three templates) plus a duplicated
`## Agent instructions` block. The comments lived nowhere else canonical,
which made them load-bearing — but they pushed every authored spec to
inherit a noisy template baseline. Per
[`IMP-20260513-slim-spec-templates`](specs/archived/IMP-20260513-slim-spec-templates.md),
the explainers moved here so authored specs start from a small
skeleton and reach for the guide only when a section is non-obvious.
