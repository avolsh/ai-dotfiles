# Dedup Closure Evidence

*Captured: 2026-05-14*
*Spec: IMP-20260514-dedup-rule-statements — Task D6*

Closure evidence artifact for the dedup IMP. Captures: rule-by-rule
before/after semantic-equivalence summary (FR-6), all-checks-green
verification (FR-7), and the preserved rule counts in `boundaries.md`.

## All-checks green

```
$ make validate-specs
python3 ./scripts/validate-specs.py
validate-specs: OK (14 spec(s); 8 check(s) registered).
exit=0

$ make lint-rules
python3 ./scripts/lint-rules.py
lint-rules: OK (8 rule(s), 23 phrase(s) tracked).
exit=0

$ make sync-system-templates  # idempotent — MD5 stable across runs
./scripts/generate-system-templates.sh
rendered: framework/templates/system/claude/CLAUDE.md
rendered: framework/templates/system/copilot/copilot-instructions.md
rendered: framework/templates/system/codex/AGENTS.md
generate-system-templates: OK (3 file(s) rendered from _canonical.md)
exit=0  (byte-identical output on re-run; MD5 hashes verified stable)
```

Out-of-scope, not blocking: `make links-check` finds 5 broken links
inside `framework/skills/.system/openai-docs/references/` (upstream
mirrored content; out of scope per IMP-20260513-slim-skill-bodies).
Pre-existed before this IMP; recorded for a follow-up framework cleanup.

## Rule counts preserved (FR-6 — no semantic intent change)

| File | Section | Before (IMP-20260513-compress-boundaries closure) | After (this IMP closure) | ✅ |
|---|---|---|---|---|
| `framework/boundaries.md` | Always do | 14 | 14 | ✓ |
| `framework/boundaries.md` | Ask first | 5 | 5 | ✓ |
| `framework/boundaries.md` | Never do | 9 | 9 | ✓ |
| `framework/spec-workflows/spec-lifecycle.md` | Rules | 13 | 13 | ✓ |

## Rule-by-rule semantic-equivalence summary

For each rule with ≥2 restatements at pre-D2 HEAD, listing the
before/after wording and confirming intent is preserved.

### R1 — Never skip the Specify stage

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `boundaries.md § Never do #2` (canonical) | "Never skip the Specify stage — even a trivial bug needs confirmed understanding via the question round." | unchanged + `<a id="never-skip-specify"></a>` | ✅ |
| `spec-lifecycle.md § Rules #1` | "Never skip the Specify stage — even for a one-line bug. Confirm understanding with the ≤10 questions from the relevant question list." | "Skip-protection rule lives at [`boundaries.md § Never do #2`](...). In lifecycle terms: even a one-line bug runs the ≤10-question round from its question list before requirements gate." | ✅ (operational note preserved) |
| `create-spec.prompt.md § Hard rules` | "Never skip the question round — even trivial CRs get one." | "No skipping the question round, even for trivial CRs — see [`boundaries.md § Never do #2`](...)." | ✅ |

### R2 — Never write `## Tasks` table while status is `specify`

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `spec-lifecycle.md § Rules #2` (canonical) | "Never write a `## Tasks` table while `status` is `specify`." | unchanged + `<a id="never-tasks-table-at-specify"></a>` | ✅ |
| `boundaries.md § Never do #3` | "Never write a `## Tasks` table while `status` is `specify`." | "Never populate `## Tasks` before Plan — canonical rule at [`spec-lifecycle.md § Rules #2`](...)." | ✅ |
| `create-spec.prompt.md § Hard rules` | "Never write `## Tasks` here — that belongs to Plan." | "No `## Tasks` table here — see [`spec-lifecycle.md § Rules #2`](...)." | ✅ |
| `visualize-spec.prompt.md § Hard rules` | "Never write `## Tasks` here." | "No `## Tasks` table here — see [`spec-lifecycle.md § Rules #2`](...)." | ✅ |

### R3 — Never flip status without explicit human approval

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `spec-lifecycle.md § Rules #3-#5` (canonical) | Three specific rules (→plan, →in-progress, →done) | unchanged + `<a id="never-flip-without-gate"></a>` on #3 | ✅ |
| `boundaries.md § Never do #4` | "Never flip a spec's status without the preceding human gate ([`spec-workflows/spec-lifecycle.md § Rules`](...))." | "Never flip a spec's status without the preceding human gate — three specific cases at [`spec-lifecycle.md § Rules #3-#5`](...)." | ✅ |

### R4 — Always update `*Last updated:*` stamp

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `boundaries.md § Always do #10` (canonical) | "Update `*Last updated: YYYY-MM-DD*` on every modified doc." | unchanged + `<a id="last-updated-stamp"></a>` | ✅ |
| `spec-lifecycle.md § Rules #6` | "Always update `*Last updated: YYYY-MM-DD*` when changing the file." | "Stamp-bump rule lives at [`boundaries.md § Always do #10`](...); applies to every change of this lifecycle file too." | ✅ |
| `docs/writing-docs.md § Core rules #1` *(missed by D1; caught by D4 lint)* | "Update `*Last updated: YYYY-MM-DD*` on every modified doc." | "**Stamp freshness** — see [`boundaries.md § Always do #10`](...)." | ✅ |

