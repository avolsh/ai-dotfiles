---
id: RES-20260914-declarative-lifecycle-schema
type: RES
date: 2026-09-14
status: done
closed: 2026-09-17
owner: alexvolsh
affected-repos:
  - ai-dotfiles
affected-docs: []
affected-code: []
skills:
  - writing-specs
model-suggestion: deep
hypothesis: A declarative lifecycle.yaml plus a small generic engine can express at least 15 of the validator's 22 checks and every template's required-section rules, reproducing the current findings on both spec corpora and on the validate-specs test fixtures exactly, in fewer lines than the checks it replaces.
kill-criteria: ≤8 hours
code-location: research/RES-20260914-declarative-lifecycle-schema/
outcome: confirmed
depends-on:
  - IMP-20260914-spec-traceability-checks
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-baseline-deltas-and-merge
  - IMP-20260914-machine-readable-spec-reports
---

# RES-20260914-declarative-lifecycle-schema

*Last updated: 2026-09-17*

## Summary

- **Goal:** Find out whether the lifecycle's rules can live in one declarative file that the validator, the
  templates and a future `spec-next` command all read, instead of being restated across prose, templates and
  2 020 lines of Python (`scripts/validate-specs.py`, plus shared readers in `scripts/speclib.py`).
- **Scope:** A sandbox prototype — `lifecycle.yaml` covering types, statuses, lanes, required sections per status,
  front-matter schema and relations — and an engine that runs it against the `ai-dotfiles` and `tobevisit-content`
  corpora and the `scripts/test/validate-specs.test.sh` fixtures, compared finding-for-finding with
  `validate-specs.py`.
- **Out of scope:** Replacing `validate-specs.py`, changing any rule, or touching `framework/`.

## Hypothesis

A declarative `lifecycle.yaml` plus a generic engine expresses ≥15 of the 22 checks and all required-section rules,
reproduces current findings exactly on both corpora and on the validator's test fixtures, and totals fewer lines than
the checks it replaces. Checks that need bespoke logic (English-only, Figma frame IDs, inventory overlap, review
disposition, baseline deltas) are expected to remain code plug-ins; how many do is the measurement.

The 22 checks are the 17 in `CHECK_REGISTRY` plus the five run outside it: agent front-matter, domain REQ-IDs,
baseline freshness, log `Closed`, baseline deltas. The ≥15 bar keeps the original two-thirds ratio (10 of 15), set
when the validator had 15.

Parity on the live corpora alone is weak: at 2026-09-16 `ai-dotfiles` yields 0 findings and `tobevisit-content` 3
(`deps_dangling`, `english_only`, `link_broken`), so an engine that reports nothing nearly passes. The fixture suite
supplies the violating inputs; parity is counted on both.

"Lines replaced" is the check functions plus their private helpers in `validate-specs.py`, measured when the sandbox
is set up; the shared `speclib.py` readers are reused by both sides and excluded.

## Kill Criteria

time-box: ≤8 hours of agent work, counted across iterations.

## Iteration Log

| # | Date | Cause | Decision |
|---|---|---|---|
| (rows added on each `in-progress → specify` backflip; initial entry blank) | | | |

## Decision

