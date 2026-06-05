# Improvements Log — ai-dotfiles

*Last updated: 2026-06-05*

Process-improvement log for the **ai-dotfiles framework** itself.
Authoring format and timing rule live in
[`improvements-log-format.md`](improvements-log-format.md). Append new
entries at the bottom; never edit past entries.

This file is the framework-scope log. Each project repo carries its
own `docs/improvements-log.md` for project-specific findings.

---

### 2026-05-14 — Specify-time numerical floors can mis-fire as tripwires

- **Spec / task:** IMP-20260514-spec-validator / F5
- **Category:** anti-pattern
- **What was found:** FR-5/AC-5 demanded "≥5 historical findings" against the archived corpus. The validator at HEAD surfaced 0 findings after F4 resolved the only two real ones. The re-Specify tripwire fired with the premise *"0 findings ⇒ checks are wrong"*, but a per-check fixture audit demonstrated all 8 classes work correctly. The corpus was simply clean — a positive signal mis-classified as a failure.
- **What was changed:** Amended FR-5/AC-5 to require the *artifact* (verbatim backtest capture in `tests/backtest-baseline.md`) rather than a numerical finding floor. Re-Specify tripwire reworded to fire on "structural false-negative (a check class fails its fixture)" rather than "0 findings."
- **Suggested follow-up:** When drafting future specs, prefer "artifact exists" or "non-empty" over "≥N" unless N has a real reason (perf SLA, throughput target). Document this guidance in `docs/acceptance-criteria-patterns.md`.

### 2026-05-14 — Edit tool struggles with mixed Unicode whitespace in regex literals

- **Spec / task:** IMP-20260514-spec-validator / F4
- **Category:** tooling
- **What was found:** Inserting a Unicode range into the `_NON_ENGLISH_RE` regex literal failed via the Edit tool — the surrounding lines contained NBSP (U+00A0) and EN QUAD (U+2000) as range-start characters, which the tool's normalization couldn't match exactly.
- **What was changed:** Used `python3 - <<'PY' ... PY` with `pathlib + replace()` as a fallback. Inline byte-precise edit succeeded.
- **Suggested follow-up:** Document the Python-in-place pattern in `docs/agent-protocol.md` as a known fallback for Edit-tool Unicode quirks. No tooling change needed at this level.

### 2026-05-14 — ai-dotfiles dogfooding gap (resolved by this log)

- **Spec / task:** IMP-20260514-spec-validator / closure
- **Category:** anti-pattern
- **What was found:** `boundaries.md § Always do #13` mandates a `docs/improvements-log.md` in every project. ai-dotfiles itself — the framework root — did not have one until this commit. Same gap for `docs/architecture/module-map.md` (still absent).
- **What was changed:** Created `docs/improvements-log.md` (this file) during closure of IMP-20260514-spec-validator. `module-map.md` remains absent; recommend a follow-up IMP to fully dogfood.
- **Suggested follow-up:** Open `IMP-20260515-ai-dotfiles-dogfood` to add `docs/architecture/module-map.md` mapping framework/, scripts/, profiles/, templates/, prompts/, spec-workflows/ as bounded contexts.

### 2026-05-14 — `make sync-agents-check` namespace-overloaded across scopes

- **Spec / task:** IMP-20260514-spec-validator / F5
- **Category:** pattern
- **What was found:** Three different `make sync-agents-check` targets now exist depending on cwd: (a) workspace `tobevisit/Makefile` runs `.github/scripts/sync-agents.sh --check` (AGENTS.md drift), (b) project repos (e.g. tobevisit-content) chain their own validators, (c) ai-dotfiles (post-this-spec) chains `validate-specs`. The same command name does three different things. Acceptable for now — each cwd has the right local meaning — but the overload is a latent friction.
- **What was changed:** None — logged for review. The overload is by convention, not by accident.
- **Suggested follow-up:** Consider renaming the ai-dotfiles target to `ci-check` or `framework-check` if the friction shows up in practice. Not urgent; revisit after one or two real CI runs.

### 2026-06-05 — Specs were too verbose for per-gate human review

