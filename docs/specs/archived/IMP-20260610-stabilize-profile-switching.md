---
id: IMP-20260610-stabilize-profile-switching
type: IMP
date: 2026-06-10
status: done
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
  - tobevisit-content
  - tobevisit-web
affected-docs:
  - docs/agent-protocol.md
  - docs/ai-agent-framework.md
  - docs/spec-templates-guide.md
  - docs/acceptance-criteria-patterns.md
  - framework/boundaries.md
  - framework/hooks/README.md
affected-code:
  - scripts/lib/profile-links.sh (new)
  - scripts/ai-switch.sh
  - scripts/ai-profile-init.sh
  - scripts/ai-doctor.sh
  - scripts/test/ai-switch.test.sh (new)
  - framework/hooks/test-rerun-guard.sh (new)
  - framework/hooks/stop-build-check.sh (new)
  - framework/hooks/preflight-reminder.sh (new)
  - framework/templates/system/ (adapter updates)
  - profiles/personal/profile.env
  - profiles/work/profile.env
  - Makefile
skills:
  - writing-specs
model-suggestion: default
---
# IMP-20260610-stabilize-profile-switching
*Last updated: 2026-06-12*
## Summary
- **Goal:** Make profile switching boringly reliable so day-to-day product
  development needs no migrations, re-inits, or manual repairs.
- **Scope:** Patch the existing profile model in ai-dotfiles: one shared
  library as the single source of truth for profile wiring (used by switch,
  init, doctor, and tests), teardown paths that always restore what they
  remove, collision-safe linking, a live `.active-manifest` lifecycle, and a
  hermetic test suite for every switch flow. Additionally finish the
  enforcement rollout: the three remaining hooks (test-rerun block,
  Stop-hook build/test check, preflight reminder), the pre-commit rollout
  into tobevisit-content and tobevisit-web, live per-harness hook
  verification, the open improvements-log follow-up sweep, and a 30-day
  framework stability window.
- **Out of scope:** Any architecture change to where CLI user state lives
  (the shared-state sync engine, keychain sync, and CLAUDE_CONFIG_DIR model
  stay as they are); auth/history isolation between profiles remains the
  existing behaviour.
## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 350k-650k |
| Human attention | requirements gate (passed 2026-06-10), plan gate, 10 task Bottom Lines, closure (incl. commit approval); ~5-10 min each |
| Re-Specify tripwire | Plan exceeds 12 tasks (P1); or the sourced-shell constraint of ai-switch.sh makes a shared library unworkable and per-script duplication returns |
## Current State
`ai <profile>` (sourced `scripts/ai-switch.sh`, 765 lines, zero tests) and
`ai-profile-init` each carry their own notion of what a wired profile looks
like, and they have drifted. Incident evidence from 2026-06-10
(`docs/improvements-log.md`, doctor first-run and ai-switch incident entries):

- **D1 — two sources of truth.** `_ai_reset_framework_links_for_tool` links
  `spec-workflows prompts templates skills agents`; `ai-profile-init.sh` now
  additionally links `upstream`, renders hook adapter configs, and merges
  hooks into `claude/settings.json`. Every switch silently undoes the
  init-only parts — `<system>/upstream/` resolution was lost twice in one day.
- **D2 — destructive teardown.** `_ai_remove_profile_symlinks` runs
  `find "$AI_DOTFILES/profiles" -type l -delete` — all symlinks of **all**
  profiles, not just the active one; one observed flow ended without the
  framework links being recreated (24 doctor failures).
- **D3 — real-directory collisions.** Whole-directory `ln -sfn` into a path
  the CLI owns as a real directory (`codex/skills/` holds Codex's own
  `.system/.codex-system-skills.marker`) produces a nested `skills/skills`
  link instead of failing or adapting.
- **D4 — orphaned manifests.** `~/.<tool>/.active-manifest` files were
  written by a code path removed before 2026-05-11; nothing updates them, and
  their `target=` values point at the pre-CLAUDE_CONFIG_DIR layout.
  `ai-doctor.sh` reads them; the live ones had to be archived by hand.

