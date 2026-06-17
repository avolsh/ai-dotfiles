---
id: RES-YYYYMMDD-<kebab-case-title>
type: RES
date: YYYY-MM-DD
status: specify
owner: <github-handle>
affected-repos:
  - <repo-name>
affected-docs: []                          # typically empty for RES; populate if the spike will edit existing docs
affected-code: []                          # typically empty for RES (code lives in research/<spec-id>/, not src/); populate only for docs/scripts the spike formally edits
skills:
  - writing-specs
  - <project-skill>
model-suggestion: deep
hypothesis: <One sentence describing what is being tested.>
kill-criteria: <time-box e.g. "≤8 hours" OR token-budget e.g. "≤200k tokens" OR iteration-count e.g. "≤3 backflips">
code-location: research/<spec-id>/
outcome:                                  # filled at `status: done`; one of: confirmed | refuted | inconclusive | promoted-to-<spec-id>
# Optional fields (domain-refs, siblings) — see docs/spec-templates-guide.md § Front-matter optional fields.
# RES specs MUST NOT elect `risk: trivial` — the Trivial lane is one-shot,
# incompatible with the iterative loop. See spec-types.md § Trivial lane.
---
<!--
RES type — iterative research / spike / POC / vibe-coding lane.
Lifecycle: specify ⇄ in-progress → done (the loop is the lane's defining feature).
Each `in-progress → specify` backflip MUST add a row to ## Iteration Log.
Full lifecycle rules, sandbox constraints, and outcome enum:
  framework/spec-workflows/spec-lifecycle.md#res-exception
Code in research/<spec-id>/ MUST NOT merge into src/ without an explicit
`outcome: promoted-to-<spec-id>` referencing a `done` sibling CR/IMP.
-->
# RES-YYYYMMDD-<title>
*Last updated: YYYY-MM-DD*
## Summary
- **Goal:** <One sentence — what question we are answering.>
- **Scope:** <One short paragraph — what is in / out for THIS round.>
- **Out of scope:** <One sentence — what NOT to investigate.>
## Hypothesis
<The single concrete claim being tested. Refine on each backflip; original
hypothesis stays here, refinements go in `## Iteration Log` and the most
recent version restates the final hypothesis.>
## Kill Criteria
<When to stop iterating regardless of result. Must match one of:
  - time-box: "≤N hours" / "by YYYY-MM-DD"
  - token-budget: "≤N tokens" (counting agent + sub-agent context)
  - iteration-count: "≤N backflips through specify"
Choose ONE shape; mixing makes the criteria unenforceable.>
## Iteration Log

| # | Date | Cause | Decision |
|---|---|---|---|
| (rows added on each `in-progress → specify` backflip; initial entry blank) |

Row format:
- **#** — sequential iteration index starting at 1
- **Date** — YYYY-MM-DD of the backflip
- **Cause** — one-line reason the loop returned to specify (new evidence,
  refuted assumption, scope shift, kill-criteria approached)
- **Decision** — what changed in the spec on this iteration (refined
  hypothesis, narrowed scope, swapped technology, etc.)
## Decision
<Filled at the FINAL `specify → in-progress` (the one that leads to `done`).
One paragraph describing the conclusion reached and the basis for it
(evidence, measurements, qualitative findings). Cite specific Iteration
Log entries if the conclusion depended on a particular pivot.>
## Outcome
<Filled at `status: done`. Choose exactly one:

- **confirmed** — hypothesis verified. Code in `research/<spec-id>/` stays
  as reference. Sibling CR/IMP MAY be opened to productionize, but is
  NOT required.
- **refuted** — hypothesis disproven. Document the negative result here
  for future searchability.
- **inconclusive** — kill-criteria reached without a definitive answer.
  Document what would resolve the question (more data, different setup,
  longer time-box).
- **promoted-to-<spec-id>** — productionize via a sibling CR/IMP that
  carries the real implementation. The referenced spec MUST exist
  (validator-enforced). Throwaway code in `research/<spec-id>/` MUST NOT
  be merged into `src/` without this promotion + the sibling being `done`.>
## Design
<Fill during Visualize when triggered, else `Skipped — exploratory; architecture decisions deferred to promoted CR/IMP if applicable`.>
## Split Decision
<Fill during Specify. RES specs typically stay as one because the loop
mechanic itself absorbs scope changes — splitting a RES mid-loop is
usually wrong. See docs/spec-templates-guide.md § Split Decision.>
## Tasks
Pending — Plan stage only. Tasks for RES specs are typically light
("set up sandbox", "run experiment N", "record findings"); the heavy
lifting is in the loop itself, not the task list.
## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. RES specs additionally
honor the `## Iteration Log` mandate from
[`spec-lifecycle.md § RES exception`](../spec-lifecycle.md#res-exception):
every `in-progress → specify` backflip MUST add a row before resuming
in-progress.
## Docs updates required
- <path> — <what changes, if any>
## Rollout / migration notes
- Sandbox path `research/<spec-id>/` is the ONLY place code may live
  during the loop. `.gitignore` covers `research/*/.tmp/` for transient
  artifacts (notebook checkpoints, dataset dumps).
- Promotion to production requires a sibling CR/IMP — never merge
  research code directly to `src/`.
