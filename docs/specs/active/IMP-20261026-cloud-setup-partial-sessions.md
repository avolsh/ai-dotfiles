---
id: IMP-20261026-cloud-setup-partial-sessions
type: IMP
date: 2026-10-26
status: specify
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
branches: {ai-dotfiles: TBV-83-cloude-fix}
affected-docs:
  - README.md
  - docs/improvements-log.md
affected-code:
  - scripts/ai-cloud-setup.sh
  - scripts/ai-cloud-docker.sh
  - scripts/ai-workspace-link.sh
  - scripts/ai-doctor.sh
  - framework/templates/system/claude/hooks.json
  - scripts/test
skills:
  - writing-specs
  - writing-docs
  - reviewing-changes
model-suggestion: default
baseline-impact: none — no docs/domain baselines in ai-dotfiles
---
# IMP-20261026-cloud-setup-partial-sessions
*Last updated: 2026-10-26*

## Summary
- **Goal:** Every cloud session of a profile's environment starts, whichever repos it cloned, and a resumed session has Docker again; the environment's Setup script is one line that never needs editing.
- **Scope:** `ai-workspace-link.sh` and `ai-cloud-setup.sh` treat a missing clone as a warning; the Docker step moves into its own script, which the Claude SessionStart hook also runs in the cloud before the doctor; README's Setup script row becomes the guarded one-liner.
- **Out of scope:** `tobevisit-docs`, the laptop flow, the Codex hooks and the environment settings themselves (Alex's).

## Current State
- The environment "AI Personal" runs `bash ai-dotfiles/scripts/ai-cloud-setup.sh personal --docs tobevisit-docs` (README § Cloud sessions). Sessions show "Setup script failed … This session can't continue" (2026-10-26).
- Reproduced in fixture workspaces (2026-10-26): all repos → 0; no `tobevisit-docs` → 2 (`ai-workspace-link: --docs 'tobevisit-docs' is not a clone`, then `set -e`); no `ai-dotfiles`, or no repo at all → 127 (`No such file or directory`).
- Without `--docs`, the same script already links the only clone holding `workspace/CLAUDE.md` and only warns when there is none.
- After a resume the container keeps its files but not its processes, and the Setup script does not run again: the SessionStart report in this thread read `ai-doctor: FAIL docker daemon not reachable`, with no `dockerd` process.

## Proposed Improvement
- A missing clone never stops a session: it is a warning in the setup log, and the doctor still reports what is unlinked.
- The Setup script is `[ ! -f ai-dotfiles/scripts/ai-cloud-setup.sh ] || bash ai-dotfiles/scripts/ai-cloud-setup.sh personal`, safe for a session with no `ai-dotfiles`.
- Docker is started at every cloud SessionStart, so a resumed session gets it back.
- Benefit: setup exit code over the four clone sets (all, no docs, no dotfiles, none): baseline 0/2/127/127, target 0/0/0/0. Doctor Docker failures after a resume: baseline 1, target 0.

## Requirements
- FR-1: `ai-workspace-link.sh --cloud --docs <name>` MUST, when `<name>` is a plain name but not a clone in the root, warn on stderr, leave `docs` unlinked and continue with exit 0; a name that is not plain stays a usage error.
- FR-2: `ai-cloud-setup.sh` MUST exit 0 whatever clones besides `ai-dotfiles` the session holds; it exits non-zero only on a usage error or a failing step of its own.
- FR-3: `scripts/ai-cloud-docker.sh` MUST, only when `CLAUDE_CODE_REMOTE=true` or `--force`, add the `mirror.gcr.io` registry mirror and start `dockerd` detached from its caller when the daemon does not answer, then wait up to 10 s for it; it always exits 0, and `ai-cloud-setup.sh` uses it for its Docker step.
- FR-4: The Claude SessionStart hook MUST run `ai-cloud-docker.sh` and then `ai-doctor.sh --fast --hook` in one command, so the doctor checks a daemon already started.
- FR-5: README § Cloud sessions MUST give the guarded one-liner as the Setup script, `--docs` only for a workspace where several clones hold `workspace/CLAUDE.md`, and say that Docker returns on resume.

## Acceptance Criteria
### AC-1: A session starts with any set of clones (FR-1, FR-2, FR-5)
Given fixture workspaces holding all repos, no docs clone, no `ai-dotfiles`, and no repo
When README's Setup script line runs in each, and `ai-cloud-setup.sh personal --docs <absent clone>` runs where `ai-dotfiles` is present
Then every run exits 0; where `ai-dotfiles` is present `~/.claude` is wired and the absent docs clone is named in a warning; a non-plain `--docs` still exits 2

### AC-2: Docker is started in the cloud only (FR-3, FR-4)
Given stub `docker`/`dockerd` and a fixture `daemon.json`
When `ai-cloud-docker.sh` runs with the daemon down in the cloud, with it up, and outside the cloud
Then it starts `dockerd` once and returns after the stub answers, keeping other `daemon.json` keys; it starts nothing in the other two runs; every run exits 0; the rendered SessionStart command runs it before the doctor

## Design
### Decisions
- D1: One SessionStart command, `ai-cloud-docker.sh; ai-doctor.sh --fast --hook` — rejected: a second hook entry (hooks of one event run in parallel, so the doctor could check before the start); the doctor starting Docker itself (the doctor only reports).
- D2: A missing named docs clone is a warning — rejected: dropping `--docs` from the line only (a profile whose workspace has several docs clones still needs it, and would fail again in a partial session).
### Risks / Trade-offs
- The hook runner may kill what its command leaves behind → `setsid nohup dockerd`; observed after `master` in a resumed session (Rollout).
- A 10 s wait lengthens SessionStart when the daemon is slow → bounded, and the doctor still reports a daemon that never came up.
### Open Questions
None.

## Out of Scope
- OS-1: Codex `hooks.json` — Codex does not run in these cloud sessions.
- OS-2: The environment settings — Alex pastes the one-liner.
- OS-3: Observing a fresh and a resumed session on `master` — the post-merge check prompt (Rollout), by Alex's decision of 2026-10-26.

## Split Decision
- Clusters: partial sessions (FR-1, FR-2, FR-5), Docker on resume (FR-3, FR-4).
- Triggers: T1 (the clusters test independently). Exceptions: none applies.
- Recommendation: `split-recommended` (T1) — sibling `cloud-docker-on-resume`.
- Human decision, 2026-10-26 09:44 ("one", in the thread): keep-as-one, one IMP and one PR.

## Tasks
Pending — Plan stage only.

## Closure Evidence
Pending — closure only.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- README.md — § Cloud sessions: Setup script row, step 6, the SessionStart paragraph.
- docs/improvements-log.md — the Setup script that failed partial sessions and the Docker lost on resume.

## Rollout / migration notes
- After the PR reaches `master`, Alex pastes the one-liner into the environment and runs the check prompt the closing message gives: one session with all repos, one without `ai-dotfiles`, then a resume of the first.
