---
id: IMP-20260610-mechanize-framework-guardrails
type: IMP
date: 2026-06-10
status: done
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/boundaries.md
  - framework/spec-workflows/spec-lifecycle.md
  - docs/agent-protocol.md
  - docs/ai-agent-framework.md
  - docs/spec-workflow-guide.md
affected-code:
  - framework/hooks/ (new)
  - framework/templates/system/ (per-tool hook-config rendering)
  - scripts/ai-doctor.sh (new)
  - scripts/git-hooks/pre-commit (new)
  - scripts/spec-metrics.py (new)
  - Makefile
skills:
  - writing-specs
model-suggestion: default
---
# IMP-20260610-mechanize-framework-guardrails
*Last updated: 2026-06-10*
## Summary
- **Goal:** Move the highest-leverage prose-enforced framework rules into mechanical
  enforcement that works on all three harnesses, and codify the two process
  relief valves (Direct lane, review-after closure) the practice already uses informally.
- **Scope:** ai-dotfiles only. Canonical hook scripts with per-harness adapters
  (Claude Code, Copilot CLI, Codex CLI) for three rules; a git pre-commit backstop
  for harnesses without CLI hooks; an `ai doctor` profile-invariant check wired to
  SessionStart; a codified Direct lane; a review-after closure gate for low-risk
  specs; and a spec-corpus metric script (framework-vs-product share).
- **Out of scope:** Rolling hook configs out into tobevisit-content / tobevisit-web
  (follow-up), and mechanizing rules beyond the three named in FR-1.
## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 300k-600k |
| Human attention | requirements gate (passed 2026-06-10), plan gate, 7 task Bottom Lines, closure; ~5-10 min each |
| Re-Specify tripwire | Plan exceeds 12 tasks (P1); or harness hook APIs diverge so far that canonical scripts cannot be shared and per-tool forks are required |
## Current State
Most behavioural rules in `framework/boundaries.md` are prose-enforced: they hold
only if the agent reads and obeys them. Mechanical enforcement exists for artifacts
(`validate-specs`, `lint-rules`, `validate-anchors`) but not for in-session agent
behaviour. Evidence of the gap:
- `docs/improvements-log.md` records repeated rule violations that tooling later
  had to catch (stale anchors, stale premises).
- The "owner-approved direct edit" practice appears in the improvements log but has
  no home in `boundaries.md` or `spec-lifecycle.md` — rules and practice have diverged.
- Profile-symlink breakage is invisible until an agent silently fails to resolve a
  path: `~/.claude/upstream` was absent ("intentionally broken") for weeks with no
  signal.
- Every closure gate is synchronous; low-risk closures wait on the owner the same
  as high-risk ones.
- No measurement exists for how much spec throughput the framework consumes for
  itself versus product work.

All three harnesses now support lifecycle hooks: Claude Code natively; Copilot CLI
via `.github/hooks/` policy files (`preToolUse`, `sessionStart`, GA 2026); Codex CLI
via `hooks.json` / `config.toml` (`PreToolUse`, `SessionStart`, `Stop`; project-scoped
hooks require project trust). Hook payloads are JSON on stdin in all three, so one
canonical script per rule with thin per-tool adapter configs is feasible — the same
canonical-source-plus-rendered-copies pattern the framework already uses for
instruction files.
## Proposed Improvement
Mechanize the three highest-leverage rules as cross-harness hooks, add a git
pre-commit backstop for IDE agents without CLI hooks, make profile breakage
self-announcing via `ai doctor` + SessionStart, and codify the Direct lane and
review-after closure so written rules match actual practice.
**Measurable benefit:** boundaries rules with mechanical enforcement on all three
harnesses: baseline 0 → target 3; profile invariants checked automatically at
session start: baseline 0% → target 100% of `.active-manifest` entries; the
direct-edit practice has a canonical rule home (baseline: none).
## Requirements
- FR-1: The framework MUST provide canonical hook scripts (single source under
  `framework/hooks/`) enforcing three rules — (a) block code edits while the
  governing spec's status is `specify` or `plan`, (b) block commits containing
  secrets, (c) auto-refresh the `*Last updated:*` stamp on edited Markdown docs —
  each invokable unmodified by Claude Code, Copilot CLI, and Codex CLI through
  thin per-tool adapter configs rendered by `ai-profile-init`.
- FR-2: The framework MUST install a git pre-commit hook (via `core.hooksPath` or
  an equivalent rendered mechanism) that runs the secrets scan and
  `make validate-specs` / stamp checks, so rules from FR-1(b–c) hold for agents
  that bypass CLI hooks (e.g., IDE-embedded Copilot).
