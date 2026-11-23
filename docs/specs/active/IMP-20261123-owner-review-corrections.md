---
id: IMP-20261123-owner-review-corrections
type: IMP
date: 2026-11-23
status: in-progress
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
branches: {ai-dotfiles: master}
affected-docs:
  - README.md
  - docs/agent-protocol.md
  - framework/boundaries.md
  - framework/spec-workflows/spec-lifecycle.md
  - framework/prompts/create-spec.prompt.md
  - framework/skills/writing-specs/references/authoring-steps.md
  - framework/skills/writing-specs/references/splitting-rules.md
  - docs/spec-asking-questions.md
  - framework/hooks/README.md
  - docs/improvements-log.md
affected-code:
  - framework/hooks/pr-base-guard.sh
  - framework/hooks/bash-write-guard.sh
  - framework/scripts/test/hooks.test.sh
skills:
  - writing-specs
  - writing-docs
  - reviewing-changes
model-suggestion: default
baseline-impact: none — no docs/domain baselines in ai-dotfiles
---
# IMP-20261123-owner-review-corrections
*Last updated: 2026-11-23*

## Summary
- **Goal:** The corrections the owner made across the tobevisit-mvp project threads become framework rules, so no thread has to be corrected the same way twice.
- **Scope:** The 17 entries of `docs/improvements-log.md` dated 2026-11-23: rules in `agent-protocol.md`, `boundaries.md`, the spec lifecycle, the Specify and Plan references and the split rules; `pr-base-guard.sh` reads a base from a spec at any active status; `bash-write-guard.sh` lets the agent merge a fetched branch into its own `claude/*` branch in a cloud session.
- **Out of scope:** deleting untracked files through the guard (OS-1); resetting or reusing a `claude/*` branch (OS-2); project `_canonical.md` files (OS-3).

