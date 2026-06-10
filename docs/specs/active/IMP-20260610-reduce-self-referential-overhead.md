---
id: IMP-20260610-reduce-self-referential-overhead
type: IMP
date: 2026-06-10
status: in-progress
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/rule-canonical-map.md
  - docs/agent-protocol.md
  - framework/boundaries.md
  - docs/writing-specs.md
  - docs/writing-docs.md
  - docs/model-selection.md
  - docs/splitting-specs.md
  - docs/spec-workflow-guide.md
affected-code:
  - scripts/validate-anchors.py (new)
  - scripts/lint-rules.py
  - Makefile
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
---
# IMP-20260610-reduce-self-referential-overhead
*Last updated: 2026-06-10*
## Summary
- **Goal:** Cut the framework's self-maintenance surface — the hand-kept rule
  map, multi-hop rule chains, and duplicated `docs/` ↔ `framework/skills/`
  content — by moving enforcement into scripts and collapsing each topic to a
  single content source.
- **Scope:** Framework meta-docs and validation scripts in `ai-dotfiles` only:
  disposition of `docs/rule-canonical-map.md`, mechanical anchor validation,
  a documented one-hop reachability rule for mandatory rules (plus an audit of
  existing chains), and deduplication of overlapping `docs/<topic>.md` /
  `framework/skills/<topic>/SKILL.md` pairs (one source + one-line pointer).
- **Out of scope:** Changing any rule's meaning; renaming `.github/copilot/*`
  catalog directories; CI wiring beyond the existing local script entry points;
  downstream project adoption.
## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 150k-300k |
| Human attention | 3 gates: requirements, plan, closure; ~10 min/gate |
| Re-Specify tripwire | Any FR requires changing a rule's meaning (not its location), or the plan grows past 6 tasks |
## Current State
Three sources of self-referential overhead exist today:

1. `docs/rule-canonical-map.md` is a hand-maintained inventory (R1-R10) of
   canonical rule homes and their linking sites, produced during
   IMP-20260514-dedup-rule-statements. Its phrase inventory IS mechanically
   consumed — `scripts/lint-rules.py` greps for verbatim duplicates in
   `make check` — but two gaps remain: (a) nothing verifies that anchors
   referenced by links actually exist, so a renamed anchor breaks silently;
   (b) the file mixes the machine-read inventory with one-off audit
   narrative that nobody consumes but everybody must scroll past and keep
   in sync.
2. Some mandatory rules are reachable only via two link hops from the files an
   agent actually loads (e.g. `boundaries.md` → `spec-lifecycle.md` →
   `splitting-rules.md § 5`). Agents drift when rules sit behind chained links.
3. Several topics exist both as a human-facing doc and an agent-facing skill
   (e.g. `docs/writing-specs.md` ↔ `framework/skills/writing-specs/SKILL.md`,
   `docs/writing-docs.md` ↔ `framework/skills/writing-docs/SKILL.md`,
   `docs/model-selection.md` ↔ `framework/skills/model-selection/SKILL.md`).
   Every paragraph duplicated across the pair is a future drift site.
## Proposed Improvement
Move what can be checked into scripts; archive what was a one-off working
artifact; collapse duplicated content to one source per topic; and state a
one-hop reachability rule so future framework edits keep mandatory rules close
to the files agents load. **Measurable benefit:** anchor validation goes from
0 mechanical checks to 1 script run in the standard check entry point;
duplicated rule/topic statements across `docs/` ↔ `skills/` pairs go from
current count (baseline measured in Task 1) to 0; mandatory rules reachable
only via ≥2 hops go from current count to 0.
## Requirements
- FR-1: A validation script MUST verify that every `<a id=...>` anchor
  referenced from framework files and `docs/rule-canonical-map.md` (if kept)
  resolves to an existing anchor, failing with file:line on breakage, and MUST
  be runnable via the same entry point as `check-md-links.sh`.
- FR-2: `docs/rule-canonical-map.md` MUST be split: the narrative parts
  (audit findings, action-item notes, resolution history) are archived as a
  closed working artifact of IMP-20260514-dedup-rule-statements; the
  machine-consumed inventory (rule id → canonical file → anchor → observed
  phrases) remains live as the data file of `scripts/lint-rules.py`, slimmed
  to that minimum and headed by a "machine-read by lint-rules.py — not
  human-maintained prose" label. `make check` MUST stay green throughout.
  *(Amended 2026-06-10 during Plan-stage discovery: the original "archive
  outright" decision assumed the map was unconsumed; `lint-rules.py` reads it
  in `make check` / `sync-agents-check`, so outright archiving would break
  the linter. Amendment approved by owner before the `specify → plan` flip.)*
- FR-3: Every rule marked MUST/Never/Always in `framework/boundaries.md` and
  `framework/spec-workflows/spec-lifecycle.md` MUST be reachable in ≤1 link
  hop from one of those two files; existing ≥2-hop chains are inlined or
  re-homed, and the one-hop convention is documented in
  `docs/agent-protocol.md`.