- FR-3: The framework MUST provide an `ai doctor` command that verifies active-profile
  invariants — every `.active-manifest` symlink resolves, `<system>/upstream/`
  resolves, tool homes exist — exits non-zero on any failure, and is wired to the
  SessionStart hook of all three harnesses in fast (manifest-only) mode.
- FR-4: `boundaries.md` and `spec-lifecycle.md` MUST define a Direct lane: changes
  of ≤2 files and ≤30 changed lines with no schema, prompt, boundary, or cross-repo
  impact MAY ship without a spec, requiring only a Bottom Line post and an
  improvements-log entry; anything beyond the threshold falls back to the Trivial
  or standard lane.
- FR-5: `spec-lifecycle.md` MUST define a review-after closure gate: specs with
  `risk: low` or `risk: trivial` MAY flip `done` and archive immediately after all
  ACs have evidence, with the owner reviewing closures in batch afterwards and an
  explicit revert path; requirements and plan gates remain blocking for all lanes.
- FR-6: The framework MUST provide a metric script (wired as a Make target) that
  reports, from `docs/specs/archived/` across the workspace, the monthly share of
  framework-targeted specs versus product-targeted specs, so meta-work gravity is
  observable.
## Acceptance Criteria
### AC-1: Cross-harness rule enforcement (FR-1)
Given a project with an active spec at `status: specify` and an agent session on any
of the three harnesses with rendered adapter configs
When the agent attempts to edit a file listed under the spec's `affected-code`
Then the PreToolUse hook denies the edit with a message naming the spec and required
status, and the same canonical script file is the one invoked on all three harnesses
And the measurable benefit is verified: 3 rules enforced mechanically, demonstrated
once per harness (recorded command output in closure evidence).
### AC-2: Pre-commit backstop (FR-2)
Given a working tree containing a file with a planted dummy secret
When `git commit` runs from any client (terminal or IDE)
Then the commit is rejected by the pre-commit hook with the secret's location, and
committing a doc with a stale `*Last updated:*` stamp is likewise rejected.
### AC-3: Self-announcing profile breakage (FR-3)
Given an active profile with one `.active-manifest` symlink deliberately broken
When a new agent session starts (or `ai doctor` runs directly)
Then the broken link is reported with its expected target and the doctor exits
non-zero; with the link restored, doctor exits zero
And the measurable benefit is verified: 100% of manifest entries checked.
### AC-4: Direct lane codified (FR-4)
Given the updated `boundaries.md` and `spec-lifecycle.md`
When an owner-approved change of ≤2 files / ≤30 lines with no schema, prompt,
boundary, or cross-repo impact ships
Then the rules name this lane explicitly (threshold, exclusions, Bottom Line +
improvements-log obligations), and `make validate-specs` and `make lint-rules` pass
on the updated corpus.
### AC-5: Review-after closure (FR-5)
Given a `risk: low` spec with documented evidence for every AC
When the agent flips it to `done` and archives it without a synchronous closure
approval
Then the lifecycle rules permit this for low/trivial risk only, the batch-review
obligation and revert path are stated, and blocking gates for requirements and plan
are unchanged.
### AC-6: Meta-share metric (FR-6)
Given the existing archived spec corpus
When the metric target runs
Then it prints per-month counts and the framework-vs-product share, classifying
specs by `affected-repos` (ai-dotfiles → framework; product repos → product), and
the current baseline is recorded in the closure evidence.
## Architecture
Skipped — infrastructure retrofit reusing the established canonical-source →
rendered-copies pattern (`_canonical.md` → three instruction files) for hook
scripts → per-tool adapter configs; no new bounded context, no schema change.
## Out of Scope
- OS-1: Rolling hook/pre-commit configs into tobevisit-content and tobevisit-web —
  separate follow-up after the mechanism stabilizes in ai-dotfiles.
- OS-2: Mechanizing the remaining prose rules (test-rerun block, Stop-hook
  build/test check, preflight reminder) — follow-up after the first three prove out.
