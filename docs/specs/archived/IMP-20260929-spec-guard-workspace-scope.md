---
id: IMP-20260929-spec-guard-workspace-scope
type: IMP
date: 2026-09-29
closed: 2026-09-29
status: done
owner: alex
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/hooks/README.md
affected-code:
  - framework/hooks/spec-status-guard.sh
  - framework/scripts/test/hooks.test.sh
skills:
  - writing-specs
  - systematic-debugging
model-suggestion: default
baseline-impact: none — no docs/domain baselines in ai-dotfiles
---
# IMP-20260929-spec-guard-workspace-scope
*Last updated: 2026-09-29*

## Summary
- **Goal:** Let `spec-status-guard.sh` see the governing spec of a cross-repo change that lives in an enclosing workspace's spec tree, instead of denying the edit.
- **Scope:** The guard evaluates every ancestor directory that owns `docs/specs/active`, not only the nearest one, and matches each spec's `affected-code` against the path as that spec's own root spells it. Tests and the hook README follow.
- **Out of scope:** The guard's allow conditions themselves, and the fact that `Bash` edits never reach it.

## Current State
- The guard walks up from the edited file to the **first** directory owning `docs/specs/active`, calls it `root`, and scans `"$root"/docs/specs/active/*.md` only (`framework/hooks/spec-status-guard.sh:47-58`, `:96`).
- In this workspace a cross-repo spec lives in the workspace root's tree (`docs/specs/active/`, the `tobevisit-docs` project of `<workspace>/CLAUDE.md`), while the code it edits lives in `src/github.com/tobeverse/tobevisit-web/`, which owns a spec tree of its own.
- Evidence, 2026-09-29: with `CR-20260924-tobevisit-web-payload-migration` (workspace root) at `in-progress` and leasing `src/github.com/tobeverse/tobevisit-web/_cms`, a write to `_cms/payload.config.ts` was denied, naming `CR-20260918-cms-schema-as-code` (tobevisit-web, `specify`). Thirteen `specify`-stage specs there lease `_cms`, `src`, `src/config.ts`, `next.config.mjs`, `open-next.config.ts`, `wrangler.toml`, `cloudflare-build.sh` and `Makefile` between them, so every file of that migration is unreachable.
- The sibling migration in `geeoz-web` never hit this: that repo's `docs/specs/active/` holds only `README.md`, so the guard found no blocker.
- Neither allow condition can fire, whatever the human writes: both read `in-progress` ids collected from the single `root`, and a workspace-root spec is never among them.

## Proposed Improvement
- The guard collects **every** ancestor that owns `docs/specs/active` — the nearest project root and any enclosing workspace root — and evaluates the specs of all of them in one pass, each against the path spelled relative to that root.
- Measurable benefit: cross-repo specs governed from a workspace tree stop being false denials. Baseline, this workspace: 0 of the 11 tasks of `CR-20260924-tobevisit-web-payload-migration` can edit `tobevisit-web`; target: all of them, with the `specify`-stage leases still denying every edit no `in-progress` spec governs.
- A single-project repository with no enclosing spec tree collects exactly one root, so its behaviour is unchanged.

## Requirements
- FR-1: The guard MUST evaluate the active specs of every ancestor directory of the edited file that owns `docs/specs/active`, not only the nearest one.
- FR-2: Each spec's `affected-code` entries MUST be matched against the edited path relative to **that spec's own root**, so a workspace-root spec leasing `src/github.com/tobeverse/tobevisit-web/_cms` matches, and a project spec leasing `_cms` keeps matching.
- FR-3: The allow conditions MUST be decided across all collected roots together: an `in-progress` spec in any of them leasing the path allows the edit, and a blocker's `depends-on:` naming an `in-progress` spec from any of them clears that blocker.
- FR-4: A denial MUST still name the blocker with the earliest `date:`, and the message MUST say which spec tree it came from, since two trees can now hold blockers.
- FR-5: For an edited file with exactly one such ancestor, the decision MUST be identical to today's, including the `docs/*` and `*.md` exemptions and the fail-open on a malformed payload.
- FR-6: `framework/scripts/test/hooks.test.sh` MUST cover the nested-workspace fixture for each outcome: allowed by a workspace-root `in-progress` lease, denied by a project blocker with no governing spec, and cleared by `depends-on:`.

## Acceptance Criteria
### AC-1: Cross-repo spec governs the edit (FR-1, FR-2, FR-3)
Given a fixture workspace whose root spec tree holds an `in-progress` spec leasing `proj/src`, and `proj/` owns a spec tree whose only spec is at `specify` and leases `src`
When the guard runs for `proj/src/app.ts`
Then it exits 0

### AC-2: A genuine conflict still denies (FR-4)
Given the same fixture with the workspace-root spec at `specify` instead
When the guard runs for `proj/src/app.ts`
Then it exits 2 and the message names the blocker with the earliest `date:` and the spec tree holding it

### AC-3: Single-root behaviour unchanged (FR-5, FR-6)
Given the existing single-root fixtures of `hooks.test.sh`
When the suite runs after the change
Then every existing assertion passes unchanged, and the new nested-workspace cases pass

