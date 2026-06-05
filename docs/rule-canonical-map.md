# Rule Canonical Map

*Last updated: 2026-05-14*

Audit inventory of rules that appear in ≥2 framework files. Produced by
Task D1 of `IMP-20260514-dedup-rule-statements`. **No edits to canonical
files were performed in D1** — this file is inventory only.

D2 will add HTML anchors (`<a id="…"/>`) to each canonical-location line.
D3 will replace verbatim restatements in linking-sites with one-line
markdown links to those anchors. `make lint-rules` (D4) will fail when
any rule from this map appears verbatim outside its canonical location.

---

## Audit method

Files inspected (all rule-bearing files in scope):

| File | Lines | Rule sections |
|---|---|---|
| `framework/boundaries.md` | 55 | § Always do (14) / § Ask first (5) / § Never do (9) / § Escalation protocol |
| `framework/spec-workflows/spec-lifecycle.md` | 149 | § Rules (13 numbered) + § Status transitions + § Visualize / § Split sub-step |
| `framework/prompts/create-spec.prompt.md` | 27 | § Hard rules (3) |
| `framework/prompts/bug-triage.prompt.md` | 21 | § Hard rules (3) |
| `framework/prompts/plan-spec.prompt.md` | 23 | § Hard rules (4) |
| `framework/prompts/visualize-spec.prompt.md` | 19 | § Hard rules (4) |
| `framework/skills/writing-specs/SKILL.md` | 30 | (References only; no rule restatements) |
| `framework/skills/writing-specs/references/bounded-autonomy-rules.md` | 52 | § Decision matrix + § Ambiguity score (canonical; not duplicated) |
| `framework/skills/writing-specs/references/splitting-rules.md` | 64 | §1-§4 (canonical; cited heavily but not restated) |

---

## Rule inventory (≥2 restatements)

Each row: **rule** | **proposed canonical location + anchor (added in D2)** | **linking sites that must replace verbatim text with anchor link in D3**.

### R1 — Never skip the Specify stage

| | |
|---|---|
| **Restatement count** | 3 |
| **Canonical location** | `framework/boundaries.md § Never do #2` |
| **Proposed anchor (D2)** | `<a id="never-skip-specify"/>` |
| **Linking sites (D3)** | `framework/spec-workflows/spec-lifecycle.md § Rules #1`; `framework/prompts/create-spec.prompt.md § Hard rules` (different framing: "Never skip the question round") |

Verbatim phrases observed:
- boundaries (post-IMP-20260514-trivial-lane T3): *"Never skip the Specify stage — even a trivial bug needs confirmed understanding via the question round. The Trivial lane"*
- boundaries (pre-IMP-20260514-trivial-lane T3 — kept tracked to catch reverts): *"Never skip the Specify stage — even a trivial bug needs confirmed understanding via the question round."*
- spec-lifecycle (pre-D3): *"Never skip the Specify stage — even for a one-line bug. Confirm understanding with the ≤10 questions from the relevant question list."*
- create-spec.prompt (pre-D3): *"Never skip the question round — even trivial CRs get one."*

### R2 — Never write `## Tasks` table while status is `specify`

| | |
|---|---|
| **Restatement count** | 5 |
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #2` |
| **Proposed anchor (D2)** | `<a id="never-tasks-table-at-specify"/>` |
| **Linking sites (D3)** | `framework/boundaries.md § Never do #3`; `framework/prompts/create-spec.prompt.md § Hard rules`; `framework/prompts/visualize-spec.prompt.md § Hard rules`; `framework/prompts/plan-spec.prompt.md § Hard rules` (different framing: "Never write tasks without approved requirements") |

Verbatim phrases observed:
- boundaries / spec-lifecycle: *"Never write a `## Tasks` table while `status` is `specify`."*
- create-spec.prompt: *"Never write `## Tasks` here — that belongs to Plan."*
- visualize-spec.prompt: *"Never write `## Tasks` here."*

### R3 — Never flip status without explicit human approval

| | |
|---|---|
| **Restatement count** | 4 |
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #3, #4, #5` (three lifecycle-specific rules: → plan, → in-progress, → done) |
| **Proposed anchor (D2)** | `<a id="never-flip-without-gate"/>` (covers all 3 sub-rules collectively) |
| **Linking sites (D3)** | `framework/boundaries.md § Never do #4` |

Verbatim phrases observed:
- boundaries: *"Never flip a spec's status without the preceding human gate."*
- spec-lifecycle #3: *"Never flip to `plan` without explicit human approval of requirements."*
- spec-lifecycle #4: *"Never flip to `in-progress` without explicit human approval of the plan."*
- spec-lifecycle #5: *"Never flip to `done` while any acceptance criterion lacks documented evidence."*

Note: spec-lifecycle is canonical because the three sub-rules are lifecycle-specific. boundaries can replace its single-line restatement with a link.

### R4 — Always update `*Last updated: YYYY-MM-DD*` stamp