- OS-3: Any change to requirements/plan gate semantics — both remain blocking.
- OS-4: CI-side enforcement beyond the existing `make` targets.
## Split Decision
Triggers T1 and T6 fire: the six FRs form ≥2 independently testable clusters
(hooks/doctor mechanics vs lane/gate rule changes vs metric), each verifiable alone;
the owner's separability answer confirmed independent shippability. No keep-as-one
exception (E1–E5) applies. **Owner override (2026-06-10): keep as one IMP** — the
clusters share one closure narrative (closing the rules-vs-practice gap) and one
review pass; per-cluster spec overhead contradicts the IMP's own goal of reducing
ceremony. Guard: if Plan produces >12 tasks, P1 forces a flip back to `specify` and
this decision is revisited.
## Tasks
> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Canonical hook scripts (FR-1): `spec-status-guard` (PreToolUse — deny code edits while the governing spec is at `specify`/`plan`), `secrets-scan` (block commits with secrets), `stamp-refresh` (PostToolUse — refresh `*Last updated:*` on edited `.md`). JSON-on-stdin contract shared by all three harnesses; tests in same task. Feeds AC-1. | `framework/hooks/spec-status-guard.sh` *(new)*, `framework/hooks/secrets-scan.sh` *(new)*, `framework/hooks/stamp-refresh.sh` *(new)*, `framework/hooks/README.md` *(new)*, `framework/scripts/test/hooks.test.sh` *(new)* | `framework/spec-workflows/spec-lifecycle.md`, `docs/improvements-log.md` | — | — | default | ✅ done (2026-06-10) |
| T2 | `ai doctor` (FR-3): verify every `.active-manifest` symlink resolves, `<system>/upstream/` resolves, tool homes exist; non-zero exit on failure; fast manifest-only mode for SessionStart; Make target + tests. Feeds AC-3. | `scripts/ai-doctor.sh` *(new)*, `scripts/test/ai-doctor.test.sh` *(new)*, `Makefile` | `scripts/ai-switch.sh`, `scripts/ai-profile-init.sh` | — | — | default | ✅ done (2026-06-10) |
| T3 | Per-harness adapters (FR-1, FR-3): hook-config templates wiring T1 scripts (PreToolUse/PostToolUse) + T2 doctor (SessionStart) for Claude Code, Copilot CLI, Codex CLI; render via `ai-profile-init`; verify one rule end-to-end per harness. Closes AC-1, AC-3. | `framework/templates/system/claude/hooks.json` *(new)*, `framework/templates/system/copilot/copilot-cli-policy.json` *(new)*, `framework/templates/system/codex/hooks.json` *(new)*, `scripts/ai-profile-init.sh` | `framework/hooks/`, `scripts/ai-doctor.sh` | T1, T2 | — | default | ✅ done (2026-06-10) |
| T4 | Git pre-commit backstop (FR-2): pre-commit running secrets-scan + stamp check + `make validate-specs`; installer via `core.hooksPath` that chains rather than clobbers existing hooks; tests with planted dummy secret and stale stamp. Closes AC-2. | `scripts/git-hooks/pre-commit` *(new)*, `scripts/test/pre-commit.test.sh` *(new)*, `Makefile` | `framework/hooks/secrets-scan.sh`, `framework/hooks/stamp-refresh.sh` | T1 | — | default | ✅ done (2026-06-10) |
| T5 | Lane & gate rules (FR-4, FR-5): Direct lane (≤2 files, ≤30 lines, no schema/prompt/boundary/cross-repo; Bottom Line + improvements-log mandatory) in `boundaries.md` + `spec-lifecycle.md`; review-after closure for `risk: low`/`trivial` with batch-review obligation and revert path; update the three overview docs. Closes AC-4, AC-5. | `framework/boundaries.md`, `framework/spec-workflows/spec-lifecycle.md`, `docs/agent-protocol.md`, `docs/ai-agent-framework.md`, `docs/spec-workflow-guide.md` | `docs/rule-canonical-map.md`, `framework/spec-workflows/questions/trivial-questions.md` | — | writing-docs | default | ✅ done (2026-06-10) |
| T6 | Meta-share metric (FR-6): `spec-metrics.py` reporting monthly framework-vs-product spec share from `docs/specs/archived/` (classified by `affected-repos`); Make target; record current baseline; tests. Closes AC-6. | `scripts/spec-metrics.py` *(new)*, `scripts/test/spec-metrics.test.sh` *(new)*, `Makefile` | `docs/specs/archived/`, `scripts/validate-specs.py` | — | — | fast | ✅ done (2026-06-10) |
| T7 | Closure: run every AC end-to-end, collect evidence per AC, `make check` + `validate-specs` + `lint-rules` + `sync-agents-check` green, improvements-log entry, refresh `## Summary` if scope drifted, flip `done`, archive. | `docs/specs/active/IMP-20260610-mechanize-framework-guardrails.md`, `docs/improvements-log.md` | all task outputs | T1–T6 | writing-specs | default | ✅ done (2026-06-10) |
## Closure Evidence