## Current State
- `docs/improvements-log.md` holds 17 entries of 2026-11-23, each `What was changed: none — logged for review` ([PR #18](https://github.com/avolsh/ai-dotfiles/pull/18)); the owner approved all of them in the thread (A1–A7 with the nuance on A3, B–F `з усім згоден`, 2026-11-23).
- `agent-protocol.md § Agent output conventions` covers commit messages and branch names, nothing about how a reply to the owner is written; no section names where a fact is stored, how a cloud thread is named, or how the owner's device is shared.
- `boundaries.md § Always do #15` asks to verify a checkable claim before challenging, but not to say what was checked.
- `plan-spec.prompt.md` already refuses tasks without approved requirements (Preconditions, Hard rules); the 2026-10-27 case broke a rule that exists, so it needs no new one.
- `authoring-steps.md § C` step 4 orders tasks by dependency only; `agent-protocol.md § Interpreting "continue"` grants one task at a time, with no mode for "do everything you can without me".
- `splitting-rules.md § 2` makes T1 alone a must-split; the owner declined that split twice (2026-11-13, 2026-11-19).
- The lifecycle has no rule on a release before closure, a tracker ticket, or a re-run AC's idempotency.
- `pr-base-guard.sh` reads `branches:` only from `in-progress` specs, so a spec-only PR for a spec at `specify` is refused (2026-11-14, 2026-11-19); `bash-write-guard.sh` refuses every `git merge` in the cloud (tests: `git merge TBV-1`, `git merge origin/master`), so the owner merged by hand and left conflict markers (2026-11-18).

## Proposed Improvement
- One rule per correction, each in the one canonical file that owns its subject, the others linking to it.
- Two guard changes that remove a hand-off the owner had to do, with the cases that must stay denied kept in the suite.
- Benefit: entries of 2026-11-23 still `logged for review` after closure: baseline 17, target 2 (OS-1, OS-2, each with a reason recorded in the closing entry).

## Requirements
- FR-1: `agent-protocol.md` MUST say that a question about status, scope or what exists is answered after reading its source of record, which the reply names; a claim in a gate carries its evidence or says it is a guess; operational advice cites the current runbook or code, never a step of a one-off migration; the question asked is answered first; release advice follows the repo's documented release steps (entries 1, 3, 14).
- FR-2: `boundaries.md § Always do #15` MUST require saying what was checked when the agent contradicts the owner on a fact (entry 2).
- FR-3: `agent-protocol.md` MUST say, for messages to the owner: no salutation and no name; decision questions in the message itself, numbered, one recommended answer each and answerable in a line, internal terms explained; a reply to his answers covers every number he raised; a step he runs is one copy-paste line or the exact UI place and value; a PR the agent cannot open is asked for with its compare link; a mistake is named before anything is adapted to it (entries 4, 5, 6).
- FR-4: `agent-protocol.md` MUST say that a change the owner did not ask for by name is proposed first, with its effect and downside, and made only after his answer (entry 7).
- FR-5: `authoring-steps.md § C` MUST order the tasks the agent can finish alone before the ones that need the owner, grouped at the end; `agent-protocol.md § Interpreting "continue"` MUST define an autonomous mode the owner sets for a spec ("do everything you can without me"), recorded under the Tasks line, in which the agent runs task after task, posts each Bottom Line and leaves each row at `◐`, and stops at a task that needs the owner or at a failure (entry 8).
- FR-6: `splitting-rules.md` MUST make T1 alone a recommendation the human may decline, and MUST add an exception and a Specify rule: a small adjacent change is included rather than deferred, and transitional compatibility is skipped when the window it covers is hours (entry 9).
- FR-7: `spec-lifecycle.md` MUST add a rule: a change that ships in an image or a deploy names its release step under Rollout and closes after the release; acceptance runs on the PR branch before the merge where the project has a per-branch preview; every run that touches data or costs money is named with its exact command and run only after the owner's go, and no paid full run is made on a local copy (entries 10, 13).
- FR-8: `spec-lifecycle.md` MUST add a rule: the tracker ticket the work serves is updated at each milestone (requirements approved, PR opened, closure, merge, release) without being asked, and a PR or thread serving it carries its key first (entry 16).
- FR-9: `create-spec.prompt.md` step 6 MUST check, before the requirements gate, the idempotency of every tool a spec names and of every "re-run changes nothing" AC against the whole command (entry 14).
- FR-10: `agent-protocol.md` MUST add a cloud-threads section: thread titles `[<ticket>] <spec id>`; a live Remote Control session asked before coding and stopped when its device work is done; what the agent may run on the device is run there, not handed over; a PR stays draft until its last commit is pushed and no review is requested from its author; nothing is written in the owner's working tree while he builds, tests or reviews there, the files to change are named first and the end of the edits is said; a file meant for one session is not forwarded to another (entries 12, 13, 17).
- FR-11: `agent-protocol.md` MUST add a table of where each kind of fact is stored, with no index file for project memory (entry 15).
- FR-12: `pr-base-guard.sh` MUST, when no `in-progress` spec records a base for the repo, accept a base recorded under `branches:` by a spec at `specify` or `plan`; an `in-progress` record still wins, and disagreeing records at the deciding status still deny (entry 11).
- FR-13: `bash-write-guard.sh` MUST, in a cloud session on the agent's own `claude/*` branch, allow `git merge` of `FETCH_HEAD` or `origin/<ref>` other than `master` / `develop`, with no option but `--no-edit`, `--ff-only`, `--no-ff`, `--abort`, `--continue`; `boundaries.md § Never do #10` says so (entry 11).
- FR-14: `boundaries.md § Never do #10` MUST name a `claude/*` branch the agent creates `claude/<ticket>-<slug>` when the work serves a tracker ticket (`claude/TBV-102-project-thread-6w751s`), and say that a branch name the platform assigns is kept and the ticket named in the PR instead (the owner, 2026-11-23 18:21 Kyiv, in the thread).

## Acceptance Criteria
### AC-1: Each rule has one canonical home (FR-1–FR-11, FR-14)
Given the rules of FR-1–FR-11 and FR-14
When the changed files are read and `make check` runs
Then each rule appears once, in the file its FR names, other files link to it, and `make check` exits 0 (links, anchors, lint-rules, validate-specs, tests)

### AC-2: A spec-only PR for a spec still at specify is allowed (FR-12)
Given fixture spec trees: one spec at `specify` recording `TBV-1`; that spec plus an `in-progress` one recording `TBV-2`; two `specify` specs recording `TBV-1` and `TBV-3`
When `pr-base-guard.sh` checks a PR into `TBV-1`, `TBV-2` and `master`
Then `TBV-1` passes in the first tree, only `TBV-2` in the second, none in the third, and `master` never

### AC-3: The agent merges a fetched branch into its own branch (FR-13)
Given a cloud session on `claude/x` and the existing guard suite
When it runs `git merge --no-edit FETCH_HEAD`, `git merge --no-edit origin/TBV-1`, `git merge --abort`, and the denied forms `git merge TBV-1`, `git merge origin/master`, `git merge --squash origin/TBV-1`, a merge on a non-`claude/` branch, and one outside the cloud
Then the first three pass, every other one is denied, and every earlier case keeps its result

## Design
### Decisions
- D1: Rules go into the existing canonical files, one home each — rejected: a new "owner corrections" doc (a second place to read, and the one-hop convention forbids copies).
- D2: Autonomous mode is a line under the Tasks heading, not a front-matter key — rejected: a key (a schema change for `validate-specs` and `lifecycle.yaml`, for a choice that is the owner's per spec).
- D3: The merge allowance names its sources (`FETCH_HEAD`, `origin/<ref>`) instead of reading the recorded base — rejected: reading `branches:` in the shell guard (a second copy of `pr-base-guard`'s reader); `master` / `develop` stay denied by name.
### Risks / Trade-offs
- A merge that conflicts leaves markers in the agent's branch → the agent resolves and commits there; nothing reaches another branch, and `--abort` is allowed.
- A `specify` spec's base now admits a PR → only when no `in-progress` spec records that repo, so the PR of the spec being implemented still decides.
### Open Questions
None.

## Out of Scope
- OS-1: Letting the guard `rm` a file git does not track (entry 11) — an untracked file is the one git cannot restore, and `.env` files are untracked; the rule stays: take the route the guard names or ask, never another program.
- OS-2: Resetting or reusing a `claude/*` branch (entry 11) — a reset discards unpushed commits; a new spec on a new branch costs a branch name, not work.
- OS-3: Project `_canonical.md` files — the rules are system scope; projects inherit them through `<system>/`.

## Split Decision
- Clusters: owner-facing rules (FR-1–FR-4, FR-10, FR-11, FR-14), spec process (FR-5–FR-9), guards (FR-12, FR-13).
- Triggers: T1 (the guard cluster tests on its own). Exceptions: E5 does not apply (code changes); none other.
- Recommendation: `split-recommended` (T1) — sibling `guard-hand-offs`.
- Human decision, 2026-11-23 18:17 Kyiv (`а ти не хочеш одразу зробити IMP і реалізувати його?`, in the thread, after approving every entry): keep-as-one, one IMP in PR #18.

## Tasks
> **Before starting Task 1, set status: in-progress in the front-matter above.**
>
> **Autonomous until owner checks** — the owner, 2026-11-23 18:17 Kyiv (`а ти не хочеш одразу зробити IMP і реалізувати його?`): requirements and plan approved with that message; tasks run back to back, each Bottom Line posted, rows left at `◐` until the owner approves at closure.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| 1 | Guards: `pr-base-guard` reads `specify` / `plan` records when no `in-progress` one exists; `bash-write-guard` allows the cloud merge of `FETCH_HEAD` / `origin/<ref>` into the agent branch; suite cases first run against the old guards (FR-12, FR-13; AC-2, AC-3) | `framework/hooks/pr-base-guard.sh`, `framework/hooks/bash-write-guard.sh`, `framework/scripts/test/hooks.test.sh`, `framework/hooks/README.md` | `framework/hooks/lib/spec-lease.sh` | — | writing-specs | default | ◐ awaiting approval |
| 2 | Boundaries: #15 says what was checked; #10 cloud exception names the merge, a diverged branch merged instead of stopping, and the `claude/<ticket>-<slug>` branch name (FR-2, FR-13, FR-14) | `framework/boundaries.md`, `README.md` | `docs/rule-canonical-map.md` | 1 | writing-docs | default | ◐ awaiting approval |
| 3 | Agent protocol: source of record, messages to the owner, propose before changing, autonomous mode, cloud threads and the owner's device, where facts live (FR-1, FR-3, FR-4, FR-5, FR-10, FR-11) | `docs/agent-protocol.md`, `docs/spec-asking-questions.md` | `docs/rule-canonical-map.md` | — | writing-docs | default | ◐ awaiting approval |
| 4 | Spec process: task order, T1 alone and the adjacent-change exception, release before closure and runs with a go, the tracker ticket, idempotency at the requirements gate (FR-5, FR-6, FR-7, FR-8, FR-9) | `framework/skills/writing-specs/references/authoring-steps.md`, `framework/skills/writing-specs/references/splitting-rules.md`, `framework/spec-workflows/spec-lifecycle.md`, `framework/prompts/create-spec.prompt.md` | `docs/splitting-specs.md` | 3 | writing-specs, writing-docs | default | ◐ awaiting approval |
| 5 | Closure: closing improvements-log entry, `make check`, review, Closure Evidence, archive, PR #18 and TBV-102 (AC-1) | `docs/improvements-log.md`, `docs/specs/active/IMP-20261123-owner-review-corrections.md` | — | 1–4 | reviewing-changes | default | ◐ awaiting approval |

## Closure Evidence
`make check` exits 0 at closure (2026-11-23, in this cloud thread): links (179 files), `validate-specs` OK (57 specs), `lint-rules` OK (90 phrases), `validate-anchors` OK (176 fragments), every self-test suite passed.

| AC | Evidence |
|---|---|
| AC-1 | Each rule has one home, the others link to it: FR-1, FR-3, FR-4 → `docs/agent-protocol.md § Working with the owner` (`#answer-from-source`, `#messages-to-owner`, `#propose-before-changing`), linked from `docs/spec-asking-questions.md`; FR-2 → `framework/boundaries.md § Always do #15`; FR-5 → `authoring-steps.md § C` step 4 and `agent-protocol.md#autonomous-mode`, each linking the other; FR-6 → `splitting-rules.md` `#t1-alone`, E6, § 5; FR-7 → `spec-lifecycle.md § Rules #16` (`#ship-before-closure`); FR-8 → `§ Rules #17` (`#tracker-ticket`), linked from the store table; FR-9 → `create-spec.prompt.md` step 6; FR-10 → `agent-protocol.md#cloud-threads`; FR-11 → `#where-facts-live`; FR-14 → `boundaries.md#claude-branch-name`, linked from `#cloud-threads`. `validate-anchors` resolves every new fragment and `lint-rules` finds no tracked phrase outside its canonical file. |
| AC-2 | `framework/scripts/test/hooks.test.sh` § pr-base-guard, the `third` tree: a `specify` spec recording `TBV-1` → `TBV-1` allowed, `master` denied; plus an `in-progress` spec recording `TBV-2` → only `TBV-2`; a `specify` and a `plan` spec disagreeing → `TBV-1`, `TBV-3`, `master` all denied. Run against the previous guard, `third -> TBV-1` failed (rc 2); the earlier case "a `plan` spec beside an `in-progress` one" keeps its result. |
| AC-3 | `hooks.test.sh` § cloud exception: `git merge --no-edit FETCH_HEAD`, `--no-edit origin/TBV-1`, `--abort`, `--continue`, `--ff-only origin/claude/x`, `--no-ff --no-edit origin/TBV-1` and `git fetch origin claude/x && git merge --no-edit FETCH_HEAD` pass in the cloud and are denied outside it; `git merge TBV-1`, `origin/master`, `origin/develop`, `refs/remotes/origin/master`, `--squash`, `-s ours`, `-X theirs`, `--no-verify`, `--allow-unrelated-histories`, two refs, none, `-m x` and `origin/TBV-1:x` are denied, and so is a merge on branch `TBV-1`. Against the previous guard the seven allowed forms failed (rc 2); every earlier case, including `git merge TBV-1` and `git fetch` + `git merge origin/master`, keeps its result. |

### Review
Waived — `risk: medium` needs no recorded review ([`spec-lifecycle.md § Status transitions`](../../../framework/spec-workflows/spec-lifecycle.md)); the owner approves the closure synchronously.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- docs/agent-protocol.md — FR-1, FR-3, FR-4, FR-5, FR-10, FR-11.
- framework/boundaries.md — FR-2, FR-13, FR-14.
- README.md — § Cloud and local on one branch: a diverged branch is merged (FR-13).
- framework/spec-workflows/spec-lifecycle.md — FR-7, FR-8.
- framework/prompts/create-spec.prompt.md — FR-9.
- framework/skills/writing-specs/references/authoring-steps.md, splitting-rules.md — FR-5, FR-6.
- docs/spec-asking-questions.md — link to FR-3's question format.
- framework/hooks/README.md — FR-12, FR-13.
- docs/improvements-log.md — a closing entry naming what each 2026-11-23 entry became.

## Rollout / migration notes
- Merged by the owner with PR #18. Hooks take effect in each session after the merge reaches the profile's `ai-dotfiles` checkout; nothing to migrate.