| | |
|---|---|
| **Restatement count** | 3 (rule restatements; prompts contain operational mentions which are not restatements) |
| **Canonical location** | `framework/boundaries.md § Always do #10` |
| **Proposed anchor (D2)** | `<a id="last-updated-stamp"/>` |
| **Linking sites (D3)** | `framework/spec-workflows/spec-lifecycle.md § Rules #6`; `docs/writing-docs.md § Core rules #1` *(discovered by D4 lint-rules; fixed during D4)* |

Verbatim phrases observed:
- boundaries: *"Update `*Last updated: YYYY-MM-DD*` on every modified doc."*
- spec-lifecycle: *"Always update `*Last updated: YYYY-MM-DD*` when changing the file."*

Note: Prompts contain operational instructions ("then update the stamp"). Those are not rule restatements — they are step instructions referencing the rule. Excluded from D3 replacement.

### R5 — Always update task row status in-place

| | |
|---|---|
| **Restatement count** | 2 |
| **Canonical location** | `framework/boundaries.md § Always do #11` |
| **Proposed anchor (D2)** | `<a id="task-row-status-in-place"/>` |
| **Linking sites (D3)** | `framework/spec-workflows/spec-lifecycle.md § Rules #7` |

Verbatim phrases observed:
- boundaries: *"Update task row status in-place as each task completes."*
- spec-lifecycle: *"Always update the task row status in-place as tasks progress."*

### R6 — Split check is mandatory in Specify, before Visualize, before the gate

