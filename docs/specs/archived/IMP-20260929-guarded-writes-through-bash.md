---
id: IMP-20260929-guarded-writes-through-bash
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
  - framework/boundaries.md
affected-code:
  - framework/hooks/bash-write-guard.sh
  - framework/hooks/lib
  - framework/hooks/spec-status-guard.sh
  - framework/scripts/test/hooks.test.sh
  - framework/templates/system
skills:
  - writing-specs
  - systematic-debugging
model-suggestion: default
baseline-impact: none — no docs/domain baselines in ai-dotfiles
---
# IMP-20260929-guarded-writes-through-bash
*Last updated: 2026-09-29*

## Summary
- **Goal:** Close the hole where a shell command writes what the file tools are guarded from writing.
- **Scope:** One `PreToolUse` guard on `Bash` that recognises the common writing verbs in a command, refuses a write to a path no active spec governs (the `spec-status-guard` decision, reused) and refuses a state-changing git verb outright. It fails open on anything it cannot read confidently.
- **Out of scope:** Sandboxing the shell, and any rule about *what* may be written — only *through what* changes.

## Current State
- `spec-status-guard.sh` is wired to `PreToolUse` on `Edit|Write|MultiEdit` (`framework/templates/system/`), so a `Bash` tool call reaches no guard at all.
- Evidence, 2026-09-29, one session on CR-20260924-tobevisit-web-payload-migration: nine files were created under `_cms/` with `cp` while three `specify`-stage specs leased that path, and `_dev/environment/.env.example` was created with `sed >` minutes after the guard had refused a `Write` to a neighbouring leased path. Both were convenience, not evasion.
- `boundaries.md` § Never do #10 already tells the agent to read every shell command for writing git verbs before running it, after the 2026-09-28 incident where `checkout -b`, `stash`, `rm` and `fetch` ran inside compound commands. That is recall, and recall has now failed in two consecutive sessions on two different rules.
- Both failures share one cause, so they have one fix: the shell is the unguarded door to everything the other guards protect.

## Proposed Improvement
- A `bash-write-guard.sh` on `PreToolUse` for `Bash`, sharing `spec-status-guard.sh`'s lease decision for file writes and refusing writing git verbs the way `boundaries.md` already requires by recall.
- Measurable benefit: of the incidents on record — 2 shell writes to leased paths (2026-09-29) and 8 writing git verbs (2026-09-28) — the guard refuses all 10 where recall refused 0. Target: every one of those exact commands denied by the replay suite, with no denial on the read-only commands the same sessions ran.
- Recall stays the first line; this is the backstop, as the git pre-commit hook is for secrets.

## Requirements
- FR-1: A `PreToolUse` guard on `Bash` MUST refuse a command that writes a file whose path no active spec governs, applying the same decision `spec-status-guard.sh` makes, so the two doors give the same answer for the same path.
- FR-2: It MUST recognise, at minimum, the verbs both incidents used: redirection (`>`, `>>`, `tee`), `cp`, `mv`, `rm`, `mkdir`, `touch`, `ln`, `sed -i`, `install`, and a heredoc written to a file.
- FR-3: It MUST refuse a state-changing git verb wherever it appears in a command, including inside a compound one, matching `boundaries.md` § Never do #10; reading verbs MUST stay unrestricted.
- FR-4: It MUST fail open — exit 0 — on any command it cannot read confidently, naming nothing. A guard that blocks work it does not understand would be turned off, and the file tools remain guarded regardless.
- FR-5: A denial MUST name the verb, the path and the governing spec where there is one, and MUST state the same allow conditions `spec-status-guard.sh` states.
- FR-6: Writes to paths outside any spec tree, and to `docs/` and Markdown, MUST stay allowed, as they are for the file tools.
- FR-7: `hooks.test.sh` MUST replay the ten commands on record — the two shell writes and the eight git verbs — plus the read-only commands from the same sessions, and MUST cover the fail-open path.

