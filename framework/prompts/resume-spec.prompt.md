---
description: "Resume — pick up an in-progress spec at the right task in a fresh session"
---
#skill:writing-specs

Resume a spec after an interruption. Reads state from the spec only — status and the task table — and never infers approval from chat it cannot see. Lifecycle: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). Task-row values: [`boundaries.md § Always do #11`](../boundaries.md#task-row-status-in-place).

## Preconditions
- A fresh session; the human said "resume", optionally with a spec ID.

## Steps
1. **Locate the spec** — by the given ID under `docs/specs/active/`. With no ID, take the single active spec at `status: in-progress`; with zero or several, list each candidate (ID, status, tasks done/total — `make specs-view` prints them) and stop for the human to pick.
2. **Read** its `## Summary`, front-matter `status`, and the `## Tasks` table.
3. **Route by status** — `specify` → hand over to [`create-spec.prompt.md`](create-spec.prompt.md); `plan` → [`plan-spec.prompt.md`](plan-spec.prompt.md); `done` → report it closed. None of these edits a file here; stop.
4. **Find the resume row** — the first task row whose Status is neither `☑ done` nor `⊘ descoped` / cancelled. No such row → every task is approved; hand over to spec completion ([`agent-protocol.md § Interpreting "continue"`](../../docs/agent-protocol.md)) and stop.
5. **Row at `◐ awaiting approval`** — re-post that task's Bottom Line in the [canonical format](../../docs/agent-protocol.md#the-bottom-line--canonical-format), rebuilt from the row and the git history / working-tree diff of its Files column, marked *re-posted on resume*; ask for approval of that task and stop. Approval flips that row to `☑` and nothing else; a change request returns it to `☐`.
6. **Row at `☐ pending`** — before any edit, report every uncommitted change (`git status --porcelain`) touching a path in the row's Files column, or `none`. Such changes are work the interrupted session left behind: name them, never discard or overwrite them.
7. **Preflight** — run the [pre-flight checklist](../../docs/agent-protocol.md#pre-flight-checklist-before-any-file-edit) and post the [task-start hard gate](../../docs/agent-protocol.md#task-start-hard-gate-mandatory-proof-in-chat) note for that task, then stop for the human's go.

## Hard rules
- Never start a task whose predecessor row is `◐` — approval is unknown until the human gives it (see [`boundaries.md § Never do #6`](../boundaries.md#continue-single-task-only)).
- Never flip a task row or the front-matter `status` on the strength of chat history this session did not see; this prompt flips a row only on an approval given in this session.
- No file edit before step 7's note is posted.