`make doctor` (IMP-20260610-mechanize-framework-guardrails) now detects all
of these — but detection without a correct switch means recurring manual
repair (`ai-profile-init personal` after every switch), which blocks the
return to product work.
## Proposed Improvement
Extract the profile-wiring logic into one shared, idempotent library and make
every entry point (switch, init) converge on it; make teardown restorative
and scoped; guard linking against CLI-owned real directories; give
`.active-manifest` a live writer matching what doctor checks; and pin the
whole lifecycle down with hermetic tests so regressions are caught in
`make check`, not in production sessions.
**Measurable benefit:** doctor-green invariant — after **any** sequence of
`init / switch / re-switch / reset / re-init` in the hermetic fixture,
`ai-doctor` exits 0 (baseline today: switch alone breaks it); plus zero
manual profile repairs needed over the first 7 days of real use (baseline
2026-06-10: 3 manual repairs in one day).
## Requirements
- FR-1: Profile wiring MUST live in a single shared library
  (`scripts/lib/profile-links.sh`): the framework ref list (including
  `upstream`), instruction-file links, hook-adapter rendering, and the
  Claude settings hooks merge. `ai-switch.sh` and `ai-profile-init.sh` MUST
  both call it; neither may carry its own copy of the list. The library MUST
  be safe for both sourced (ai-switch) and executed (init) contexts.
- FR-2: Every teardown path in `ai-switch.sh` MUST be scoped to the active
  profile only and MUST leave that profile fully wired afterwards (or fully
  detached on `--reset`, with re-wiring on the next switch); no flow may end
  with framework links absent while the profile remains active.
- FR-3: Linking MUST NOT clobber or nest into an existing real (non-symlink)
  directory. For CLI-owned real directories (e.g. `codex/skills/`), the
  library MUST fall back to per-entry symlinks inside the directory,
  preserving CLI-owned entries (e.g. `.system/`); any other real-path
  conflict is reported and skipped, never silently nested.
- FR-4: `ai-switch.sh` MUST write `~/.<tool>/.active-manifest` on every
  switch (profile, target instruction path, timestamp) and remove it on
  `--reset`; `ai-doctor.sh` MUST validate exactly the fields the switch
  writes. Orphaned manifests from the pre-CLAUDE_CONFIG_DIR era are deleted
  by the migration step.
- FR-5: A hermetic test suite (`scripts/test/ai-switch.test.sh`, fixture
  `HOME` + `AI_DOTFILES`, never touching real tool homes) MUST cover:
  init→switch, switch→switch (same and other profile), switch→reset,
  reset→switch, double init; after every sequence `ai-doctor` MUST exit 0
  (or report the documented fully-detached state after `--reset`). The suite
  MUST be wired into `make tests` (and therefore `make check`).
  **Characterization-first ordering:** the suite is written and green
  against the **unmodified** ai-switch.sh *before* any refactoring task may
  start; every later task keeps it green. **Session-preservation
  invariants** are first-class assertions in every sequence, **per tool**:
  (a) fixture session state planted in each shared home survives
  byte-identical — Claude: `projects/<p>/session.jsonl`, `history.jsonl`,
  `.credentials.json`; Codex: `sessions/<rollout>.jsonl`, `history.jsonl`,
  `auth.json`, `goals_1.sqlite`, `.codex-global-state.json`; Copilot:
  `session-state/<f>`, `session-store.db`, `command-history-state.json`,
  `config.json`; (b) the atomic-rename scenario — a CLI replaced a
  shared-state symlink with a real file containing data (observed in the
  wild as `~/.codex/*.bak.tmp-*` remnants) — ends with that data merged
  back, never stranded or deleted, exercised for each tool; (c)
  `.claude.json` JSON-merge keeps both home and profile keys; (d) binary
  state (`*.sqlite`, `*.db`) is asserted by checksum — partial restores
  corrupt SQLite silently.
- FR-6: `profile.env` consumption in the switch MUST be reduced to
  `AI_PROFILE` (model/backend pins removed from the personal and work
  profile.env files); docs (`agent-protocol.md`, `ai-agent-framework.md`)
  MUST reflect the final wiring contract and manifest lifecycle. This
  explicitly includes reconciling `agent-protocol.md § Two-scope model` with
  reality (it currently describes per-entry symlinks inside
  `~/.{claude,copilot,codex}/`, while the implementation uses
  `CLAUDE_CONFIG_DIR`-style profile dirs) and documenting that
  `profiles/<p>/claude/settings.json` may be a symlink into
  `~/.claude/settings.json`, so the hooks merge writes through to user-level
  settings and MUST stay idempotent and non-clobbering.