## Design
### Decisions
- D1: Collect roots by continuing the upward walk past the first match, with no marker file. Rejected: reading `<workspace>/CLAUDE.md` for the project map, which makes the guard depend on a document's shape and on the optional `<workspace>` convention; rejected: an environment variable naming the workspace, which is unset in exactly the harnesses the guard must work in.
- D2: One pass that gathers `(root, spec)` pairs and decides afterwards, replacing today's `leases_path && exit 0` inside the loop. It is what FR-3 requires: an outer root's `in-progress` spec must be able to allow a path an inner root's spec blocks, whichever is read first.
### Risks / Trade-offs
- An unrelated ancestor that happens to own `docs/specs/active` (a checkout inside another repository's tree) starts contributing blockers → the same allow conditions apply to it, and AC-2's message names the tree, so a surprise denial is traceable to its source in one line.
- The walk reads more spec files per edit → the count is bounded by the directory depth, and each file is read only for its front-matter, as today.
### Open Questions
None.

## Out of Scope
- OS-1: `Bash` writes (`cp`, `sed`, a heredoc) never reach a PreToolUse guard matched on `Edit|Write|MultiEdit`, so the lease is enforced only for the file tools. Observed in this session, and the same class as the 2026-09-29 improvements-log follow-up about writing git verbs in shell commands; it needs its own spec.
- OS-2: Whether a `specify`-stage spec should lease a path at all, and the allow conditions themselves.

## Split Decision
keep-as-one (`no-trigger`). One cluster: FR-1–FR-5 are one decision path in one script, and FR-6 is its test. T1 no — no AC passes without the changed root resolution; T2 no — one script, one context; T3 no — one repo; T4 no — no data entity; T5, T6 no — nothing external blocks a part of it.

## Tasks
> **Before starting Task T1, set status: in-progress in the front-matter above.**

Paths are relative to the `ai-dotfiles` repository root. T1 changes the decision; T2 documents it and checks it against the workspace that found the gap.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Multi-root resolution: the upward walk collects every ancestor owning `docs/specs/active` instead of stopping at the first; each spec is matched against the path relative to its own root; one pass gathers blockers and `in-progress` leases across all roots and decides afterwards; the denial names the blocker's spec tree. Tests: the nested-workspace fixture for all three outcomes, and every existing single-root assertion unchanged (FR-1–FR-6; AC-1, AC-2, AC-3) | `framework/hooks/spec-status-guard.sh`, `framework/scripts/test/hooks.test.sh` | `framework/hooks/README.md`, `framework/spec-workflows/spec-lifecycle.md` | — | systematic-debugging, test-driven-development | default | ☑ done |
| T2 | Docs and verification: the README's root resolution and allow conditions across several spec trees; `make tests` and `make check` green; against this workspace, a write to `src/github.com/tobeverse/tobevisit-web/_cms/payload.config.ts` is allowed while `CR-20260924-tobevisit-web-payload-migration` is at `in-progress`, and denied once it is not (the Current State evidence, re-run) | `framework/hooks/README.md` | `docs/specs/active/CR-20260924-tobevisit-web-payload-migration.md` (workspace root), `src/github.com/tobeverse/tobevisit-web/docs/specs/active/*.md` | T1 | writing-docs | fast | ☑ done |

## Closure Evidence
Final runs 2026-09-29, agent, on `master` at the working tree of this change: `make tests` rc=0, `make check` rc=0 (links, validate-specs 52 specs, lint-rules, validate-anchors).

| AC | Evidence | Result |
|---|---|---|
| AC-1 | `hooks.test.sh` "guard allows an edit governed from the enclosing workspace tree" — the nested fixture (`ws/docs/specs/active` holding an `in-progress` spec leasing `repo/src`, `ws/repo/docs/specs/active` holding a `specify` spec leasing `src`) exits 0. Verified red first: the same payload against `git show HEAD:framework/hooks/spec-status-guard.sh` exits 2, so the case could have failed. Also "guard clears a project blocker waiting on a workspace spec" (FR-3, `depends-on:` across trees) | pass |
| AC-2 | `hooks.test.sh` "guard denies when no tree has a governing spec" exits 2, with two message assertions: the blamed spec is the earliest by `date:` (`CR-20260901-repo-plan`), and the message names its tree (`$ws/repo/docs/specs/active`) | pass |
| AC-3 | `hooks.test.sh` rc=0 with every pre-existing single-root assertion unchanged, including the two that failed mid-task and drove the `read -r` fix below; `make tests` rc=0 across all 9 suites; `make check` rc=0 | pass |
| Benefit (Proposed Improvement) | Measured on this workspace's real spec trees, both directions: a write to `src/github.com/tobeverse/tobevisit-web/_cms/payload.config.ts` exits 0 while `CR-20260924-tobevisit-web-payload-migration` is at `in-progress`; on a copy of both trees whose only change is that spec at `plan`, it exits 2 naming `CR-20260918-cms-schema-as-code.md` and its tree. Baseline was 0 of 11 migration tasks able to edit the repository | pass |

- **Divergence (T1):** field splitting was first written as `read -r` under `IFS=$'\t'`, which broke two existing assertions — a tab is IFS whitespace, so the empty `date:` of a fixture spec without one collapsed and shifted every field left. Replaced with parameter expansion, as the original code used, with a comment naming the trap (`framework/hooks/spec-status-guard.sh:131`).
- **Consolidation sub-step:** not due — `consolidation-due.py` reports 3/5 against a threshold of 5, 0 contexts due.
- **Reviewer sub-step:** not required — `risk: medium`; a recorded `### Review` is mandatory for the high tier only (`spec-lifecycle.md` § Status transitions).
- **Processes:** none started; the fixtures under `/tmp` were removed after the runs.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. The guard is shared by all three harnesses (`framework/hooks/README.md` § Contract): keep it POSIX-shell portable and fail-open on a malformed payload.

## Docs updates required
- `framework/hooks/README.md` — the guard's root resolution and the allow conditions across several spec trees.