The loop ran once, without a backflip, so the one `specify → in-progress` was the final one. It went ahead on the
refined hypothesis (22 checks, parity also against the validator's fixtures). T1 found that the self-tests never
trigger 26 of the ids, so T2 added mutation fixtures before any rule was declared. Without them, parity for the most
schema-like checks would have proved nothing.

Result: the hypothesis holds as written, with two costs it did not anticipate. First, the line saving is a density
effect: the schema is smaller in lines and bigger in characters. Second, the schema is only data for front-matter,
statuses, lanes and sections. For traceability, links and overlap it is a program written in YAML. The value is in
the first part. That part is what `IMP-20260914-spec-next-instructions` needs, and it is where prose and code already
disagree (§ Outcome, drift 1–2). Recommendation: productionise the vocabulary (types, statuses, lanes, required
sections, front-matter schema) as the single source, and keep algorithmic checks in Python reading it.

## Outcome

`confirmed` — approved by the owner at the closure gate, 2026-09-17. Full record: `research/RES-20260914-declarative-lifecycle-schema/README.md` § Final result.
Expected shapes: `confirmed` → sibling IMP productionises the schema and `IMP-20260914-spec-next-instructions` reads
it; `refuted` → `spec-next` reads canonical-doc anchors instead; `inconclusive` → record which checks resisted and why.

- **Checks.** 16 of 22 declarative (43 rules), 6 plug-ins (`english_only`, `figma_frame_id`, `review_disposition`,
  `baseline_freshness`, `log_closed`, `baseline_deltas`), 0 not expressible. Strict reading: 12. Four declarative
  checks rely on an op that only one rule uses and that reads structure in Python (`cycles`, `section_has_table`,
  `table_rows`, `req_duplicates`).
- **Parity.** Exact, messages included. Corpora: 3/3 findings. Validator self-tests: 93/93 across 71 invocations.
  Mutation and edge fixtures: 89/89 across 42 projects. 0 missing, 0 extra, 0 message drift.
- **Size.** 834 code lines replaced vs 560 for schema + engine (−33 %), or 649 with the stdlib YAML loader (−22 %).
  In characters: 20 081 vs 25 942 (+29 %), or 28 524 with the loader (+42 %).
- **Vocabulary.** 55 ops; 18 used once. `not`, `all`, `eq` and `in` carry most rules.
- **Required sections.** Expressed per type and status (advisory; the validator has no section check). They flag 19
  specs in ai-dotfiles and 38 in tobevisit-content, mostly `## Closure Evidence` missing under older headings.
  Enforcing them needs a date cut-off.
- **Rules stated differently in prose and code (7).**
  1. `## Closure Evidence` is read by two checks but is absent from all four templates.
  2. "RES MUST NOT elect `risk: trivial`" is not enforced; verified on the validator.
  3. The Tasks-table status check is not fence-aware, while every other section reader skips fences.
  4. There are two `Last updated` grammars.
  5. Rule #10 does not cover a `done` spec with unmet `depends-on`; verified on the validator.
  6. RES has no `plan`, so its Tasks table can only land with the `in-progress` flip.
  7. The `code-location` check is stricter than the prose.
- **Time.** About 5 of 8 hours, estimated rather than clocked.

## Design

Skipped — exploratory; architecture decisions deferred to a promoted IMP if applicable.

## Split Decision

Kept as one — RES iterative loop (per spec-lifecycle.md § RES exception).

## Tasks

> **Before starting Task T1, set status: in-progress in the front-matter above.**

Time-box started 2026-09-16. Paths are relative to the workspace root; `validate-specs.py` is only read, never edited.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Sandbox + parity harness: a shim that runs `validate-specs.py` and the engine on the same input and logs finding-set differences, a runner over both corpora and the fixture suite (run through the shim), and the lines-replaced baseline | `research/RES-20260914-declarative-lifecycle-schema/README.md` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/shim.py` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/parity.sh` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/measure_lines.py` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/engine.py` *(new, empty engine)* | `env/ai-dotfiles/scripts/validate-specs.py`, `env/ai-dotfiles/scripts/speclib.py`, `env/ai-dotfiles/scripts/test/validate-specs.test.sh` | — | writing-specs | default | ☑ done |
| T2 | Mutation fixtures for the 26 finding ids the self-tests never trigger (T1 finding), then schema v0 — front-matter fields, enums, types, statuses, lanes, status/location invariants, naming and filename–id parity; engine interprets them | `research/RES-20260914-declarative-lifecycle-schema/fixtures.sh` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/parity.sh`, `research/RES-20260914-declarative-lifecycle-schema/lifecycle.yaml` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/yamlite.py` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/engine.py` | `env/ai-dotfiles/framework/spec-workflows/spec-lifecycle.md`, `env/ai-dotfiles/framework/spec-workflows/spec-types.md` | T1 | writing-specs | deep | ☑ done |
| T3 | Required-section rules per type and status, read from the four templates; freshness | `research/RES-20260914-declarative-lifecycle-schema/lifecycle.yaml`, `research/RES-20260914-declarative-lifecycle-schema/engine.py` | `env/ai-dotfiles/framework/spec-workflows/templates/` | T2 | writing-specs | deep | ☑ done |
| T4 | Relations — depends-on / siblings graph, promotion targets, link integrity | `research/RES-20260914-declarative-lifecycle-schema/lifecycle.yaml`, `research/RES-20260914-declarative-lifecycle-schema/engine.py` | `env/ai-dotfiles/scripts/validate-specs.py` | T2 | writing-specs | deep | ☑ done |
| T5 | Wire every remaining check as a plug-in; full parity run on both corpora and all fixtures (plug-ins are declared in `lifecycle.yaml` and loaded by the engine — no separate `plugins.py`) | `research/RES-20260914-declarative-lifecycle-schema/lifecycle.yaml`, `research/RES-20260914-declarative-lifecycle-schema/engine.py`, `research/RES-20260914-declarative-lifecycle-schema/fixtures.sh` | `env/ai-dotfiles/scripts/validate-specs.py` | T3, T4 | writing-specs | default | ☑ done |
| T6 | Record measurements, prose-vs-code rule drift, Decision and Outcome | `env/ai-dotfiles/docs/specs/archived/RES-20260914-declarative-lifecycle-schema.md` *(moved from active/ at closure)*, `research/RES-20260914-declarative-lifecycle-schema/README.md`, `research/RES-20260914-declarative-lifecycle-schema/measure_result.py` *(new)* | `research/RES-20260914-declarative-lifecycle-schema/` | T5 | writing-specs | default | ☑ done |

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Every `in-progress → specify` backflip MUST add
an `## Iteration Log` row before resuming.

## Docs updates required

- None during the loop.

## Rollout / migration notes

- Waited for every other spec changing `scripts/validate-specs.py` in this batch, so the schema describes stable
  rules rather than a moving target. All five `depends-on` IMPs are `done` (checked 2026-09-16); the counts above
  were re-measured against the validator they left behind.
- Sandbox path `research/RES-20260914-declarative-lifecycle-schema/` is the only place code lives; nothing merges
  into `scripts/` without a promoted sibling IMP reaching `done`.