- **Spec / task:** IMP-20260605-solo-agent-workflow-realignment / Specify
- **Category:** pattern
- **What was found:** The owner reviews every spec at each gate. Long prose sections (Current State, Proposed Improvement, restated rationale) pushed read time toward ~20 min/iteration without adding signal beyond the FR/AC contract. First draft of this IMP ran ~190 lines.
- **What was changed:** Rewrote the IMP to ~124 lines — compressed prose to a few bullets, kept FR/AC precise but terse, removed cross-section restatement. New default: the FR/AC contract carries the weight; narrative is minimal.
- **Suggested follow-up:** Fold a "keep specs terse — prose minimal, FR/AC carry the contract" line into `docs/writing-specs.md` writing-style rules and/or `framework/spec-workflows/templates/*` so it's enforced by convention, not memory.

### 2026-06-05 — Reached for harness memory instead of the framework's improvements-log

- **Spec / task:** IMP-20260605-solo-agent-workflow-realignment / Specify
- **Category:** anti-pattern
- **What was found:** Given process feedback ("write specs concise"), I stored it in the harness's private memory file rather than `docs/improvements-log.md`. `boundaries.md § Always do #13` and the project CLAUDE.md designate the improvements-log as the canonical home for process-improvement findings, and CLAUDE.md states project instructions OVERRIDE default behavior. I defaulted to the generic memory tool without checking that the framework already owns this class of fact.
- **What was changed:** Deleted the memory file + its `MEMORY.md` index line; moved the finding here. Going forward, process-improvement / friction findings go to the relevant `docs/improvements-log.md`, not harness memory.
- **Suggested follow-up:** None — convention already exists; this was an adherence miss, now corrected.

### 2026-06-05 — Generator-delegation removal missed `research-spec.prompt.md`

- **Spec / task:** IMP-20260605-solo-agent-workflow-realignment / T3
- **Category:** anti-pattern
- **What was found:** FR-2 named only `create-spec.prompt.md` and `plan-spec.prompt.md` as prompts that delegate to the generator agents. After deleting the agent files in T3, a grep surfaced that `framework/prompts/research-spec.prompt.md:17` also delegates to `spec-author` (RES mode) — left dangling, it points at a deleted file. The RES prompt was not in any task's Files column.
- **What was changed:** Folded the `research-spec.prompt.md` inline rewrite into T4 (same theme: bring the framework into line with the removal). Surfaced at the T3 gate for re-approval before proceeding.
- **Suggested follow-up:** When a spec enumerates files by name in an FR (rather than "all prompts that delegate to X"), the Plan stage should grep for the full set rather than trust the FR's list. Consider a generic-phrasing preference in `docs/writing-specs.md`.

### 2026-06-05 — Orphaned `tests/*.md` reference removed agents (reviewer dogfood finding)

- **Spec / task:** IMP-20260605-solo-agent-workflow-realignment / reviewer sub-step
- **Category:** pattern
- **What was found:** Dogfooding the new `reviewer` sub-agent on this IMP surfaced that `tests/subagents-target.md`, `tests/subagents-baseline.md`, and `tests/research-lane-closure-evidence.md` still reference `spec-author`/`splitter`/`task-planner`. They are historical measurement/closure artifacts of the now-superseded `IMP-20260514-framework-subagents`; validators do not consume them, so they are not AC violations (the AC-1/AC-2 grep scope was `framework/prompts framework/agents`).
- **What was changed:** None in this IMP — left out to avoid scope creep. Flagged as a follow-up.
- **Suggested follow-up:** Trivial-lane IMP to archive or annotate those `tests/*.md` as historical (note they describe the superseded delegated-subagent model) so the active tree is free of dangling agent references.

### 2026-06-05 — Applied the terseness + generic-phrasing follow-ups

- **Spec / task:** ad-hoc (direct edit, owner-approved)
- **Category:** protocol
- **What was found:** The two convention follow-ups logged earlier today (specs too verbose; FRs enumerating files by name) had no home in the canonical writing-style guidance.
- **What was changed:** `docs/writing-specs.md` — added a Forbidden bullet (no point restated across Summary / Current State / Proposed Improvement; FR/AC contract carries the spec), anti-pattern #12 (don't enumerate files inside an FR; phrase generically + grep at Plan), and a Plan-stage note to grep for the full set when an FR names an affected set by capability. Owner approved direct edits (no spec) for these two entries only.
- **Suggested follow-up:** None — entries #1 and #3 from earlier today are now resolved in canonical guidance.
