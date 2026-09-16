# IMP-20260914-resume-spec-prompt — worked examples

*Last updated: 2026-09-16*

Evidence for AC-1 – AC-3. Recorded 2026-09-16 by Claude Opus 5 (the implementing session), walking
[`resume-spec.prompt.md`](../../../../framework/prompts/resume-spec.prompt.md) step by step against three throwaway
fixture projects. Each fixture is a git repo with one `CR` spec, a committed `src/` tree and the task table below; the
commands shown are the ones the prompt's steps call for, with their real output. **Limitation:** the walk was done by
the session that wrote the prompt, not a cold one; AC-1 was then re-run cold (below).

No-edit proof: a SHA over every non-`.git` file of each fixture, taken before and after the walk.

| Fixture | Before | After |
|---|---|---|
| ac1 | `cee4c930f339` | `cee4c930f339` |
| ac2 | `bdefc246a758` | `bdefc246a758` |
| ac3 | `5b942c9601c1` | `5b942c9601c1` |

## AC-1 — an unapproved task is not skipped

Fixture `CR-20260910-fixture-awaiting`, `status: in-progress`; T1 `☑ done`, T2 `◐ awaiting approval`, T3 `☐ pending`.

- Step 1 — one active in-progress spec (`spec-status.py`: `CR-20260910-fixture-awaiting … in-progress … 1/3`).
- Step 4 — first row not `☑`/`⊘` is **T2** (`src/format.py`, `◐ awaiting approval`).
- Step 5 — rebuilt from `git log --name-only -- src/format.py` (`fdfdfcf fixture: T1+T2 work`) and a clean working tree
  for that path. Output posted:

  > **Bottom Line — T2 Add formatter** *(re-posted on resume)* · Files touched: `src/format.py` (committed in
  > `fdfdfcf`) · Acceptance criteria satisfied: per T2 row · Tests / verification run: not re-run on resume ·
  > Divergences flagged: none recorded · Open questions: none. **Approve T2?**

- Stopped. T3 not started; no preflight posted; no file changed (hashes above).

### AC-1 cold re-run

Recorded 2026-09-16 by a fresh general-purpose sub-agent (Claude Opus 5) with no chat history, given only the prompt
path, the fixture root and "resume", and told not to modify files. Fixture hash after the run: `cee4c930f339`
(unchanged).

- Stopped at step 5: T2 `◐` → re-posted T2's Bottom Line in the canonical six fields, marked *re-posted on resume*,
  asked "Approve T2?", stated that approval flips only T2 and a change request returns it to `☐`. T3 not started.
- Commands: `spec-status.py <root>`; `cat` of the active spec; `git log --stat -- src/format.py`; `git status
  --porcelain`; `git show fdfdfcf`.
- Ambiguities it reported: (1) CLAUDE.md names `<system>/docs/agent-protocol.md`, the file is at the repo's
  `docs/agent-protocol.md` — it tried `framework/docs/` first; (2) step 5 does not say what to put in a Bottom Line
  field with no record — it wrote "none can be named" rather than inventing; (3) step 5 is silent on a later task's
  file committed early — it flagged `src/cli.py` as a divergence and left it alone.

## AC-2 — a clean resume reaches preflight

Fixture `CR-20260910-fixture-clean`, `status: in-progress`; T1 `☑`, T2 `☑`, T3 `☐ pending`. Working tree: `src/cli.py`
modified (T3's file) and an untracked `scratch.txt` (no task's file).

- Step 4 — resume row is **T3** (`src/cli.py`).
- Step 6 — `git status --porcelain` intersected with T3's Files column:
  `M src/cli.py` — reported as left-behind work, not discarded. `scratch.txt` is outside the Files column and is not
  reported.
- Step 7 — posted the task-start note: *Task T3 · precedent files read: `src/parse.py`, `src/format.py` · loaded
  skills: none listed for T3*, then stopped for go.
- No file changed (hashes above).

## AC-3 — early statuses route away

Fixture `CR-20260910-fixture-plan`, `status: plan`, all rows `☐`.

- Step 3 — `status: plan` → handed over to `plan-spec.prompt.md` and stopped. Step 4 onward not reached.
- No file changed (hashes above).