## Acceptance Criteria
### AC-1: The two doors agree (FR-1, FR-2, FR-5, FR-6)
Given a fixture where a `specify`-stage spec leases `src/foo` and no `in-progress` spec governs it
When each of `cp a src/foo/b`, `sed -i '' s/x/y/ src/foo/b`, `echo x > src/foo/b` and a heredoc to `src/foo/b` is checked
Then each exits 2 naming the verb, the path and the blocking spec, while the same commands against an unleased path and against `docs/x.md` exit 0

### AC-2: Writing git verbs are refused, reading ones are not (FR-3)
Given the eight commands recorded on 2026-09-28 (`checkout -b`, `checkout -B`, `rm`, `restore --staged`, `stash`, `stash pop`, `merge --ff-only`, `fetch`), each also as one step of a compound command
When the guard checks them, and then checks `git status`, `git log`, `git diff`, `git show` and `git branch --show-current`
Then the eight are refused and the five are allowed

### AC-3: An unreadable command does not block work (FR-4, FR-7)
Given commands the guard cannot resolve — a path built from a variable, a write inside a script the command invokes, a pipeline into an interpreter
When the guard checks them
Then it exits 0, and `hooks.test.sh` asserts each case together with the AC-1 and AC-2 replays

## Design
### Decisions
- D1: One guard for both families. Rejected: two scripts, which would duplicate the command-reading half — the hard part — and let the two drift.
- D2: Fail open, explicitly (FR-4). The guard is a backstop for convenience mistakes, not a sandbox: an agent that means to evade it can always write a script and run it. Rejected: fail closed, which denies on every command with a variable in it and would be disabled within a day.
- D3: Reuse `spec-status-guard.sh`'s decision rather than reimplement it — extract the lease decision into a function both scripts source, so a path cannot be governed at one door and not the other. Rejected: calling the guard as a subprocess per path, which re-reads every spec tree for each of a command's paths.
### Risks / Trade-offs
- Reading shell commands is open-ended, so the guard will miss cases → FR-4 makes a miss the designed behaviour rather than a defect, and the replay suite pins the cases that actually happened.
- A false denial interrupts legitimate work → the denial names the verb and path so the agent can use `Write` instead, which is the intended route anyway.
### Open Questions
None.

## Out of Scope
- OS-1: Sandboxing or restricting the shell beyond these two families.
- OS-2: `spec-status-guard.sh`'s own allow conditions, settled in IMP-20260929-spec-guard-workspace-scope.

## Split Decision
keep-as-one (`no-trigger`). One cluster: every FR is a rule of one guard, and D1 and D3 make the command-reading half shared by construction. T1 no — no AC passes without the guard; T2 no — one script; T3 no — one repo; T4, T5, T6 no.

## Tasks
> **Before starting Task T1, set status: in-progress in the front-matter above.**

Paths are relative to the `ai-dotfiles` repository root. T1 makes the decision shareable without changing it; T2 is the new guard; T3 wires it into the three harnesses and writes it down.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | The lease decision moves into a sourceable library — root collection, per-root relative path, front-matter readers, `leases_path`, and the collect-then-decide pass returning the blocker or nothing — and `spec-status-guard.sh` becomes its first caller, with its own message and exit codes unchanged. Every existing assertion in `hooks.test.sh` passes untouched, which is what proves the decision did not move (D3) | `framework/hooks/lib/spec-lease.sh` *(new)*, `framework/hooks/spec-status-guard.sh` | `framework/scripts/test/hooks.test.sh`, `framework/hooks/README.md` | — | avoiding-duplication, systematic-debugging | default | ☑ done |
| T2 | `bash-write-guard.sh`: read the command for the write verbs of FR-2 and resolve each target path, ask the shared decision, and refuse with the verb, the path, the blocking spec and the same allow conditions; refuse a state-changing git verb anywhere in the command while leaving the reading ones alone; exit 0 on anything unresolved — a variable in a path, a write inside an invoked script, a pipeline into an interpreter. Tests: the ten recorded commands, the read-only commands from the same sessions, the `docs/` and Markdown exemptions, and each fail-open case (FR-1–FR-7; AC-1, AC-2, AC-3) | `framework/hooks/bash-write-guard.sh` *(new)*, `framework/scripts/test/hooks.test.sh` | `framework/hooks/lib/spec-lease.sh`, `framework/boundaries.md`, `docs/improvements-log.md` | T1 | systematic-debugging, test-driven-development | deep | ☑ done |
| T3 | Wiring and docs: the guard added to the `Bash` matcher in the Claude and Codex hook templates and to the `bash` entry of the Copilot policy (behind the existing response adapter); README's script table, the new guard's row and its fail-open contract; `boundaries.md` § Never do #10 noting that the shell door is guarded and that the rule still binds where the guard fails open; `make tests` and `make check` green | `framework/templates/system/claude/hooks.json`, `framework/templates/system/codex/hooks.json`, `framework/templates/system/copilot/copilot-cli-policy.json`, `framework/hooks/README.md`, `framework/boundaries.md` | `framework/hooks/adapters/copilot-pretooluse.sh` | T2 | writing-docs | fast | ☑ done |

