# Authoring Steps — inline procedures

*Last updated: 2026-06-05*

The main agent runs these procedures **inline, in the same context** —
spec authoring, the Split check, and task decomposition are not delegated
to subagents (see [`agents/README.md`](../../../agents/README.md) for the
subagent-need gate). The workflow prompts
([`create-spec.prompt.md`](../../../prompts/create-spec.prompt.md),
[`plan-spec.prompt.md`](../../../prompts/plan-spec.prompt.md)) reference
the sections below.

These are *procedures*. Rules they obey are canonical elsewhere — link,
don't restate: lifecycle/gates → [`spec-lifecycle.md`](../../../spec-workflows/spec-lifecycle.md);
behavioural rules → [`boundaries.md`](../../../boundaries.md); split
trigger/exception tables → [`splitting-rules.md`](splitting-rules.md);
AC form → [`docs/acceptance-criteria-patterns.md`](../../../../docs/acceptance-criteria-patterns.md).

---

## A. Spec authoring (CR / IMP)

Run after the Specify question round (mandatory Q1+Q2 answered). Produces
the spec body through `## Out of Scope`; leaves `## Split Decision` for
§ B and `## Tasks` empty for Plan (§ C).

1. **Validate inputs.** `spec_type ∈ {CR, IMP}`; `title` matches `[a-z0-9-]+`; `date` is `YYYY-MM-DD`; mandatory Q1+Q2 answers non-empty. If two answers imply different scopes, STOP and surface the contradiction — do not draft. (RES → § D.)
2. **Locate template.** `<system>/spec-workflows/templates/<TYPE>-TEMPLATE.md`.
3. **Compose filename + path.** `<TYPE>-<YYYYMMDD>-<title>.md` under `<project_root>/docs/specs/active/`.
4. **Build front-matter** per [`spec-lifecycle.md § Front-matter schema`](../../../spec-workflows/spec-lifecycle.md). `status: specify`; `risk` default `low`, escalate to `medium` if scope crosses bounded contexts or schemas, `high` if it adds a bounded context; set `domain-refs:` from any baselines; leave `siblings:`/`depends-on:` to § B.
5. **Fill `## Summary`** — Goal (one sentence), Scope (one short paragraph), Out of scope (one sentence), from Q1.
6. **Fill `## Cost Estimate`** — token range, gate count, re-Specify tripwire conditions distilled from the answers.
7. **Fill the problem section** — Current State + Proposed Improvement (IMP) or Problem Statement (CR): what exists, why it needs change, concrete evidence. Keep prose tight; the FR/AC contract carries the weight.
8. **Fill `## Requirements`** — one FR per discrete capability, MUST per RFC 2119, numbered FR-1, FR-2, …
9. **Fill `## Acceptance Criteria`** — Given/When/Then, one AC per FR (or one per jointly-verified cluster), numbered AC-1, …
10. **Fill `## Out of Scope`** — explicit OS-1, OS-2, … from Q1's out-of-scope answer.
11. **Fill `## Architecture`** — `Skipped — <reason>`, or `Pending — Visualize sub-step` when a [Visualize trigger](../../../spec-workflows/spec-lifecycle.md#visualize-triggers) fires.
12. **Leave `## Split Decision`** as `Pending` until § B runs; **leave `## Tasks`** as `Pending — Plan stage only.` — never write rows here ([Rule #2](../../../spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify)).
13. **Write the file** atomically; set `*Last updated: <date>*` under the H1.

## B. Split check (Specify, mandatory)

Run on every CR / IMP / BUG after FRs+ACs, before the requirements gate
([Rule #9](../../../spec-workflows/spec-lifecycle.md#split-check-mandatory)).
Produces the `## Split Decision` block. You produce the recommendation;
the human decides at the gate.

1. **Cluster the FRs** — group by shared acceptance surface (same user action, output contract, or data entity); a lone FR is its own cluster.
2. **Evaluate triggers T1–T6** ([`splitting-rules.md § 2`](splitting-rules.md)). Record which fire and the signal source. T2 needs a module map; if absent, mark T2 `unknown`.
3. **Evaluate exceptions E1–E5** ([`splitting-rules.md § 4`](splitting-rules.md)). Record which apply.
4. **Decide** — no trigger → `keep-as-one` (`no-trigger`); trigger fires, no exception → `split-recommended` (smallest `T<N>`); trigger fires, exception applies → `keep-as-one` (dominant `E<N>`); trigger + ambiguous exception → STOP for a human decision.
5. **If split-recommended**, propose one sibling stub per independently-shippable cluster (kebab slug + one-line scope).
6. **Write `## Split Decision`** citing the driving trigger/exception ID(s) and a one-line reason.

> Edge cases: <3 FRs → too few to cluster meaningfully; note it and let the human decide. A trigger and exception firing ambiguously → STOP rather than reach the gate silently.

## C. Task decomposition (Plan)

Run at `status: plan` (requirements + ACs approved, Architecture filled,
Split Decision filled). Produces the `## Tasks` block. Apply the
Plan-stage safety net ([`splitting-rules.md § 3`](splitting-rules.md)).

1. **Verify prerequisites** — Requirements, Acceptance Criteria, Split Decision, Architecture all populated.
2. **Build the FR→AC map.**
3. **Cluster into vertical slices** — each owns ≥1 FR and ends at a verifiable AC/green build moment. A slice spanning >5 files is over-bundled — split it.
4. **Order by dependency** — earlier tasks produce what later tasks consume; scaffolding first, verification/closure last; aim for a near-linear chain.
5. **Per task, build the row** — Description (what/why + FR/AC numbers); Files (exact paths, ≤5, mark `*(new)*`); Source files (read-only, optional, uncapped); Depends on (earlier task IDs or `—`); Skills (subset of spec `skills:`); Model (`fast`/`default`/`deep` per [`docs/model-selection.md`](../../../../docs/model-selection.md), default `default`); Status `☐ pending`.
6. **Apply the safety net** — P1 (>12 tasks), P2 (>2 bounded contexts span the table with no shared AC; needs module map, else `unknown`), P3 (a task group with zero dependencies on others). If any fires, do NOT write the table — flip `status: plan → specify` and re-run the Split check.
7. **Format `## Tasks`** — first the line `> **Before starting Task <T1>, set status: in-progress in the front-matter above.**`, then the 8-column table: `| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |`.
8. **Refresh `## Cost Estimate`** so token range, gate count, and the re-Specify tripwire reflect the final task count + dependencies.

## D. Research authoring (RES)

RES uses a different template, front-matter, and body shape — most CR/IMP
sections are absent or auto-filled. Run after the exactly-5 RES question
answers ([`questions/res-questions.md`](../../../spec-workflows/questions/res-questions.md)).

1. **Validate** — all 5 answers non-empty; Q4 `code-location` outside any repo's `src/`; Q3 `kill-criteria` is exactly one shape (time-box OR token-budget OR iteration-count). STOP on any failure.
2. **Template + path** — `RES-TEMPLATE.md`; `RES-<YYYYMMDD>-<title>.md` under `docs/specs/active/`.
3. **Front-matter (RES schema)** — standard fields + `status: specify`, `model-suggestion: deep`, and RES-only `hypothesis:` (Q1), `kill-criteria:` (Q3), `code-location:` (Q4), `outcome:` (blank). Do **not** set `risk:`/`severity:`.
4. **Fill** `## Summary`, `## Hypothesis` (Q1, falsifiable), `## Kill Criteria` (Q3, explicit shape). Leave `## Iteration Log` empty (header rows only), `## Decision` and `## Outcome` as placeholders.
5. **`## Architecture`** — `Skipped — exploratory …` (or `Pending — Visualize sub-step` only if the spike tests an architecture proposal).
6. **`## Split Decision`** — auto-fill `Kept as one — RES iterative loop (per spec-lifecycle.md § RES exception)`; RES does not run § B.
7. **Leave `## Tasks`** as `Pending — Plan stage only.`; write the file atomically with the `*Last updated:*` stamp.

> RES is the only type that may loop `in-progress → specify`; every backflip lands an `## Iteration Log` row (date + cause + decision). The loop is managed at iteration time by the orchestrating prompt, not during this initial draft.
