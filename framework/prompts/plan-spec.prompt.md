---
description: "Plan stage — decompose an approved spec into vertical-slice tasks"
---
#skill:writing-specs
#skill:model-selection
#skill:agent-protocol

You are running the **Plan stage**. Requirements (and architecture, if
triggered) are already approved by the human in the Specify stage.

Full process: [`<root>/.github/copilot/spec-workflows/README.md`](../spec-workflows/README.md).

## Preconditions

- Spec file exists at `status: specify` with approved requirements.
- `## Architecture` is either populated or explicitly skipped with a reason.
- Human has explicitly approved the requirements (don't run this prompt
  without that approval).

## Step 1 — Load context

1. The spec file.
2. `<root>/.github/copilot/skills/model-selection/SKILL.md` — tier assignment.
3. `SKILL.md` files for every skill listed in the spec's `skills` field.
4. Target project's `docs/architecture/module-map.md` (to refine
   `affected-code` paths into specific files).

## Step 2 — Decompose into tasks

Decompose the approved requirements into vertical-slice tasks. Expected
size after a correct Specify-stage Split check: 1–12 tasks in a single
spec.

For each task:

- **Vertical slice** — feature logic + tests in the same change.
- **Max 5 files** in the Files column. Enumerate exact paths (not
  directories). Mark new files with `(new)`.
- **Optional Source files column** — read-only load manifest with no
  file-count cap. Use it when the task must read precedent/source files
  that are not part of the edit list. Entries MUST be either exact paths
  verified against branch HEAD, or directory entries of the form
  `<dir>/ *(all N files; <intent>)*` when the read intent is a bounded
  shape scan. Directory entries state file count and intent inline;
  agents resolve them at task time with a deterministic glob and re-glob
  in the pre-task post if drift is suspected. Documentation-heavy specs
  SHOULD use the two-column form; behaviour-heavy specs MAY keep only
  the capped Files column.
- **Dependencies** — cite earlier task numbers the task depends on.
- **Skills** — list the skills needed for *this task* (subset of the
  spec-level skills).
- **Model** — pick `fast` / `default` / `deep` per model-selection skill.
- **Status column** starts as `⬜ todo`.

## Step 3 — Safety-net split check

Run [`<root>/.github/copilot/skills/writing-specs/references/splitting-rules.md § 3`](../skills/writing-specs/references/splitting-rules.md)
against the decomposed task list. If any signal fires:

1. Stop. Do not write the `## Tasks` table.
2. Flip `status` back to `specify`. Update `*Last updated:*`.
3. Return control to [`create-spec.prompt.md § Step 4`](create-spec.prompt.md)
   so the Split check re-runs against FR clusters.
4. Plan resumes only after the human approves the new split (or a
   § 4 exception) at a fresh Specify gate.

If no signal fires, continue to Step 4.

## Step 4 — Write the tasks table

Fill the `## Tasks` table in the spec. Add a line above the table:

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

If the spec's Agent instructions mention "The Bottom Line",
cross-reference the canonical format in
`<root>/.github/copilot/skills/agent-protocol/SKILL.md#the-bottom-line--canonical-format`
rather than duplicating the field list.

Refresh `## Cost Estimate` so its token range, human gate count /
minutes, and re-Specify tripwire reflect the approved task count and
task dependencies.

Flip the spec's front-matter `status` to `plan` (not `in-progress` yet).
Update `*Last updated: YYYY-MM-DD*`.

## Step 5 — Gate (hard stop)

Post a summary:

- Task count and total file count.
- Any cross-bounded-context concerns.
- Model tier distribution.
- Estimated execution order.
- `## Summary` present and still reflects the approved requirements.
- `## Cost Estimate` present and refreshed against the task count.

**Wait for explicit human approval of the plan.** Do not start Task 1.
Do not flip status to `in-progress` — that happens when Task 1 actually
begins, inside the task execution flow.

## Hard rules

- Never write tasks without approved requirements above them.
- Never exceed 5 files per task row.
- Never merge unrelated work into a single task to hit the ≤12 total.
- If § 3 signals fire, flip `status` back to `specify` and re-run the
  Split check — never force-fit an oversized plan.
- Never advance a spec to `plan` while its `depends-on:` siblings are
  not yet `done`.