- FR-7: The canonical hook set MUST grow by three scripts in
  `framework/hooks/` with self-tests and adapter wiring on all three
  harnesses: (a) `test-rerun-guard` — PreToolUse on shell test commands,
  denying a re-run when the worktree hash is unchanged since the last run
  (boundaries § Never #7); (b) `stop-build-check` — Stop/agentStop hook
  reminding when code was edited but no build/test command ran in the
  session (boundaries § Always #7; advisory, never blocking exit); (c)
  `preflight-reminder` — first code edit in a session without a posted
  preflight proof injects a reminder (boundaries § Always #4; advisory).
- FR-8: Both product repos (tobevisit-content, tobevisit-web) MUST get the
  commit-time backstop: `core.hooksPath` (or an equivalent installed hook)
  pointing at the shared pre-commit, verified by a planted-secret rejection
  test run in each repo; their agent-instructions files MUST mention the
  backstop and how to bypass the stamp check. Project-level hook configs are
  NOT duplicated per repo — harness hooks stay profile-level
  (`ai-profile-init`), so the rollout adds no per-repo drift surface.
- FR-9: Hook wiring MUST be verified **live** on each harness, not only at
  contract level: one scripted non-interactive run per CLI (Claude Code,
  `codex exec`, `copilot -p`) in a fixture project with a `specify`-status
  spec, demonstrating (a) the PreToolUse guard denies the governed edit and
  (b) SessionStart runs `ai doctor --fast`. If a CLI's real payload shape
  differs from the documented one, the canonical extractor is fixed in the
  same task. Recorded output is closure evidence.
- FR-10: Every open "Suggested follow-up" in `docs/improvements-log.md`
  MUST be closed or explicitly rejected in this spec: (a) document the
  `docs/specs/archived/artifacts/` convention in
  `docs/spec-templates-guide.md`; (b) add the runtime-assembled-fixture
  pattern note to `framework/hooks/README.md § Tests`; (c) verify the
  "artifact-exists over ≥N" guidance landed in
  `docs/acceptance-criteria-patterns.md` (add it if absent); (d) confirm the
  ai-switch follow-ups are subsumed by FR-1..4. The closure summary lists
  each follow-up with its disposition.
- FR-11: A 30-day framework stability window MUST be codified: one "Ask
  first" bullet in `framework/boundaries.md` stating that after this spec
  closes, framework-scope changes are limited to Direct-lane fixes (or an
  explicit owner waiver) until the window ends; the window end date and the
  `make spec-metrics` review at that date are named in the bullet.
- FR-12: The diff of this spec MUST NOT modify the shared-state engine. All
  ten functions verified present at HEAD — `_ai_link_shared_state`,
  `_ai_link_shared_state_for_tool`, `_ai_link_shared_state_source`,
  `_ai_restore_shared_state`, `_ai_restore_shared_state_for_tool`,
  `_ai_restore_path`, `_ai_merge_json_into`, `_ai_sync_claude_keychain`,
  `_ai_sync_claude_keychain_back`, `_ai_guard_running` — stay byte-identical
  (verified by `git diff` over their bodies). Where FR-2 needs different
  teardown scoping, it adds a **new** scoped function and changes only the
  call sites; the legacy function is deleted only if it has zero remaining
  callers — never edited in place.
## Acceptance Criteria
### AC-1: Single source of truth (FR-1)
Given the shared library is in place
When `grep` searches `ai-switch.sh` and `ai-profile-init.sh` for the
framework ref list or hook-rendering logic
Then each appears exactly once, in `scripts/lib/profile-links.sh`, and both
entry points call it (evidence: grep output + both flows green in AC-5 suite).
### AC-2: Switch never un-wires a profile (FR-2)
Given a fully initialized fixture profile
When `ai <profile>` runs twice in a row, and separately `ai --reset` then
`ai <profile>` runs
Then after each sequence `ai-doctor` exits 0, and after `--reset` alone the
profile is fully detached with no half-wired remnants
And the measurable benefit is verified: the doctor-green invariant holds for
every sequence in the suite.
### AC-3: Real-directory collision safety (FR-3)
Given a fixture where `codex/skills/` is a real directory containing
`.system/marker`
When the library wires the profile
Then `.system/marker` is preserved, per-entry links to framework skills
appear inside `codex/skills/`, and no nested `skills/skills` path exists.
### AC-4: Live manifest lifecycle (FR-4)
Given a fixture switch
When `ai <profile>` completes
Then `~/.<tool>/.active-manifest` exists with the documented fields and
`ai-doctor` validates it; after `ai --reset` the manifest is gone; planting a
pre-migration orphan manifest and running the migration step removes it.
### AC-5: Hermetic suite in CI (FR-5)
Given `make tests`
When the suite runs on a clean checkout
Then all switch-flow scenarios pass without touching the real `$HOME`, and a
deliberately re-introduced D1 regression (removing `upstream` from the ref
list) fails the suite.
### AC-6: Reduced env + docs (FR-6)
Given the merged change
When `profile.env` files are inspected and the docs are read
Then only `AI_PROFILE` is exported by profile.env, and
`agent-protocol.md` / `ai-agent-framework.md` describe the final contract
(refs incl. upstream, hook adapters, manifest fields, doctor checks).
### AC-7: Remaining hooks live (FR-7)
Given the three new hook scripts and re-rendered adapters
When (a) the same test command runs twice with no worktree change, (b) a
session with code edits stops without a build/test run, (c) a first code
edit lands with no preflight proof posted
Then (a) is denied citing the unchanged tree, (b) and (c) produce visible
advisory output without blocking, and each script's self-tests pass in
`make tests`.
### AC-8: Product repos protected (FR-8)
Given tobevisit-content and tobevisit-web after rollout
When a commit with a planted dummy secret is attempted in each repo
Then the pre-commit backstop rejects it citing the file, a clean commit
passes, and each repo's agent-instructions file documents the backstop.
### AC-9: Live per-harness proof (FR-9)
Given a fixture project with a `specify`-status spec
When each CLI runs the scripted scenario non-interactively
Then each transcript shows the guard's deny message and the doctor
SessionStart line; any payload-shape fix is covered by an added extractor
test in `hooks.test.sh`.
### AC-10: Follow-up ledger clean (FR-10)
Given the closure summary
When every "Suggested follow-up" in `docs/improvements-log.md` is checked
Then each is listed as done (with the diff path) or rejected (with one-line
reason), and none remains unaddressed.
### AC-11: Stability window codified (FR-11)
Given the merged boundaries change
When `framework/boundaries.md § Ask first` is read
Then the window bullet names the end date (closure + 30 days) and the
spec-metrics review, and `make lint-rules` passes.
### AC-12: Sessions provably untouched (FR-5, FR-12)
Given the full diff of this spec
When the shared-state function bodies are compared against the pre-spec
revision and the characterization suite runs
Then every listed function is byte-identical (diff evidence in closure),
the planted-session and atomic-rename invariants pass in every sequence,
and the cold reviewer sub-step (mandatory for this spec, medium risk)
returns PASS on exactly this clause before the closure gate is requested.
## Architecture
Skipped — convergence refactor of existing scripts onto a shared library;
no new bounded context, no schema change, model unchanged
(CLAUDE_CONFIG_DIR → profile dirs, shared-state sync untouched).
## Out of Scope
- OS-1: Architecture inversion (framework overlay into native tool homes) —
  rejected at Specify: owner requires auth/history isolation semantics to
  stay untouched.
- OS-2: Changes to the shared-state sync engine, keychain sync, launchctl
  handling, or `_ai_guard_running` beyond what FR-2 scoping requires.
- OS-3: Multi-account/per-profile credential features beyond today's
  behaviour.
- OS-4: CI pipelines inside the product repos (the backstop is local
  pre-commit; repo CI changes are their own concern).
## Split Decision
Triggers fire on two axes: T1 (manifest lifecycle, hook extensions, doc
sweeps, and the link library are separately testable) and T3 (FR-8 targets
tobevisit-content/tobevisit-web while FR-1..7 and FR-9..12 target
ai-dotfiles). Exceptions E2 and E3 cover the FR-1/FR-2/FR-3/FR-5/FR-12 core
(one acceptance surface — the hermetic switch suite asserts them per
sequence; atomic rollback of the library convergence). FR-9 verifies FR-7's
artifacts (same surface); FR-10/FR-11 are documentation rows under the same
closure metric. For FR-7/FR-8 no exception cleanly applies; **owner override
(2026-06-10, reconfirmed after FR-9..12 extension): keep as one IMP** — the
explicit goal is "return to product development with zero leftovers", and
FR-8 is operationally a per-repo install-and-verify of an artifact FR-7's
repo already ships (shared closure narrative, one review pass). Guard: P1
(>12 tasks) re-opens this decision.
## Tasks
> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Characterization suite vs **unmodified** ai-switch (FR-5, FR-12 baseline): hermetic HOME+AI_DOTFILES fixtures; sequences init→switch, switch×2 (same/other profile), switch→reset, reset→switch, double-init; per-tool session invariants (planted Claude/Codex/Copilot state byte-identical, sqlite/db by checksum), atomic-rename merge, `.claude.json` merge. Session invariants MUST pass at HEAD; doctor-green assertions land disabled with the current failures recorded as baseline (enabled in T3). Record FR-12 function-body hashes. | `scripts/test/ai-switch.test.sh` *(new)*, `Makefile` | `scripts/ai-switch.sh`, `scripts/ai-profile-init.sh`, `scripts/ai-doctor.sh` | — | — | deep | ✅ done (2026-06-10) |
| T2 | Shared wiring library (FR-1, FR-3): extract ref list (incl. `upstream`), instruction links, adapter rendering, settings hooks merge into `scripts/lib/profile-links.sh`; per-entry fallback for CLI-owned real dirs (`codex/skills/.system` preserved); `ai-profile-init.sh` converges on it; sourced+executed safe (no file-scope `set -e`). | `scripts/lib/profile-links.sh` *(new)*, `scripts/ai-profile-init.sh`, `scripts/test/profile-links.test.sh` *(new)*, `Makefile` | `framework/hooks/README.md`, `scripts/ai-switch.sh` | T1 | — | default | ✅ done (2026-06-10) |
| T3 | Switch convergence (FR-1, FR-2, FR-4, FR-12): ai-switch calls the library; new active-profile-scoped teardown replaces `_ai_remove_profile_symlinks` call sites (legacy deleted only at zero callers); manifest written on switch / removed on reset; `ai-doctor.sh` validates exactly those fields; enable doctor-green assertions in the T1 suite; verify FR-12 hashes unchanged. | `scripts/ai-switch.sh`, `scripts/ai-doctor.sh`, `scripts/test/ai-switch.test.sh` | `scripts/lib/profile-links.sh` | T2 | — | deep | ✅ done (2026-06-11) |
| T4 | Env + docs reconciliation (FR-6): profile.env files reduced to `AI_PROFILE`; `agent-protocol.md § Two-scope` matched to the implemented model (CLAUDE_CONFIG_DIR profile dirs; settings.json write-through documented); cheat-sheet rows refreshed. | `profiles/personal/profile.env`, `profiles/work/profile.env`, `docs/agent-protocol.md`, `docs/ai-agent-framework.md` | `scripts/lib/profile-links.sh` | T3 | writing-docs | fast | ✅ done (2026-06-11) |
| T5 | Three remaining hooks + self-tests (FR-7): `test-rerun-guard` (deny on unchanged worktree hash), `stop-build-check` (advisory), `preflight-reminder` (advisory); extend hooks test suite. | `framework/hooks/test-rerun-guard.sh` *(new)*, `framework/hooks/stop-build-check.sh` *(new)*, `framework/hooks/preflight-reminder.sh` *(new)*, `framework/scripts/test/hooks.test.sh` | `framework/hooks/spec-status-guard.sh`, `framework/boundaries.md` | — | — | default | ✅ done (2026-06-11) |
| T6 | Adapter wiring for the new hooks (FR-7): extend the three harness templates; re-render via the T2 library; verify rendered JSON validity. | `framework/templates/system/claude/hooks.json`, `framework/templates/system/codex/hooks.json`, `framework/templates/system/copilot/copilot-cli-policy.json` | `scripts/lib/profile-links.sh`, `framework/hooks/` | T2, T5 | — | default | ✅ done (2026-06-11) |
| T7 | Live per-harness verification (FR-9): scripted `claude -p` / `codex exec` / `copilot -p` runs in a fixture project with a `specify` spec; capture deny + SessionStart doctor lines; fix canonical extractors on payload-shape mismatch with added tests; document Codex project-trust step. | `framework/hooks/spec-status-guard.sh`, `framework/hooks/stamp-refresh.sh`, `framework/scripts/test/hooks.test.sh`, this spec *(evidence)* | rendered adapters in `profiles/personal/` | T3, T6 | — | default | ✅ done (2026-06-11) — Codex partial, see Closure Evidence |
| T8 | Product repo rollout (FR-8): in tobevisit-content and tobevisit-web — install the pre-commit backstop (`core.hooksPath` to the shared dir), planted-secret rejection + clean-commit verification, backstop note in each repo's canonical agent-instructions (+ `make sync-agents` re-render). | `tobevisit-content` canonical agent file *(+renders)*, `tobevisit-web` canonical agent file *(+renders)* | `scripts/git-hooks/pre-commit` | T1 | — | fast | ✅ done (2026-06-11) |
| T9 | Docs sweep (FR-10, FR-11): `archived/artifacts/` convention in spec-templates-guide; runtime-assembled-fixture note in hooks README; verify/add "artifact-exists over ≥N" in acceptance-criteria-patterns; 30-day stability-window bullet in boundaries § Ask first (end date + spec-metrics review). | `docs/spec-templates-guide.md`, `framework/hooks/README.md`, `docs/acceptance-criteria-patterns.md`, `framework/boundaries.md` | `docs/improvements-log.md` | — | writing-docs | fast | ✅ done (2026-06-11) |
| T10 | Closure (all ACs, AC-12 mandatory reviewer): cold reviewer PASS on the FR-12 clause; FR-12 diff evidence; live migration (`ai personal`, doctor green, delete stale manifests); follow-up ledger dispositions (AC-10); improvements-log entry; owner-approved commit of the full staged state; flip `done`, archive. | this spec, `docs/improvements-log.md` | all task outputs | T1–T9 | writing-specs | default | ✅ done (2026-06-12) |
## Closure Evidence

- **AC-1 (single source of truth):** ref list (incl. `upstream`) exists once,
  at `scripts/lib/profile-links.sh` (`AI_LINKS_REFS`); both entry points
  source the library (reviewer-verified line refs: ai-switch.sh:707,
  ai-profile-init.sh:59); zero duplicate lists by grep.
- **AC-2 (switch never un-wires):** `ai-switch.test.sh` STRICT=1 green over
  all six sequences; live D1 reproduction during T3 (old on-disk code lost
  `upstream` mid-task) vs new code surviving reset→switch on a copy of the
  real personal profile.
- **AC-3 (collision safety):** `profile-links.test.sh` cases 5–6 (real
  `codex/skills` with `.system/marker` preserved, per-entry links, no
  nested `skills/skills`, shadowing entry kept + reported); live re-init
  on the real profile preserved Codex's `.system`.
- **AC-4 (manifest lifecycle):** suite asserts presence+fields after switch
  and absence after reset; live `ai --force personal` (2026-06-12) wrote
  `profile=personal`, resolving `target=`, timestamp; stale 2026-05-11
  orphans deleted; doctor green before and after.
- **AC-5 (hermetic suite in CI):** wired into `make tests`/`make check`;
  mutation test: removing `upstream` from the library ref list failed the
  suite on 4 assertions (recorded in session, 2026-06-11).
- **AC-6 (env + docs):** both profile.env files export only `AI_PROFILE`
  (stale `ANTHROPIC_MODEL=claude-sonnet-4-6` pins removed);
  `agent-protocol.md` `<system>/` prefix row, § Two-scope System row, and
  Context-loading §1 rewritten to the implemented model; write-through
  `settings.json` documented.
- **AC-7 (remaining hooks):** `test-rerun-guard` (deny, FORCE_TEST_RERUN
  override), `stop-build-check` + `preflight-reminder` (advisory, rc=0,
  fail-open) — 14 new assertions in hooks.test.sh; wired in all three
  adapter templates.
- **AC-8 (product repos):** `core.hooksPath` set in both repos (owner) and
  verified on local clones: planted `AKIA…` secret rejected citing the
  file, clean commit passes — both tobevisit-content and tobevisit-web
  (2026-06-12); backstop bullet present in both `_canonical.md` § Boundaries
  (+3 renders each, owner-authored).
- **AC-9 (live per-harness proof):** **Claude** — PreToolUse denied this
  session's own Edit of a governed fixture file (verbatim guard message in
  transcript) and SessionStart printed `ai-doctor … OK ✓` on resume.
  **Copilot** — live deny: agent relayed "The file cannot be edited because
  it is governed by a spec that is currently in the 'specify' status",
  `Changes +0 -0`; required two extractor/adapter fixes (see Divergences in
  T7 Bottom Line): `toolArgs` JSON-string parsing in all four guards
  (+unit test) and `adapters/copilot-pretooluse.sh` translating exit-2 to
  `permissionDecision: deny` (Copilot 1.0.46 ignores exit codes — verified
  by an always-exit-2 probe). **Codex** — partial: hooks.json valid in both
  CODEX_HOME and `~/.codex`, but codex-cli 0.139 did not execute hooks in
  `exec` mode even with `--dangerously-bypass-hook-trust` (catch-all probe
  silent; trust prompt hangs non-interactively). Pending owner's one-time
  interactive `codex` trust grant; until then Codex is covered by the git
  pre-commit backstop. Accepted at closure as a documented limitation.
- **AC-10 (follow-up ledger):** (a) `archived/artifacts/` documented in
  spec-templates-guide.md ✓; (b) runtime-assembled-fixture pattern in
  hooks/README.md § Tests ✓; (c) artifact-exists-over-≥N row added to
  acceptance-criteria-patterns.md § Common mistakes (was absent) ✓;
  (d) ai-switch follow-ups subsumed by FR-1..4 ✓. No open follow-ups
  remain unaddressed.
- **AC-11 (stability window):** boundaries § Ask first #6, end date
  2026-07-12 (closure + 30 days), `make spec-metrics` review named;
  `make lint-rules` OK.
- **AC-12 (sessions untouched):** cold reviewer verdict **PASS** —
  per-function SHA-256 of all ten shared-state bodies identical to the
  pre-spec revision; legacy functions deleted with zero call sites;
  characterization suite (incl. per-tool session byte-identity and
  atomic-rename merge) green throughout. Live confirmation:
  `_ai_guard_running` correctly refused the closure-time switch under a
  running CLI until `--force`.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
`ai-switch.sh` is **sourced** into the user's interactive shell: the library
must not `set -euo pipefail` at file scope, must not leak functions/vars
beyond the documented set, and must keep the existing `unset -f` discipline.
## Docs updates required
- `docs/agent-protocol.md` — final wiring contract (refs, adapters, manifest
  fields) in § Two-scope model / § Mechanical enforcement.
- `docs/ai-agent-framework.md` — sync cheat-sheet rows if commands change.
- `docs/improvements-log.md` — closure entry.
## Rollout / migration notes
- One-time migration at closure: run the real `ai personal` once; verify
  `make doctor` green on the live profile; delete archived orphan manifests
  (`~/.claude/.active-manifest.stale-20260511`, copilot counterpart) after
  the new writer proves itself.
- Closure includes committing the full staged ai-dotfiles state (this spec's
  work plus the prior session's submodules and guardrails work) — owner
  approval for the commit is part of the closure gate.
- Codex project-scoped hooks require one-time project trust; document during
  FR-9 verification.
- Revert path: the library is additive — reverting restores today's two-copy
  behaviour; no data migration involved. FR-8 reverts per repo by unsetting
  `core.hooksPath`.
- Supersedes the spawned background task "Fix ai-switch.sh framework-link
  lifecycle" (dismiss the chip — it cannot be withdrawn programmatically
  after the app restart).
- After closure: the FR-11 stability window applies — the next framework
  spec is expected no earlier than the window end; product work
  (tobevisit-web / tobevisit-content CRs) proceeds normally.