- **AC-1 (cross-harness rule enforcement):** `framework/scripts/test/hooks.test.sh`
  — 12 assertions green (deny at `specify` naming the spec, allow at
  `in-progress`/ungoverned/spec-self, fail-open on malformed payload).
  Per-harness demonstration (recorded in session, 2026-06-10): the same
  `spec-status-guard.sh` denied with rc=2 under the Claude Code payload
  (`tool_input.file_path`), the Codex payload (`tool_input.path`,
  `apply_patch`), and the Copilot camelCase payload (`toolInput.filePath`).
  Rendered adapters are valid JSON with `@AI_DOTFILES@` substituted:
  `profiles/personal/{claude/settings.json,codex/hooks.json,copilot/hooks/framework-policy.json}`.
  **Live fire:** during T5 the PostToolUse `stamp-refresh` hook auto-bumped
  `docs/spec-workflow-guide.md` and `docs/ai-agent-framework.md` stamps in
  the working Claude Code session — the wiring is active in production.
- **AC-2 (pre-commit backstop):** `scripts/test/pre-commit.test.sh` — 6
  assertions green: planted `AKIA…` secret rejected citing the file, staged
  `.env` rejected, stale stamp rejected citing the file,
  `SKIP_STAMP_CHECK=1` escape hatch works, fresh stamp passes, repo-local
  hook chained (its rc controls the outcome). `make install-git-hooks`
  applied to this repo (`core.hooksPath = scripts/git-hooks`).
- **AC-3 (self-announcing profile breakage):** `scripts/test/ai-doctor.test.sh`
  — 7 assertions green (broken symlink fails naming the path, repair
  restores rc=0, fast mode, manifest mismatch/consistency, missing profile).
  Live run found 5 real pre-existing failures: `upstream` link missing in
  all three tool dirs (fixed by adding `upstream` to the profile-init refs
  and re-initializing) and 2 stale `.active-manifest` targets (logged to
  improvements-log; cleared by the next `ai personal` switch). 100% of
  manifest entries checked.
- **AC-4 (Direct lane codified):** `spec-lifecycle.md § Direct lane`
  (anchor `direct-lane`), `boundaries.md` Always #3 + Never #2 link to it
  (one-hop); lanes overview added to `spec-workflow-guide.md` and
  `ai-agent-framework.md`. `make validate-specs` + `make lint-rules` +
  `make validate-anchors` all OK after the edits.
- **AC-5 (review-after closure):** `spec-lifecycle.md § Review-after closure`
  (anchor `review-after-closure`) — low/trivial only, batch-review
  obligation + revert path stated; transition table row updated;
  `boundaries.md` Never #4 amended; requirements/plan gates unchanged.
- **AC-6 (meta-share metric):** `scripts/test/spec-metrics.test.sh` green;
  `make spec-metrics` baseline on the live corpus (2026-06-10):
  2026-05 → 15 framework / 0 product (100%), 2026-06 → 2 framework / 0
  product (100%), total 17/0 — the meta-share watch threshold (>30%) is
  exceeded, exactly the gravity this metric now makes visible.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Changes to
`boundaries.md` and `spec-lifecycle.md` are "Ask first" — they land only inside this
spec's approved tasks.
## Docs updates required
- `framework/boundaries.md` — Direct lane rule; pointer to mechanical enforcement.
- `framework/spec-workflows/spec-lifecycle.md` — Direct lane definition;
  review-after closure gate for low/trivial risk.
- `docs/agent-protocol.md` — hook layer description (what is enforced mechanically
  vs by prose); `ai doctor` reference.
- `docs/ai-agent-framework.md` — enforcement-pyramid overview (harness hooks →
  git hooks → CI), metric target.
- `docs/spec-workflow-guide.md` — lane table update (standard / trivial / direct).
## Rollout / migration notes
- Hook adapters render via `ai-profile-init`; existing profiles need one re-init
  after merge (`ai-profile-init personal`).
- Codex CLI loads project-scoped hooks only for trusted projects — document the
  one-time trust step.
- Pre-commit installation must not clobber existing project hooks; use
  `core.hooksPath` with chaining or check for an existing hook and append.
- Revert path: each FR is independently revertible (delete adapter configs, unset
  `core.hooksPath`, revert doc rules) — no data migration involved.
