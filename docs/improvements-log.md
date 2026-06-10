# Improvements Log — ai-dotfiles

*Last updated: 2026-06-10*

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

### 2026-06-10 — Audit-first ordering caught a stale premise before it became churn

- **Spec / task:** IMP-20260610-reduce-self-referential-overhead / T1
- **Category:** pattern
- **What was found:** The spec's FR-3 (re-home ≥2-hop rule chains) and FR-4 (dedup docs↔skills pairs) were premised on a code-review impression. The T1 baseline audit measured both: 0 two-hop chains, 0 duplicated paragraphs — IMP-20260514 D3 had already done the work. Executing FR-4 as approved (inverting content ownership) would have been pure churn. Similarly, the original FR-2 ("archive the rule map") assumed the map was unconsumed; checking the tooling revealed `lint-rules.py` machine-reads it, forcing an amendment.
- **What was changed:** T4 rescoped to convention-documentation only; T5 cancelled; FR-4 closed as already satisfied (owner-approved). FR-2 amended to a split (live machine inventory + archived narrative) before the plan gate.
- **Suggested follow-up:** When an IMP's premise comes from impression rather than measurement, make Task 1 a measurement-only task and gate the remaining tasks on its numbers. Verify any "X is unused" claim against the Makefile/scripts before approving a removal FR.

### 2026-06-10 — Anchor-fragment validation paid for itself on the first run

- **Spec / task:** IMP-20260610-reduce-self-referential-overhead / T2
- **Category:** tooling
- **What was found:** `check-md-links.sh` validates file existence only; `#fragment` resolution was unchecked. The new `scripts/validate-anchors.py` caught 2 live broken anchors in `docs/writing-specs.md` on its first run — links to anchors that never existed in `spec-workflows/README.md`, the exact failure class documented (and supposedly closed) by the R10 side-finding of IMP-20260514 D1.
- **What was changed:** `validate-anchors` target wired into `make check` and `make sync-agents-check`; the two stale links redirected to the canonical `spec-lifecycle.md` anchors.
- **Suggested follow-up:** None — the class is now mechanically enforced.

### 2026-06-10 — `validate-specs` flat-glob constrains what can live in `archived/`

- **Spec / task:** IMP-20260610-reduce-self-referential-overhead / T3
- **Category:** tooling
- **What was found:** `discover_specs` globs `docs/specs/{active,archived}/*.md` flat, so any non-spec markdown placed directly in `archived/` is validated as a spec and fails on missing front-matter. The archived rule-map narrative had to live in `archived/artifacts/` instead of the path listed in the task row.
- **What was changed:** Created `docs/specs/archived/artifacts/` for non-spec closure artifacts; divergence recorded in the T3 Bottom Line.
- **Suggested follow-up:** Document the `archived/artifacts/` convention in `docs/spec-templates-guide.md` (or make `discover_specs` skip declared artifact subtrees explicitly) so future closures don't rediscover this.

### 2026-06-10 — First doctor run surfaced two latent breakage classes

- **Spec / task:** IMP-20260610-mechanize-framework-guardrails / T2-T3
- **Category:** tooling
- **What was found:** `make doctor`'s first live run reported 5 failures: (a) the `upstream` framework ref was absent from the symlink loops of both `ai-profile-init.sh` and `ai-switch.sh` — the documented `<system>/upstream/` resolution never existed, which is why the broken state persisted invisibly for weeks; (b) `~/.claude/.active-manifest` and `~/.copilot/.active-manifest` still carry `target=` paths from the pre-CLAUDE_CONFIG_DIR model (`~/.claude/CLAUDE.md`) that no longer resolve.
- **What was changed:** (a) fixed for `ai-profile-init.sh` (T3, `upstream` added to refs) and the profile re-initialized; `ai-switch.sh` was out of the spec's file list and still lacks `upstream` in `_ai_reset_framework_links_for_tool`. (b) not changed — manifests are regenerated by the next `ai personal` switch.
- **Suggested follow-up:** Direct-lane edit adding `upstream` to `ai-switch.sh`'s ref loop; run `ai personal` to regenerate stale manifests; until then `make doctor` reports the 2 manifest failures by design.

### 2026-06-10 — Hook wiring went live mid-spec and enforced its own rule

- **Spec / task:** IMP-20260610-mechanize-framework-guardrails / T5
- **Category:** pattern
- **What was found:** After T3 merged the hooks into the profile's `claude/settings.json`, the running Claude Code session picked them up immediately: the PostToolUse `stamp-refresh` hook auto-bumped `*Last updated:*` on `docs/spec-workflow-guide.md` and `docs/ai-agent-framework.md` before the agent could do it manually — the first boundaries rule to move from prose to mechanical enforcement did so during the very spec that introduced it.
- **What was changed:** Nothing — recorded as live-fire evidence under the spec's Closure Evidence (AC-1).
- **Suggested follow-up:** When extending the hook set (OS-2 follow-up: test-rerun block, Stop-hook build check, preflight reminder), expect hooks to activate mid-session after profile re-init; sequence rollouts accordingly.

### 2026-06-10 — Secrets backstop flagged its own test fixtures on first real commit

- **Spec / task:** Direct lane (owner-reported, post IMP-20260610-mechanize-framework-guardrails)
- **Category:** tooling
- **What was found:** The first real `git commit` after installing the pre-commit backstop was rejected because the planted example key `AKIA...` lived as a contiguous literal inside the two test scripts themselves — the scanner correctly flagged the sources of its own tests.
- **What was changed:** Both fixtures now assemble the key at runtime (`printf '%s%s' "AKIA" "IOSFODNN7EXAMPLE"`): the fixture file written during the test still contains a contiguous match (assertions unchanged, all suites green), while the committed source no longer does. The scanner was not weakened — no allowlist added.
- **Suggested follow-up:** Document the runtime-assembly pattern wherever future fixtures need to plant secret-shaped strings (e.g., a note in framework/hooks/README.md § Tests).

### 2026-06-10 — ai-switch tore down framework links without restoring them; doctor caught it live

- **Spec / task:** Direct lane (incident during IMP-20260610-mechanize-framework-guardrails rollout)
- **Category:** tooling
- **What was found:** An `ai personal` switch removed every symlink under `profiles/` (`_ai_remove_profile_symlinks`) and linked shared user state, but the framework links (instruction files, boundaries, spec-workflows, skills, prompts, templates) were not recreated — `make doctor` immediately reported 24 failures. Two structural collisions surfaced: (a) `codex/skills` is a real directory owned by Codex CLI (`.system` marker), so whole-dir `ln -sfn` produces a nested `skills/skills` link — the per-entry symlink model from agent-protocol.md is the correct shape there; (b) `claude/settings.json` is switched to a symlink into `~/.claude/settings.json`, so profile-init's hook merge writes through to user-level settings (acceptable — that is the file the live session reads — but undocumented).
- **What was changed:** Removed the nested `codex/skills/skills` link, re-ran `ai-profile-init personal` (restores links incl. `upstream`, re-renders hook adapters), doctor back to the 2 known stale-manifest failures.
- **Suggested follow-up:** In `ai-switch.sh`: add `upstream` to the ref loop, make the switch re-create framework links it tears down, and guard `ln -sfn` against existing real directories (use per-entry links for `codex/skills`). Tracked as a spawned background task.