- FR-4: For **every** overlapping `docs/<topic>.md` ↔
  `framework/skills/<topic>/SKILL.md` pair (full inventory taken in Task 1),
  the **skill MUST own the agent-facing content** (skills are what agents
  load during tasks); the doc MUST shrink to a one-line pointer plus any
  human-facing rationale that has no place in a SKILL.md, or be deleted, with
  inbound links updated. *(Ownership direction chosen by owner during the
  Specify question round, 2026-06-10.)*
## Acceptance Criteria
### AC-1: Anchor validation runs and fails on breakage (FR-1)
Given the validation script is installed
When an anchor referenced by a framework file is renamed without updating the
reference
Then the script exits non-zero naming the offending file and line
And the measurable benefit is verified: the script runs green on the current
tree at closure.
### AC-2: Rule map split into lint data + archived narrative (FR-2)
Given the split decision recorded in FR-2
When the narrative is archived and the live file is slimmed to the
machine-read inventory
Then `make lint-rules` and `make check` pass unchanged, the live file carries
the "machine-read" label, and the narrative is preserved alongside the
IMP-20260514 archive context
And the measurable benefit is verified: zero live documents reference the map
as human-maintained prose (grep evidence), and the live file's line count
drops to the inventory minimum (before/after counts in closure evidence).
### AC-3: No mandatory rule is two hops away (FR-3)
Given the post-change tree
When each MUST/Never/Always rule in `boundaries.md` and `spec-lifecycle.md` is
traced to its full statement
Then every trace resolves in ≤1 link hop
And the measurable benefit is verified: the Task 1 baseline count of ≥2-hop
chains is reduced to 0 (trace table in closure evidence).
### AC-4: One source per overlapping topic (FR-4)
Given the list of overlapping pairs identified in Task 1
When each pair is deduplicated
Then one file owns the content and the counterpart is a pointer or deleted,
with `check-md-links.sh` green
And the measurable benefit is verified: duplicated-paragraph count across
pairs is 0 (grep evidence against the Task 1 baseline).
## Architecture
Skipped — meta-documentation and validation scripts only; no bounded context,
data flow, schema, pipeline, or UI change.
## Out of Scope
- OS-1: Renaming `.github/copilot/*` catalog directories — separate IMP
  (migration touching `ai-switch.sh` and all templates).
- OS-2: CI/pipeline integration of the new script beyond local/Make entry
  points — adoption work, not this improvement.
- OS-3: Rewriting rule content — this spec relocates and deduplicates; it
  does not change what any rule requires.
## Split Decision
Kept as one spec — decided with the owner at the Specify question round
(2026-06-10). The candidate split line (validation tooling FR-1/FR-2 vs.
content dedup FR-3/FR-4) was considered and rejected: both clusters edit the
same small set of framework meta-docs, share one closure metric (zero drift
sites), and partial application leaves the map archived but unverifiable or
verified but still duplicated — worse than either end state. No `siblings:`,
no `depends-on:`.
## Tasks

> **Before starting Task T1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Baseline audit (feeds AC-3/AC-4 metrics): (a) trace every MUST/Never/Always rule in `boundaries.md` + `spec-lifecycle.md` to its full statement, list chains needing ≥2 hops; (b) inventory all overlapping `docs/<topic>.md` ↔ `framework/skills/<topic>/SKILL.md` pairs with duplicated-paragraph counts. Record both baseline tables in this spec under Closure Evidence. Inventory only — no edits outside this spec. | this spec *(baseline tables)* | `framework/boundaries.md`; `framework/spec-workflows/spec-lifecycle.md`; `framework/skills/**/SKILL.md`; `docs/*.md` | — | writing-docs | deep | ☑ done |
| T2 | Anchor validator (FR-1): `scripts/validate-anchors.py` (stdlib only, mirrors `lint-rules.py` conventions) — every intra-repo markdown link with a `#fragment` across `framework/**/*.md` + `docs/**/*.md` must resolve to an existing heading or `<a id>`; non-zero exit with `path:lineno`. Add `make validate-anchors`; hook into `make check` and `sync-agents-check`. Fixture: deliberate broken-anchor test. | `scripts/validate-anchors.py` *(new)*; `Makefile` | `scripts/lint-rules.py` *(precedent)*; `scripts/validate-specs.py` *(precedent)* | — | writing-specs | default | ☐ todo |
| T3 | Rule-map split (FR-2): slim `docs/rule-canonical-map.md` to the machine-read inventory (rule id → canonical file → anchor → phrases) with a "machine-read by lint-rules.py" header; move audit narrative to `docs/specs/archived/IMP-20260514-rule-map-narrative.md`. `lint-rules.py` parser must keep passing without code changes; `make check` green. | `docs/rule-canonical-map.md`; `docs/specs/archived/IMP-20260514-rule-map-narrative.md` *(new)* | `scripts/lint-rules.py` *(parser contract)* | — | writing-docs | default | ☐ todo |
| T4 | One-hop re-homing (FR-3): inline or re-home every ≥2-hop chain from the T1 list so each mandatory rule resolves in ≤1 hop from `boundaries.md` / `spec-lifecycle.md`; update map inventory entries for any relocated canonical text; document the one-hop convention in `docs/agent-protocol.md`. `make check` green (lint-rules + validate-anchors). | `framework/boundaries.md`; `framework/spec-workflows/spec-lifecycle.md`; `docs/agent-protocol.md`; `docs/rule-canonical-map.md` | T1 baseline table; chain-target files identified in T1 | T1; T2; T3 | writing-docs | deep | ☐ todo |
| T5 | Docs↔skills dedup (FR-4): for every pair from the T1 inventory, skill keeps the agent-facing content; doc shrinks to a one-line pointer plus human-facing rationale, or is deleted; update inbound links. `make links-check` + `make check` green. | `framework/skills/**/SKILL.md`; `docs/<topic>.md` per T1 inventory | T1 pair inventory | T1; T2 | writing-docs | default | ☐ todo |
| T6 | Closure (all ACs): run `make check` — all green; assemble before/after evidence (T1 baselines → 0 two-hop chains, 0 duplicated paragraphs, map line counts); bump `*Last updated:*` stamps; log lessons to `docs/improvements-log.md`; refresh `## Summary` if scope drifted. | all previously edited files *(verify only)*; `docs/improvements-log.md`; this spec | T1 baselines; HEAD post-T2-T5 | T4; T5 | writing-specs | default | ☐ todo |
## Closure Evidence

