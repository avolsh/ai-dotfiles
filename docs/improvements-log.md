# Improvements Log — ai-dotfiles

*Last updated: 2026-08-30*

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

### 2026-06-12 — Profile switching stabilized; live verification reshaped the Copilot adapter

- **Spec / task:** IMP-20260610-stabilize-profile-switching / T1-T10
- **Category:** tooling
- **What was found:** (1) The characterization-first ordering paid off twice: the suite captured the exact D1 baseline (upstream lost only after reset→switch), and a mid-task live incident reproduced it with the old on-disk code while the fix was being written. (2) Live per-harness verification (FR-9) found two contract gaps no documentation showed: Copilot CLI sends tool args as a JSON-encoded string in `toolArgs`, and ignores hook exit codes entirely — denial requires `{"permissionDecision":"deny"}` on stdout. An always-exit-2 probe proved the latter. (3) codex-cli 0.139 does not execute hooks in `exec` mode even with `--dangerously-bypass-hook-trust`; interactive trust is the only path.
- **What was changed:** Shared wiring library + scoped teardown + live manifests (FR-1..4); hermetic switch suite in `make check` (FR-5); extractors extended and `adapters/copilot-pretooluse.sh` added (FR-9); Codex live verification recorded as a documented limitation pending one-time interactive trust.
- **Suggested follow-up:** After the owner grants Codex hook trust interactively, re-run the T7 fixture scenario for Codex (Direct lane; the fixture recipe is in the spec's Closure Evidence). During the stability window, treat any new harness-contract surprise the same way: probe first, adapt in the adapter layer, never weaken the canonical scripts.

### 2026-06-12 — Generated profile wiring no longer tracked in git

- **Spec / task:** Direct lane (owner-approved), follow-on to IMP-20260610-stabilize-profile-switching
- **Category:** tooling
- **What was found:** `.gitignore` explicitly un-ignored (`!`) every profile wiring entry (CLAUDE.md, boundaries.md, skills, prompts, spec-workflows, templates, agents, upstream) per tool, so the machine-generated, absolute-path, host-specific symlinks were version-controlled. Every `ai --reset` → commit → re-init cycle then churned `git status` (a reset's committed deletions, then untracked re-creations), and a reset's deletions had already landed in an unrelated product commit.
- **What was changed:** `.gitignore` now ignores `profiles/*/{claude,copilot,codex}/` wholesale (regenerated by `make profile-init` / `ai <profile>`); only the hand-authored `profile.env` and `preferences.md` at the profile root stay tracked. `git rm -r --cached` untracked the 25 generated entries. Verified: re-init now produces zero git churn; `make doctor` green; `make check` 11/11.
- **Suggested follow-up:** None — the reset/switch/re-init cycle is now git-silent by construction.

### 2026-06-12 — Real `ai personal` broke: bash-only idioms in a zsh-sourced library

- **Spec / task:** Hotfix (owner-reported), follow-on to IMP-20260610-stabilize-profile-switching
- **Category:** bug
- **What was found:** `ai personal` failed with "profile wiring failed" and left no active profile. Root cause: `scripts/lib/profile-links.sh` used two bash-only idioms that silently misbehave under zsh, the shell `ai` sources it into: (1) `for x in $VAR` — zsh does not word-split unquoted parameter expansions, so the refs/tools loops ran once with the whole string as one token; (2) `"$src"/.[!.]*` — zsh's default `nomatch` aborts the glob when no dotfiles exist. The entire hermetic test suite passed because it ran under `bash`; the real entry point is zsh. This is exactly the sourced-shell hazard FR-12/Agent-instructions flagged, missed by bash-only testing.
- **What was changed:** Replaced both with portable forms — `_ai_links_words` (quoted `printf | tr`) feeding `while read` loops, and `find -mindepth 1 -maxdepth 1` instead of the dotglob. Added a cross-shell section to `profile-links.test.sh` that re-runs `ai_links_wire_profile` under `zsh` (when present) and asserts every ref link lands incl. a CLI-owned real-dir case; mutation-verified it fails on the bash-only form. Verified real `ai personal` → `✓ profile=personal`.
- **Suggested follow-up:** Any shell library sourced by `ai` MUST be exercised under zsh in tests, not just bash. Consider running the whole switch/links suite under both shells in CI.

### 2026-06-16 — Spec output budget, Figma design-system rule, author-challenge stance

- **Spec / task:** IMP-20260616-spec-output-and-agent-rigor (all 6 tasks)
- **Category:** process / tooling
- **What was found:** A 54-spec corpus analysis (3 roots) showed body avg 283 / median 192.5 / max 1162, with 48/54 over 120 lines; mass concentrated in Requirements + Acceptance/Fix Criteria. The framework had qualitative compression guidance but **no measurable length budget** and no gated step enforcing it; `## Cost Estimate` was fixed overhead in 33/54 specs; the Visualize step routed UI to Figma but never required design-system reuse; and `boundaries.md` had no rule telling agents to challenge a questionable instruction.
- **What was changed:** Added a deterministic ≤120 physical-line body budget + per-section caps + gated Compression-pass step + self-review item (`writing-specs.md`, `authoring-steps.md`, `spec-format.md`); one-line FRs / clustered ACs / no-prose-restating rules + inline template cap hints; removed `## Cost Estimate` framework-wide (templates, prompts, lifecycle, guides); added the Figma design-system-first hard rule (`visualize-spec.prompt.md`, lifecycle links to it); added `boundaries.md` Always-do #15 "Challenge before complying". Closure artifact redrafted 3 representative specs at 41% / 54% / 57% reduction with no FR/outcome loss.
- **Suggested follow-up:** (1) Pre-existing `make links-check` failure — 10 broken links in upstream `modern-javascript-patterns` / `nodejs-backend-patterns` (sibling `advanced-patterns.md` reached via a wrong `references/` prefix) — fix via Direct lane. (2) Pre-existing `_canonical.md` → rendered-system-template drift (research-spec routing row + two pointer lines) — re-render and commit separately. (3) Consider a future `validate-specs` soft check that warns when an authored spec body exceeds 120 physical lines without a justification line.

### 2026-06-17 — ai-switch test uses Bash 4 associative arrays on macOS Bash 3.2

- **Spec / task:** IMP-20260617-rename-architecture-section-to-design / T7
- **Category:** tooling
- **What was found:** The closure-time `make check` passed links, install, spec, rule, anchor, hook, doctor, pre-commit, metrics, and profile-link checks, then `scripts/test/ai-switch.test.sh` failed at its FR-12 hash table (`declare -A`, line 220) with `_ai_link_shared_state: unbound variable`. macOS `/bin/bash` 3.2 does not support associative arrays; this docs-only IMP does not touch the failing script or shared-state engine.
- **What was changed:** No out-of-scope code fix and no unchanged rerun. The required `make sync-agents-check` closure checks remain green; the portability failure is recorded in the IMP's Closure Evidence.
- **Suggested follow-up:** Replace the associative hash table with a Bash 3.2-compatible key/value list, or explicitly require and invoke a modern Bash for the suite; add a macOS Bash 3.2 test lane so the declared local runtime is exercised.

### 2026-06-17 — Secret scanner now distinguishes keys from Markdown anchors

- **Spec / task:** Direct lane (owner-approved commit-blocker fix)
- **Category:** tooling
- **What was found:** The OpenAI key pattern began at the `sk-` suffix inside `task-complexity-estimation`, so a harmless archived-spec table-of-contents anchor blocked commits as a secret.
- **What was changed:** Added a non-word left boundary to the `sk-` alternative and regression coverage proving a real standalone key is rejected while the Markdown anchor is allowed.
- **Suggested follow-up:** None — both the hook unit suite and pre-commit integration suite cover the behavior.

### 2026-08-13 — `validate-specs.py` can only ever validate its own repo

- **Spec / task:** IMP-20260813-config-and-duplication-rules, Specify (discovered while authoring four sibling specs in `tobevisit-content`)
- **Category:** `tooling`
- **What was found:** `main()` resolves the corpus root with `find_repo_root(Path(__file__).resolve().parent)` and ignores `argv` entirely, so the walk always terminates at `ai-dotfiles/docs/specs` no matter where the script is invoked from. Running it with `tobevisit-content` as the working directory reports `OK (22 spec(s))` — the ai-dotfiles corpus — while that project holds 58. The output is indistinguishable from a real pass over the project's specs, which is the dangerous part: an agent that runs it from a project root and reads "OK" has evidence for a claim the run never tested. The eleven registered checks — naming pattern, front-matter schema, dependency graph — therefore cover one of the workspace's four spec corpora, and every project spec written since the validator landed has been unvalidated by construction. Same shape as the 2026-08-12 `verify-baselines.sh` entry: a checker whose name implies coverage it does not have, passing loudly.
- **What was changed:** none — logged, and the four new `tobevisit-content` specs were checked against the front-matter schema by hand instead. The fix is out of this spec's scope (it ships framework rules, not framework tooling).
- **Suggested follow-up:** Accept an optional path argument and fall back to the current working directory before `__file__`, so `python3 validate-specs.py <repo>` validates that repo; then wire it into each project's `make sync-agents-check` the way `lint-rules` is wired into the framework's. Worth pairing with a guard that prints the resolved root and the corpus size on every run — both failures in this class were invisible because the tool never said what it had actually looked at. General rule for this repo's checkers: a validator MUST print the root it resolved, and MUST NOT resolve that root from its own install location when it is meant to be pointed at something.

### 2026-08-13 — Four new skills would have shipped with zero readers

- **Spec / task:** IMP-20260813-config-and-duplication-rules + IMP-20260813-failure-semantics-rules, Specify
- **Category:** `anti-pattern`
- **What was found:** The owner asked how the four skills these two specs create would actually reach the 21 project specs already written. They would not have. A skill is loaded at every stage and task through the spec's `skills:` front-matter, and the task table's `Skills` column is defined as a subset of that list — so a skill absent from the front-matter cannot be reached by any downstream mechanism. All 21 specs had been authored before the skills existed, and none named them. Two of the five delivery mechanisms would still have worked (the `boundaries.md` rules, which are always-on, and the `reviewing-changes` hook), which is exactly what made the gap easy to miss: the specs looked covered because *something* would fire. Naming it plainly: the specs would have shipped four skills with zero readers, which is the dead-configuration-key defect those same specs exist to prevent. `validate-specs.py` could not catch it either — it checks that `skills:` is present, never that the named skills exist or that relevant ones are listed.
- **What was changed:** the four skills were mapped onto the 19 specs whose work they govern and added to their `skills:` front-matter; `boundaries.md` rules in both framework specs now MUST link the skill carrying their depth (FR-3 in each), turning the always-on statement into the entry point rather than a dead end; a new FR-7 requires `authoring-steps.md § A` to instruct future authors to select `skills:` from both scopes' catalogs against what the change touches.
- **Suggested follow-up:** Add a `validate-specs.py` check that every name in `skills:` resolves to a real skill in either scope — a typo is silent today. Deliberately **not** added as an FR to either framework spec: both rest on split exception E5, which requires zero behavioural code change, and a validator script edit would break that reasoning. It belongs with the already-logged fix for the validator's `__file__`-anchored root (2026-08-13 entry above), since both are the same shape — a checker that cannot see what it implies it checks. More generally, when a spec introduces a new *capability* rather than a change to an existing one, the adoption path is part of the spec: ask "what loads this, and what would fail if nothing did?" before the requirements gate, not after.

### 2026-08-13 — Five recurring failure classes had no framework rule

- **Spec / task:** IMP-20260813-config-and-duplication-rules, T7 closure
- **Category:** `rule-gap`
- **What was found:** The 2026-08-13 review of `tobevisit-content` found five defect classes the framework had never stated a rule for: layered configuration precedence, configuration keys with zero readers, secrets reaching logs, vocabulary drift, and the repeat-fix signal. Coverage was 0/5 — duplication had exactly one clause (`reviewing-changes` dimension 5, naming the symptom without a test for it), and configuration had none at all. The evidence was not subtle: a BUG-20260812 fix copied verbatim into 4 of 8 shape-sharing adapters, a 14-value vocabulary restated across 9 sites with 0 compiler-checked, 4 config keys with no readers (one behind an editable admin screen), 30 unchecked `as` casts on one config document, and a debug branch printing two live API keys to stdout behind a flag the committed env template shipped enabled. Each earlier instance had been diagnosed and fixed locally; none produced a rule, so every recurrence cost the same investigation.
- **What was changed:** coverage taken to 5/5, each with a named canonical location — two skills (`configuring-applications`, `avoiding-duplication`), one always-on rule (`boundaries.md § Always do #16`, registered as R11), the dimension-5 review checklist that makes them catchable where they cost least, both catalogs, and an `authoring-steps.md § A` instruction so future authors pick `skills:` against what the change touches.
- **Suggested follow-up:** The rules are now stated but only gate-checked at self-review (OS-2). If the classes keep recurring in product specs, the next step is mechanical — a dead-config-key check and a vocabulary-derivation check — not more prose.

### 2026-08-13 — The rule map's ID sequence and its phrase matcher both mislead

- **Spec / task:** IMP-20260813-config-and-duplication-rules, T3
- **Category:** `tooling-gap`
- **What was found:** Two independent defects in the canonical-rule machinery, both found only because T3 had to allocate a new rule ID. (1) **The next free `R<N>` cannot be read off the inventory.** `docs/rule-canonical-map.md` ends at `### R8`, so the plan allocated R9 — but R9 and R10 were already assigned by IMP-20260514 as *anchor-only* IDs (R9 = "Continue = one task", R10 = Visualize triggers) and are referenced as such in the header comments of `boundaries.md` and `spec-lifecycle.md`. They carry no `### R<N>` section because they had no tracked phrases, so the inventory silently understates the allocated range by two. The real next ID was R11. (2) **`lint-rules.py` matches phrases per physical line** (`text.splitlines()`), while the canonical files wrap their rules at ~120 characters. A tracked phrase spanning a wrapped line can never match anything — including a genuine copy-paste elsewhere. R1's tracked phrase is one such: it spans a line break in `boundaries.md`, so that entry is inert today. `make lint-rules` reports OK either way, because the linter only reports occurrences *outside* the canonical file — an inert phrase and a well-behaved one produce identical output.
- **What was changed:** R11 used instead of R9; the sibling spec's reservation corrected to #17 / R12 in the same pass; R11's three tracked phrases deliberately chosen as single-line substrings so they actually match. No tooling change — out of scope for a spec resting on split exception E5 (zero behavioural code change).
- **Suggested follow-up:** Two small fixes to `scripts/lint-rules.py`, worth pairing: (a) normalize whitespace before matching, so wrapped phrases work and existing inert entries start earning their keep — expect it to surface real drift on first run; (b) have it assert that every tracked phrase is present in its own canonical file, which converts an inert entry from invisible into a build failure. Add an `R<N>` allocation note to the map header while there, so the next author does not read the last section as the high-water mark. Same shape as the two 2026-08-12/13 validator entries above: a checker whose output cannot distinguish "verified" from "never looked".

### 2026-08-13 — The audit's most dangerous pattern had no framework rule

- **Spec / task:** IMP-20260813-failure-semantics-rules, T6 closure
- **Category:** `rule-gap`
- **What was found:** The 2026-08-13 audit of `tobevisit-content` named one pattern as the single most dangerous one present — a technical failure written as a valid terminal state, after which the backlog query that would retry it stops selecting the record — and found it in four subsystems at once: a Google network error resolving to an empty result and checkpointing a rectangle as processed with zero places; a Wikimedia or R2 failure writing `{gallery: [], enrichedAt}` so the place is permanently "has no photos"; an S3 per-key delete error never read, so the catalog document is removed while the objects survive; an empty batch result standing for six distinct states at once. The same audit found uniqueness enforced only by application queries with no index behind them, `find`-then-`insert` and `hasRunning`-then-`create` races, Mongo writes whose outcome is never read, and long runs re-deriving their settings at completion from a configuration that may have changed. Framework coverage of all seven classes was 0/7. `reviewing-changes` dimension 4 said "logic errors, unhandled edge cases, broken invariants" — true, and too general to catch any of them. Every one is project-agnostic, and none had ever produced a rule, so each recurrence cost a fresh investigation.
- **What was changed:** coverage taken to 7/7, each with a named canonical location — two skills (`handling-external-failures`, `designing-durable-state`), one always-on rule (`boundaries.md § Always do #17`, registered as R12), the dimension-4 review checklist that makes the classes catchable at review, and both skills catalogs. The sibling's two tooling lessons were applied rather than re-learned: R12 was allocated from the *sibling's* corrected sequence (#17 / R12, not the inventory's apparent high-water mark), and all three tracked phrases were verified to sit on a single physical line of `boundaries.md` before closure, so none of them landed inert the way R1's did.
- **Suggested follow-up:** Same shape as the sibling's — the rules are stated but only gate-checked at self-review (OS-3). The two classes worth mechanizing first are the ones with an unambiguous signature: a `catch` block whose body writes a completion field, and an update-or-delete-by-identity whose result is discarded. Both are grep-shaped in a way "is this duplication?" never was. Until then, the two skills only reach a spec that names them in `skills:` — the `tobevisit-content` remediation specs from the same audit are the first readers, and the check that this rule set is real is whether those specs' reviews cite dimension 4 by its new bullets.

### 2026-08-20 — A citation format that cannot survive its own source

- **Spec / task:** IMP-20260820-figma-screenshot-durability-and-file-versioning / T7
- **Category:** anti-pattern
- **What was found:** The Visualize sub-step told the agent to "embed screenshots" from Figma, but the MCP tools that produce those URLs state plainly that they are short-lived (`get_screenshot` — "short-lived URL"; `download_assets` — "URLs are temporary"). The instruction and the tool contract contradicted each other, and nothing in the framework noticed for months: 49 dead image links accumulated across 12 archived specs, every sampled one returning 404. The markup made the decay unrecoverable — a bare image with the node link on a separate line as inline code, so a dead URL left no clickable path back to the frame. A second, independent defect hid underneath: node links resolve against a *live* file, so closed specs illustrated their design with whatever the file looked like later.
- **What was changed:** Frames are now embedded as a link-wrapped image whose alt text is the frame's conventional name, so expiry degrades into a named clickable reference carrying `fileKey` + `node-id` — the exact input needed to regenerate the image. Regeneration moved to the requirements gate, making freshness a property of the process. File versioning added: Visualize asks every run whether to adopt a new key, the successor is the copy (never the archive), and the predecessor is frozen. Recorded in ADR-0002; reference mechanics in `figma-file-organization.md` § 6.
- **Suggested follow-up:** When a prompt instructs the agent to persist anything an external tool returns, check the tool's own description for a lifetime claim before writing the rule — the contradiction here was visible in the tool schema the whole time. Two open items: the per-team Figma file ceiling is still unverified (a copy-per-milestone cadence spends it), and `scripts/validate-specs.py` `check_link_integrity` still matches links inside code spans and fenced blocks, so documenting link syntax requires `https://`-shaped placeholders.

### 2026-08-27 — A safety net that fires on every well-formed cross-cutting spec

- **Spec / task:** IMP-20260826-spec-guard-and-validator-gaps / Plan + T8
- **Category:** `process`
- **What was found:** The Plan-stage safety net P3 ("a task group with zero dependencies on other groups") fired on this spec exactly as T1 had fired at Specify — the guard cluster and the validator cluster share no file and no AC. The mechanical action is to write no tasks and flip back to `specify`, which lands on the same question the human had already answered at the Specify gate with both clusters named. The two checks are the same test run twice, so a recorded override at Specify guarantees a P3 fire at Plan; the prompt gives no way to carry the first decision forward, and the honest options were to force-fit a dependency, flip back into a loop, or stop and ask.
- **What was changed:** stopped at the gate, surfaced P3 with both clusters named, and recorded the human's confirmation in `## Split Decision` alongside the original T1 override. Eight tasks were then written as two independent chains plus a closure task that spans both.
- **Suggested follow-up:** Let `## Split Decision` record an override as *binding on both checks* — if the human elected a shape at Specify with the clusters named, P3 should cite that decision and proceed rather than re-ask. Failing that, `plan-spec.prompt.md` step 3 should say what to do when the fired signal is one the human has already adjudicated, instead of leaving the agent between a forbidden force-fit and a loop.

### 2026-08-27 — Three baseline numbers in a spec body, none of them measured

- **Spec / task:** IMP-20260826-spec-guard-and-validator-gaps / T2, T6, T8
- **Category:** `anti-pattern`
- **What was found:** The spec carried three quantitative claims used as closure targets, and implementing it disproved all three. Its measurable benefit said eight replayed guard collisions go "from 8 denials to 0" — the log's own eighth entry says plainly that occurrence is a genuine sequencing conflict the proposed rules would not fix, so the target is 8 → 1. Its rollout note said `tobevisit-content` was clean for the new REQ-ID check (22 files, 0 collisions); the implemented check finds 15 collisions across 7 files, including six consecutive IDs in one baseline. Its inventory metric read "24 of 28 archived specs"; the archived corpus is 24 specs, of which 2 use the offending form. Each number was plausible, none was produced by running anything, and each would have been asserted as met at closure.
- **What was changed:** all three corrected in the spec body, with the measured figures and how they were obtained recorded under `## Closure Evidence`.
- **Suggested follow-up:** A number in `## Current State`, `## Proposed Improvement` or `## Rollout` is a claim about a corpus, and the corpus is usually one command away at Specify time. Either run the command and cite it, or write the claim as an estimate and say so — "0 collisions today" and "expect this to land green" read identically to a reader deciding whether the work is needed.

### 2026-08-27 — A validator check that passed only because of where the repo was checked out

- **Spec / task:** IMP-20260826-spec-guard-and-validator-gaps / post-closure
- **Category:** `tooling`
- **What was found:** FR-9's check reported inventory paths that do not resolve from the spec's own project root. Two entries in an archived cross-repo spec point into `tobevisit-content`, which has no project-root-relative form, so the shipped version exempted them by walking ancestor directories to see whether the path resolved into some *other* project. That works in this workspace, where `env/ai-dotfiles/` and `src/github.com/tobeverse/` are siblings under one root. CI checks out `ai-dotfiles` on its own: no ancestor holds the sibling repo, the exemption could not fire, and `make validate-specs` failed on exactly the two findings the exemption was written to suppress. Every local run — `make check` included — was green, because the fixture for the exemption built its own sibling directory and so encoded the same assumption as the code.
- **What was changed:** exemption removed. The check now judges **active specs only**, matching what `spec-status-guard.sh` actually reads — an archived spec's inventory leases nothing, so cross-repo entries leave scope with no filesystem probing at all. The test that built a sibling directory was replaced with one asserting an archived spec is not judged. Verified against a copy of the repo with no sibling present.
- **Suggested follow-up:** A check that answers a question about *this* project must not read outside the project root. Where a rule seems to need the surrounding workspace, the rule is usually mis-scoped — here the scope that removed the need was "what the guard reads", which was in the FR's own rationale all along. Practical test before shipping any corpus check: run it against a copy of the repo with nothing beside it, since that is what CI does.

### 2026-08-27 — Correct classification, discarded cause

- **Spec / task:** IMP-20260826-failure-diagnosability / T3 closure
- **Category:** `rule-gap`
- **What was found:** During CR-20260825-catalog-media-studio a Mapillary adapter raised `Mapillary answered 400` and dropped the response body. Every framework rule in play was satisfied: the failure was classified, the class was permanent, and a 400 is permanent. What the process threw away was orthogonal to class — Mapillary had written `Invalid OAuth access token - Cannot parse access token`, which names the cause outright — and recovering that sentence took two rounds of probing the API by hand. `handling-external-failures` said nothing about the provider's own account of a failure, and the silence read as permission to discard it. The same incident exposed the configuration half: the suspect value was inspected by reading `.env.local`, then through a shell pipeline, and both misled in opposite directions — the file read kept quotes `dotenv` strips, the shell probe stripped quotes the loader keeps. The check that settled it imported the settings module and printed the resolved value's length and prefix. `configuring-applications` covered where a value may come from and never said where to look at it, so the obvious move — read the file — was the one that answers a different question.
- **What was changed:** one paragraph in each skill. `handling-external-failures § Three outcomes, not one` now requires the provider's own message stored beside the class, bounded in length, and states plainly that class and cause are different information — only the class is reconstructible from the outcome. `configuring-applications § One validated accessor` now requires a value to be diagnosed where the process reads it, naming the four layers that can make the file and the effective value differ (loader quoting, declared default, store merge, parse function), and says explicitly that the length-and-prefix check it endorses does not relax `§ Secrets never reach a log`. Both carry the incident as their worked example. Both `description:` trigger lists gained the symptom phrasing a reader in this position would actually use — "error body dropped", "only a status code to go on", "env var not taking effect", "wrong config value at runtime" — since a rule reachable only from its own vocabulary is a rule nobody loads mid-incident.
- **Suggested follow-up:** Both halves of this incident are the same shape — a rule that names the *class* of a thing and is silent about the *instance*, where only the instance identifies the cause. Worth a sweep for the same silence elsewhere: a rule that says "record the outcome" without saying what the outcome carries, or "validate at the boundary" without saying what a validation failure reports. Mechanically, the failure half has a grep-shaped signature the duplication rules never had — a `catch` whose stored value references the status code but not the body — and is the first candidate if OS-3's "stated but not gate-checked" gap is ever closed.

### 2026-08-27 — A rule map that never checks its rules still exist

- **Spec / task:** IMP-20260826-ui-surface-closure-evidence / T4
- **Category:** `tooling`
- **What was found:** `lint-rules.py` matches each tracked phrase as a raw substring of a file's full text and skips the phrase's own canonical file, so nothing ever verifies that a tracked phrase is still *present where it is declared canonical*. R3's `spec-lifecycle #5` entry — *"Never flip to `done` while any acceptance criterion lacks documented evidence."* — was line-wrapped in `spec-lifecycle.md` as `documented\n   evidence.`, so the registered string appeared in no file at all, this one included. It could match only a restatement that happened to fit on one source line, and the canonical rule could have been reworded or deleted outright with `make lint-rules` staying green. The map read as an inventory of guarded rules; four of its phrases were guarding nothing.
- **What was changed:** the new R13 rule text in `spec-lifecycle.md § Rules #5` was reflowed so each canonical sentence occupies a single source line, and R13's three phrases were registered in that form. Verified live-fire: pasting the exclusion clause into `docs/acceptance-criteria-patterns.md` produced `rule_duplicate:R13` and a non-zero exit; reverting returned `OK`. R3's wrapped phrase was kept as a revert tripwire and the drifted wording registered beside it.
- **Suggested follow-up:** add a presence check to `lint-rules.py` — every tracked phrase MUST appear in its canonical file, failing otherwise. That one check converts the map from a claim into a guarantee and would have caught this the day the phrase was wrapped. Until it exists, a phrase spanning a line break is silently inert, so register phrases that fit one line and reflow the canonical text when they do not.

### 2026-08-27 — The spec about unfalsifiable evidence shipped an uncounted count

- **Spec / task:** IMP-20260826-ui-surface-closure-evidence / Plan
- **Category:** `anti-pattern`
- **What was found:** The spec's measurable benefit and AC-4 both asserted that four of CR-20260825's nine criteria were observation-shaped, naming AC-1, AC-2, AC-4 and AC-5. Measuring all nine against the rule the spec itself proposes gives five: AC-9's `When` reads *"the operator enters the studio from each"*, naming an operator and a surface as plainly as AC-1's. The number had been written by reading the criteria that were already known to be broken rather than by applying the test to all nine. AC-4 would have failed at closure against its own corrected classification — or, worse, been declared met by restating the number in the spec. Separately, FR-4 carried no acceptance criterion at all, which the FR→AC map surfaced only at Plan.
- **What was changed:** both fixed at Specify before Plan re-ran — AC-4 now requires the deciding clause to be cited per criterion and states the 5/4 partition; AC-5 was added for FR-4. The classification table is in the spec's `## Closure Evidence`.
- **Suggested follow-up:** the FR→AC orphan check runs today only as a human reading `docs/acceptance-criteria-patterns.md` § Coverage checklist. `validate-specs.py` already parses both sections; an orphan check in either direction is a cheap addition and would have caught FR-4 at the requirements gate instead of one stage later.

### 2026-08-27 — A second inert canonical phrase, found by the check that does not exist yet

- **Spec / task:** IMP-20260826-decomposition-and-staleness-procedures / T5, T7
- **Category:** `tooling`
- **What was found:** The 2026-08-27 entry on `lint-rules.py` noted that nothing verifies a tracked phrase is still present where it is declared canonical, and recommended a presence check. Registering R14 and R15 meant running that check by hand, and it caught a second instance immediately: R7's first phrase — the `depends-on:` blocking rule — was line-wrapped in `spec-lifecycle.md § Rules #10` as `(never flip to\n    'plan')`, so the registered string matched no file at all. R7 had been guarding nothing since the wrap. The map reported 11 rules and 35 phrases and looked healthy; two of its entries were decorative. R7's second phrase is inert for a different reason — `plan-spec.prompt.md` says *"No advance to `plan`…"* where the map registers *"Never advance to `plan`…"* — and could not be registered in its current form without failing the linter, since a live restatement is exactly what the map treats as drift.
- **What was changed:** Rule #10 reflowed so its canonical sentence occupies one physical line; the phrase is now present and guarded. R14 and R15 registered with every current-wording phrase verified present via `grep -F` and every revert tripwire verified absent, before closure. Live-fire confirmed both new rules fire on a pasted restatement and return to `OK` on revert.
- **Suggested follow-up:** The presence check is now recommended by two entries and would have caught both instances the day the text wrapped; it is roughly ten lines in `lint-rules.py`. Worth noting what the manual check cannot do — R7's second phrase shows the map has no way to express *"this file restates the rule by design, with a link"*, so a legitimate summarising restatement is either untracked or a lint failure. If the presence check lands, a `link-site` phrase class is the natural companion.

### 2026-08-27 — Re-verification is where the missing requirements were

- **Spec / task:** IMP-20260826-decomposition-and-staleness-procedures / pre-Plan
- **Category:** `process`
- **What was found:** This spec proposed FR-6 — re-verify `## Current State` when the last `depends-on:` closes — and then had to run it on itself, since its dependency reached `done` before it advanced. The re-read found the four documented gaps unchanged and nothing superseded, which is the outcome the rule is usually assumed to produce. The value came from somewhere else: reading the target files end to end surfaced three sites restating the very rules the spec was replacing — `authoring-steps.md § C` step 3, and both the `## Hard rules` cap and the step 3 safety net in `plan-spec.prompt.md`. Shipping FR-1…FR-7 as written would have left `§ C` steps 3 and 5 returning opposite verdicts on one task, and left the file the agent actually reads at Plan contradicting the file it links to. The original FR set was written from the improvements log, which records where a rule *failed*, never where it is *repeated*.
- **What was changed:** FR-8, FR-9, FR-10 and AC-7 added at Specify before Plan ran, with `affected-docs:` widened by three files. AC-7 closes on a corpus grep rather than a claim.
- **Suggested follow-up:** The generalisable half is not about `depends-on:` at all — before changing a rule, grep the corpus for the rule's *current* statement, not just the site the log names. Every rule in `docs/rule-canonical-map.md` exists because a statement was found in more than one place, so a spec that edits a canonical rule and touches exactly one file is making a claim it has not checked. Cheap enough to belong in `authoring-steps.md § A` step 7 as a one-line precondition on any FR whose target is a rule statement.

### 2026-08-30 — the bootstrap manifest described a model the framework had already replaced

- **Spec / task:** IMP-20260830-canonical-scaffold-and-verification-rules
- **Category:** `protocol`
- **What was found:** `boundaries.md § Always do #7` sends every agent to *"the project's agent-instructions file § Build and Run"* — a section `templates/project/_canonical.md` did not have. Pulling that thread found the scaffold manifest two models behind: `_canonical.md` occurred **zero** times across it and `docs/bootstrapping-project.md`, its ten required artifacts omitted the one file a human edits, and it still called `.github/copilot-instructions.md` canonical and `CLAUDE.md` a slim `@`-import. The installed `sync-agents.sh` has meanwhile been rendering all three from `_canonical.md`, which is also what `§ Always do #1` says and what every real project is. The user-visible end of it: `ai-project.sh` finished by printing *"Fill in `<placeholder>` markers in `.github/copilot-instructions.md`"* — pointing the human at a generated file that #1 forbids editing and the next `make sync-agents` silently overwrites. Nothing failed; the scaffold produced a working project and the wrong instruction, and only a hand-run scaffold surfaced it.
- **What was changed:** three project-independent rules moved from one project's `_canonical.md` into `boundaries.md` (#19 read the exit status not the tail, #20 exported-signature changes, #21 no verification step rewrites its source); the two section skeletons added to the project template; the manifest, the guide and the scaffold message corrected to the `_canonical.md` model; the duplicated copies removed from `tobevisit-content`.
- **Suggested follow-up:** the framework has no check that its **documentation about itself** matches its own scripts, and this is the class of drift `docs-check` was built for one level down. Two cheap forms: assert that every path named as an artifact in `scaffold-manifest.md` exists under `templates/project/`, and assert the reverse — every file the scaffold actually copies appears in the manifest. Both are a `find` and a `comm`, and either would have failed the day `_canonical.md` was introduced. Worth pairing with the observation that the only reason this surfaced at all was running `ai-project` into a scratch directory and reading what it printed; the manifest had been wrong for months of sessions that all read it instead.