| | |
|---|---|
| **Restatement count** | 5 (across spec-lifecycle, create-spec, bug-triage; plus 2 internal restatements within spec-lifecycle itself) |
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #9` (the mandate); split-rule mechanics live in `splitting-rules.md` (already canonical, not duplicated) |
| **Proposed anchor (D2)** | `<a id="split-check-mandatory"/>` |
| **Linking sites (D3)** | `framework/spec-workflows/spec-lifecycle.md § Rules #11` (self-consolidate — merge into #9 or link to anchor); `framework/spec-workflows/spec-lifecycle.md § Rules #12` (same); `framework/prompts/create-spec.prompt.md § Hard rules` ("Never request the gate without `## Split Decision` filled"); `framework/prompts/bug-triage.prompt.md § Hard rules` (same); `framework/prompts/plan-spec.prompt.md § Steps #3` (Safety-net split check — operational, keep but link the rule reference) |

Verbatim phrases observed:
- spec-lifecycle #9: *"The Split check is a mandatory sub-step of Specify — complete it before Visualize..."*
- spec-lifecycle #11: *"Never request the requirements gate without completing the Split check; record the outcome under `## Split Decision` first."*
- spec-lifecycle #12: *"Never bundle independently-testable features into one spec — split per splitting-rules.md § 2."*
- create-spec.prompt: *"Never request the gate without `## Split Decision` filled in every spec (this + siblings)."*
- bug-triage.prompt: *"Never request the gate without `## Split Decision` filled in every spec."*

Note: `splitting-rules.md` is the canonical source for trigger/exception IDs (T1-T6, P1-P3, E1-E5) — that table is NOT duplicated; only the mandate is.

### R7 — Spec with unmet `depends-on:` MUST stay at `specify`

| | |
|---|---|
| **Restatement count** | 2 |
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #10` |
| **Proposed anchor (D2)** | `<a id="depends-on-blocks-plan"/>` |
| **Linking sites (D3)** | `framework/prompts/plan-spec.prompt.md § Hard rules` |

Verbatim phrases observed:
- spec-lifecycle: *"A spec with unmet `depends-on:` MUST stay at `specify` (never flip to `plan`) until all listed siblings reach `done`."*
- plan-spec.prompt: *"Never advance to `plan` while `depends-on:` siblings are unmet."*

### R8 — Visualize stays at `status: specify`

| | |
|---|---|
| **Restatement count** | 2 |
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #8` (the rule) + `§ Visualize sub-step` (the definition) |
| **Proposed anchor (D2)** | `<a id="visualize-not-a-status"/>` (on Rule #8) |
| **Linking sites (D3)** | `framework/prompts/visualize-spec.prompt.md § Hard rules` |

Verbatim phrases observed:
- spec-lifecycle #8: *"Visualize is a sub-step of Specify (not a status). When triggered, complete it before asking for the requirements gate."*
- visualize-spec.prompt: *"Status stays at `specify` — Visualize is not a separate status."*

### R9 — "Continue" means the next single task only

| | |
|---|---|
| **Restatement count** | 1 in framework/; multiple in docs/ (out-of-scope per Specify) |
| **Canonical location** | `framework/boundaries.md § Never do #6` |
| **Proposed anchor (D2)** | `<a id="continue-single-task-only"/>` |
| **Linking sites (D3)** | **None inside `framework/**` — no action needed** |
| **Out-of-scope mentions (informational)** | `docs/ai-agent-framework.md § Key principles #2`; `docs/spec-workflow-guide.md § Stage 3 + § The one-page summary`; workspace `README.md` |

Note: out-of-scope mentions are documentation prose, not rule restatements. The boundaries rule is already canonical; docs reference it informally. D3 does **not** need to replace these — they are descriptive, not normative. R9 is listed for completeness (the anchor will exist after D2 for future linking; D3 doesn't act on it).

### R10 — Visualize trigger conditions

| | |
|---|---|
| **Restatement count** | 2 (in `spec-lifecycle.md § Visualize sub-step` + reference from `spec-workflows/README.md § Visualize sub-step when mandatory` *(unverified — see action item below)*) |
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Visualize sub-step` |
| **Proposed anchor (D2)** | `<a id="visualize-triggers"/>` |
| **Linking sites (D3)** | `framework/prompts/visualize-spec.prompt.md § Preconditions`; `framework/prompts/create-spec.prompt.md § Steps #5` — both currently link to `spec-workflows/README.md § Visualize…`; D2/D3 redirects them to the new anchor in `spec-lifecycle.md` (the canonical home) |

**Action item carried into D2 — RESOLVED 2026-05-14:** `spec-workflows/README.md` does NOT restate Visualize triggers; it only references `spec-lifecycle.md` as the canonical source. No additional linking sites for R10. **Side-finding:** `create-spec.prompt.md § Steps #5` and `visualize-spec.prompt.md § Preconditions` both link to `spec-workflows/README.md#visualize-sub-step-when-mandatory`, but that anchor does not exist in `README.md` (the section isn't there — the triggers live in `spec-lifecycle.md`). D3 will redirect both prompts to the new `spec-lifecycle.md#visualize-triggers` anchor.

---

## Rules NOT duplicated (canonical-only — no D3 action)

For reference, these rules live in exactly one place and are correctly cited from elsewhere:

| Rule | Canonical location |
|---|---|
| The Bottom Line — canonical format | `docs/agent-protocol.md` (referenced by `boundaries.md § Always do #9`) |
| Front-matter schema | `spec-lifecycle.md § Front-matter schema` |
| Status transitions table | `spec-lifecycle.md § Status transitions` |
| File naming pattern | `spec-lifecycle.md § File naming` |
| File location active/archived | `spec-lifecycle.md § File location` |
| Split triggers / exceptions (T1-T6, P1-P3, E1-E5) | `splitting-rules.md` |
| Bounded autonomy decision matrix | `bounded-autonomy-rules.md` |
| Ambiguity scoring | `bounded-autonomy-rules.md § Ambiguity score` |
| Escalation protocol | `boundaries.md § Escalation protocol` |
| Tests-with-features mandate | `boundaries.md § Always do #6` (not restated elsewhere) |
| BUG Task 1 = reproduce + failing test | `bug-triage.prompt.md § Hard rules` (BUG-type-specific; not restated) |
| Preflight proof format | `boundaries.md § Always do #4` (referenced via prose in agent-protocol) |
| Two-scope skill / boundary lookup | `boundaries.md § Always do #1, #5` + `docs/agent-protocol.md` |

---

## Summary

- **10 distinct rules** have ≥2 restatements across in-scope files (R1-R10), with R9 having no in-framework duplicates (anchor created for future linking only).
- **9 rules** require D3 action (R1-R8, R10). R9 is anchor-only.
- **Total verbatim restatement sites to replace in D3:** approximately **13 sites** across `boundaries.md` (1), `spec-lifecycle.md § Rules #11, #12` (2 self-consolidation), `create-spec.prompt.md` (2), `bug-triage.prompt.md` (1), `plan-spec.prompt.md` (3), `visualize-spec.prompt.md` (4).
- **2 canonical files** own all 10 anchors: `boundaries.md` (R1, R4, R5, R9) and `spec-lifecycle.md` (R2, R3, R6, R7, R8, R10).
- **0 rules** found to be semantically distinct under similar wording — no false positives in the dedup candidates.
- **1 verification action** carried into D2: confirm whether `spec-workflows/README.md` restates Visualize triggers.

## D2-D6 action queue derived from this audit

| Step | Action | Files touched |
|---|---|---|
| D2 | Add 10 anchors to canonical locations (R1-R10) | `boundaries.md` (R1, R4, R5, R9); `spec-lifecycle.md` (R2, R3, R6, R7, R8, R10) |
| D3 | Replace ~13 verbatim restatement sites with anchor links | `boundaries.md` (1 site); `spec-lifecycle.md § Rules #11, #12` (2 self-consolidations); `create-spec.prompt.md` (2 sites); `bug-triage.prompt.md` (1 site); `plan-spec.prompt.md` (3 sites); `visualize-spec.prompt.md` (4 sites) |
| D4 | `make lint-rules` enforces the canonical-map (scripts/lint-rules.py grep + canonical-map parser) | new `scripts/lint-rules.py`; `Makefile` |
| D5 | Canonical-template generator (orthogonal scope; bundled because edit-surface overlaps with D2/D3) | `framework/templates/system/_canonical.md` (new); `scripts/generate-system-templates.sh` (new); switched rendered files |
| D6 | Semantic-equivalence summary in Closure Evidence; rule counts (14/5/9 in boundaries) preserved | verify-only pass; `make validate-specs && make lint-rules && make sync-system-templates` green |