### T1 baseline — rule-chain trace (feeds AC-3)

Method: extracted every outbound link from `framework/boundaries.md` (14
Always / 5 Ask-first / 9 Never) and
`framework/spec-workflows/spec-lifecycle.md` (13 Rules + lane rules); checked
each 1-hop target for onward deferral of normative content.

| 1-hop target | Self-contained? |
|---|---|
| `spec-lifecycle.md` anchors (×4 from boundaries) | yes — full statements at anchor |
| `boundaries.md` anchors (×3 from lifecycle) | yes |
| `docs/agent-protocol.md` (+ `#the-bottom-line--canonical-format`) | yes — full format table |
| `skills/writing-specs/references/bounded-autonomy-rules.md` | yes — 52-line decision matrix, no onward defer |
| `skills/writing-specs/references/splitting-rules.md` | yes — 66-line trigger/exception tables |
| `skills/reviewing-changes/SKILL.md`, `agents/reviewer.md`, `agents/README.md` | yes |
| `docs/baseline-citations.md` | yes — schema lives there |

**Baseline: rules requiring ≥2 hops for their full statement = 0.**
(AC-3 target of 0 is already met pre-change.)

### T1 baseline — docs ↔ skills pair inventory (feeds AC-4)

Method: normalized-line intersection (lines ≥50 chars, links stripped,
whitespace collapsed) between each `docs/<topic>.md` and its skill
counterpart(s).

| Pair | Doc lines | Skill lines | Duplicated lines |
|---|---|---|---|
| `docs/writing-specs.md` ↔ `skills/writing-specs/` (SKILL + authoring-steps) | 189 | 122 | 0 |
| `docs/writing-docs.md` ↔ `skills/writing-docs/SKILL.md` | 109 | 24 | 0 |
| `docs/model-selection.md` ↔ `skills/model-selection/SKILL.md` | 99 | 19 | 0 |
| `docs/bootstrapping-project.md` ↔ `skills/bootstrapping-project/` | 147 | 87 | 0 |
| `docs/splitting-specs.md` ↔ `references/splitting-rules.md` | 70 | 66 | 0 |
| `docs/bounded-autonomy.md` ↔ `references/bounded-autonomy-rules.md` | 61 | 52 | 0 |

**Baseline: duplicated paragraphs = 0 across all 6 pairs.** Established
ownership direction is doc = content, skill = pointer (the inverse of FR-4's
chosen direction), applied consistently by IMP-20260514 D3.

### T1 baseline — rule-map composition (feeds AC-2)

`docs/rule-canonical-map.md`: 220 lines total; 94 table (inventory) lines;
narrative sections: `## Audit method` (~18L), per-rule action-item /
side-finding notes, `## Summary` (~9L), `## D2-D6 action queue` (~9L).
Side-check: `check-md-links.sh` validates file existence only — `#fragment`
resolution is unchecked today (FR-1 gap confirmed; the R10 side-finding in the
map documents a historical broken anchor).

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
## Docs updates required
- `docs/agent-protocol.md` — add the one-hop reachability convention.
- `docs/rule-canonical-map.md` — archive or place under validation (FR-2).
- Overlapping `docs/` ↔ `skills/` pairs — one source + pointer (FR-4).
## Rollout / migration notes
- Docs-only plus one script; no deploy order. Revert is a single git revert.
- `framework/boundaries.md` edits trigger the "Ask first" boundary — covered
  by this spec's gates.
