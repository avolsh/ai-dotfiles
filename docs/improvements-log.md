# Improvements Log — ai-dotfiles

*Last updated: 2026-05-14*

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