## Closure Evidence
Final runs 2026-09-29, agent: `make tests` rc=0, `make check` rc=0 (links, validate-specs 53 specs, lint-rules, validate-anchors); the three rendered hook templates parse as JSON.

| AC | Evidence | Result |
|---|---|---|
| AC-1 | `hooks.test.sh` § bash-write-guard: nine write verbs against a leased path exit 2 (`cp`, `sed -i` in the BSD two-argument form, `>`, `>>`, `rm`, `mkdir -p`, `touch`, `mv`, `tee`), plus the same `cp` as the second step of `npm test && …`; the same verbs against an unleased path, a `docs/` file and the spec itself exit 0; three message assertions check the verb, the path and the spec name | pass |
| AC-2 | The eight commands recorded on 2026-09-28 exit 2 each, and again each as `cd /tmp && git …`; ten reading commands exit 0, including `git branch` bare and `git stash list`. `git stash` bare is a *write* and is refused — the form that once applied and dropped the human's own stash | pass |
| AC-3 | Six unreadable commands exit 0 — a `$VAR` in the path, a `$(…)` argument, `bash -c`, an interpreter given a script, `find -exec`, a glob — as do a malformed payload and a payload with no command | pass |
| Benefit (Proposed Improvement) | All ten recorded incidents are refused where recall refused none, and none of the read-only commands from those sessions is. Verified red first: with `bash-write-guard.sh` replaced by an always-allow stub the suite reports 49 failures | pass |

- **Divergence (T1):** extracting the decision into `lib/spec-lease.sh` first broke 14 existing assertions. `roots="$(spec_lease_roots …)"` drops the trailing newline that the in-place loop used to keep, so `read` silently lost the outermost root — the enclosing workspace tree, or the only tree there is. Fixed with a here-string, with a comment naming the trap; every pre-existing assertion then passed untouched, which is what proves the decision itself did not move (D3).
- **Coverage the guard does not claim:** `gh` subcommands (`gh pr create` is named in boundaries.md § Never do #10) are outside FR-3, which speaks of git verbs; a multi-file `sed -i` is read by its last argument only. Both are fail-open misses by design, recorded here rather than left to be discovered.
- **Consolidation sub-step:** not due — `consolidation-due.py` reports below the threshold of 5.
- **Reviewer sub-step:** not required — `risk: medium`; a recorded `### Review` is mandatory for the high tier only.
- **Processes:** none started; the `/tmp` fixtures were removed after the runs.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. The guard is shared by all three harnesses (`framework/hooks/README.md` § Contract): POSIX-shell portable, and fail-open on a malformed payload as well as on an unreadable command.

## Docs updates required
- `framework/hooks/README.md` — the new guard, its event, what it recognises and its fail-open contract.
- `framework/boundaries.md` § Never do #10 — a note that the shell door is now guarded too, and that the rule still binds where the guard fails open.