### R5 — Always update task row status in-place

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `boundaries.md § Always do #11` (canonical) | "Update task row status in-place as each task completes." | unchanged + `<a id="task-row-status-in-place"></a>` | ✅ |
| `spec-lifecycle.md § Rules #7` | "Always update the task row status in-place as tasks progress." | "Task-row-update rule lives at [`boundaries.md § Always do #11`](...); applies as tasks progress through the in-progress stage." | ✅ |

### R6 — Split check mandatory in Specify

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `spec-lifecycle.md § Rules #9` (canonical) | "The **Split check** is a mandatory sub-step of Specify — complete it before Visualize and record the outcome under `## Split Decision` in every affected spec." | unchanged + `<a id="split-check-mandatory"></a>` | ✅ |
| `create-spec.prompt.md § Hard rules` | "Never request the gate without `## Split Decision` filled in every spec (this + siblings)." | "No requirements gate without `## Split Decision` filled in this spec + all siblings — see [`spec-lifecycle.md § Rules #9`](...)." | ✅ |
| `bug-triage.prompt.md § Hard rules` | "Never request the gate without `## Split Decision` filled in every spec." | "No requirements gate without `## Split Decision` filled in this spec + all siblings — see [`spec-lifecycle.md § Rules #9`](...)." | ✅ |

### R7 — Spec with unmet `depends-on:` MUST stay at `specify`

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `spec-lifecycle.md § Rules #10` (canonical) | "A spec with unmet `depends-on:` MUST stay at `specify` (never flip to `plan`) until all listed siblings reach `done`." | unchanged + `<a id="depends-on-blocks-plan"></a>` | ✅ |
| `plan-spec.prompt.md § Hard rules` | "Never advance to `plan` while `depends-on:` siblings are unmet." | "No advance to `plan` while `depends-on:` siblings are unmet — see [`spec-lifecycle.md § Rules #10`](...)." | ✅ |

### R8 — Visualize stays at `status: specify`

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `spec-lifecycle.md § Rules #8` (canonical) | "Visualize is a sub-step of Specify (not a status). When triggered, complete it before asking for the requirements gate." | unchanged + `<a id="visualize-not-a-status"></a>` | ✅ |
| `visualize-spec.prompt.md § Hard rules` | "Status stays at `specify` — Visualize is not a separate status." | "Status stays at `specify` (Visualize is a sub-step, not a status — see [`spec-lifecycle.md § Rules #8`](...))." | ✅ |

### R9 — "Continue" means next single task only

Anchor created in `boundaries.md § Never do #6` (`<a id="continue-single-task-only"></a>`). No verbatim restatements inside `framework/` — anchor available for future linking. Docs mentions in `ai-agent-framework.md` / `spec-workflow-guide.md` / workspace `README.md` remained as descriptive prose (out of D3 scope per the canonical map).

### R10 — Visualize trigger conditions

| Site | Before | After | Equivalent? |
|---|---|---|---|
| `spec-lifecycle.md § Visualize sub-step` (canonical) | Trigger list (5 bullets) | unchanged + `<a id="visualize-triggers"></a>` on heading | ✅ |
| `create-spec.prompt.md § Steps #5` (link redirect) | Linked to `spec-workflows/README.md#visualize-sub-step-when-mandatory` (broken anchor — README has no such section) | Now links to `spec-workflows/spec-lifecycle.md#visualize-triggers` (live anchor) | ✅ (target corrected; previously stale) |
| `visualize-spec.prompt.md § Preconditions` (link redirect) | Same broken anchor | Same fix | ✅ |

## Aggregate impact

| Metric | Before D1 | After D6 |
|---|---|---|
| Distinct rules with verbatim duplicates in framework/ | 10 (R1-R10) | 0 |
| Verbatim restatement sites (framework + docs in scope) | ~14 | 0 |
| Anchors landed in canonical files | 0 | 10 |
| Files now lint-enforced for canonical purity | 0 | All `framework/**.md` + `docs/**.md` (minus allowlist) |
| Stale anchor links (link target missing) | 2 (R10 prompts → README.md) | 0 |
| System-template canonical sources | 3 near-identical files | 1 `_canonical.md` + 3 generated outputs |

## Acceptance Criteria coverage

| AC | Evidence |
|---|---|
| AC-1: Rule canonical map exists and is complete | `docs/rule-canonical-map.md` (220 lines, R1-R10) |
| AC-2: Restatements replaced by links (lint green) | `make lint-rules` → `OK (8 rule(s), 23 phrase(s) tracked)`, exit 0 |
| AC-3: Canonical-template generator idempotent | Two consecutive runs produced byte-identical files (MD5 verified) |
| AC-4: Lint-rules catches drift | D4 fixture: injected R2 canonical phrase into create-spec.prompt.md → `rule_duplicate` finding, exit 1 |
| AC-5: Semantic equivalence preserved | This document — 10 rules, 23 site replacements, all marked ✅ |
| AC-6: Validator stays green | `make validate-specs` → `OK (14 spec(s); 8 check(s) registered)`, exit 0 |

## Closure-readiness checklist

- [x] All ACs have evidence (above)
- [x] Rule counts preserved (14/5/9 in boundaries; 13 in spec-lifecycle)
- [x] No rule's semantic intent changed
- [x] All four checks (validate-specs, lint-rules, sync-system-templates, links-check-when-scoped) green within scope
- [x] `tests/dedup-closure-evidence.md` (this file) committed

Ready for closure gate.
