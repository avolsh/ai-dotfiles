---
id: IMP-20260830-canonical-scaffold-and-verification-rules
type: IMP
date: 2026-08-30
status: done
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
  - tobevisit-content
affected-docs:
  - framework/boundaries.md
  - framework/templates/project/_canonical.md
  - framework/skills/bootstrapping-project/references/scaffold-manifest.md
  - docs/bootstrapping-project.md
affected-code:
  - scripts/ai-project.sh
skills:
  - writing-specs
  - writing-docs
  - bootstrapping-project
model-suggestion: default
---

# IMP-20260830-canonical-scaffold-and-verification-rules

*Last updated: 2026-08-30*

<!-- Body 144 lines, over the 120 budget: 9 FRs across four clusters the Split Decision recommends
     keeping together. The overage is itself evidence for that call and shrinks if the human splits. -->

## Summary

- **Goal:** Put the rules that hold in every project into system scope, and make the project scaffold
  seed the sections those rules refer to — so a new project starts with them instead of relearning them.
- **Scope:** Three behavioural rules into `boundaries.md`; two section skeletons into
  `templates/project/_canonical.md`; the bootstrap authorities corrected to the `_canonical.md` model
  they already run on; the now-duplicated copies removed from `tobevisit-content`.
- **Out of scope:** Project-specific verification content — commands, step counts, output formats.

## Current State

<!-- Over the 12-line cap: three independently evidenced findings in three different files. -->

**A system-scope rule points at a section the scaffold never creates.** `boundaries.md` § Always do #7
says to run build and test *"per the project's agent-instructions file § Build and Run"*.
`templates/project/_canonical.md` has no such section — only a header field, `**Build and Run:**
<build / test commands>` — and no `## Verification by Change Type` at all. Both exist in
`tobevisit-content` only because it grew them itself, after three task gates passed on a suite that
had never compiled the admin app (log, 2026-08-11, 2026-08-27).

**Three rules that hold everywhere are stranded in that one project** and appear in neither
`boundaries.md` nor `agent-protocol.md`: a command's tail is not its result; an exported signature
change is a breaking API change whatever the file looks like; no verification step rewrites the
source it checks.

**The bootstrap authorities describe a model the framework left behind.** `_canonical.md` occurs zero
times across `scaffold-manifest.md` and `docs/bootstrapping-project.md`; the manifest's ten required
artifacts omit it, calling `.github/copilot-instructions.md` canonical and `CLAUDE.md` a slim
`@`-import. The installed `sync-agents.sh` reads `_canonical.md` and writes all three as byte-identical
renders — which is what `boundaries.md` #1 states and what both real projects are. `ai-project.sh`
does copy `_canonical.md`, then prints *"Fill in `<placeholder>` markers in
`.github/copilot-instructions.md`"*: a generated file, which #1 forbids editing and the next
`make sync-agents` overwrites.

## Proposed Improvement

The three rules move up to `boundaries.md`, reaching every project every session instead of waiting to
be rediscovered. The two sections become skeletons in the template — headings and an empty table, no
commands — so a new project has somewhere to put its answer rather than having to invent the question.
The manifest, guide and scaffold message are corrected to name `_canonical.md`. The duplicated
sentences then leave `tobevisit-content`, since a rule in two places drifts in one of them.

**Measurable benefit:** the three rules are reachable from 1 project today, from all of them after;
`§ Build and Run` is referenced by 1 system-scope rule and seeded by 0 templates, seeded by 1 after;
`_canonical.md` appears in 0 of 2 bootstrap authorities, in 2 after.

## Requirements

- FR-1: `boundaries.md` MUST state that a command's tail is not its result — the exit status is, and a summary line covers only what it names.
- FR-2: `boundaries.md` MUST state that changing an exported signature is a breaking API change regardless of what kind of file declares it: ask who compiles against it.
- FR-3: `boundaries.md` MUST state that no verification step rewrites the source it checks, and that formatting is a developer command rather than a verification step.
- FR-4: `templates/project/_canonical.md` MUST carry a `## Build and Run` section shaped as an ordered table of single-purpose steps, each with its own exit status, with placeholder rows.
- FR-5: `templates/project/_canonical.md` MUST carry a `## Verification by Change Type` section with an empty `| What changed | Minimum verification |` table and the project-independent instruction to default to the broadest command and narrow only on demonstrated reach.
- FR-6: `scaffold-manifest.md` and `docs/bootstrapping-project.md` MUST list `_canonical.md` as a required project artifact and describe the three agent files as renders of it.
- FR-7: `ai-project.sh`'s next-steps message MUST name `_canonical.md` as the file to fill in, not a generated one.
- FR-8: `boundaries.md` § Ask first #6 MUST NOT present the expired stability window as a live constraint.
- FR-9: `tobevisit-content/_canonical.md` MUST NOT restate a rule FR-1 through FR-3 moved into system scope; its project-specific verification content stays.

## Acceptance Criteria

### AC-1: The three rules are in system scope, stated without a project's commands (FR-1, FR-2, FR-3)

Given `framework/boundaries.md`
When an agent loads system-scope boundaries in any project
Then each rule is present, numbered, and names no project's commands
Evidence: grep per rule; `make validate-anchors` if a rule takes an anchor

### AC-2: A freshly scaffolded project has somewhere to record its verification (FR-4, FR-5)

Given an empty scratch directory
When `ai-project` runs and `make sync-agents` follows
Then `_canonical.md` and all three rendered files carry both sections, with placeholder rows and no commands
Evidence: scaffold into a scratch directory, read the rendered files, discard

### AC-3: The bootstrap authorities name the file the scaffold runs on (FR-6, FR-7)

Given the manifest, the guide and `ai-project.sh`
When a human follows only their printed and documented steps on an empty directory
Then the file they are told to fill in is `_canonical.md`, and the manifest lists it as required
Evidence: the same scratch scaffold as AC-2

### AC-4: No expired constraint reads as live (FR-8)

Given `boundaries.md` § Ask first, read on any date after 2026-07-12
When the section is read
Then no entry presents the closed window as a current restriction
Evidence: reading the section

### AC-5: Each moved rule is stated once (FR-9)

Given `boundaries.md` and `tobevisit-content/_canonical.md` after the move
When both are read
Then each rule appears in exactly one, and `tobevisit-content` keeps every fact specific to itself
Evidence: grep both per rule; `make docs-check` and `make sync-agents-check` in `tobevisit-content`

## Design

Skipped — no UI surface; rules, template headings and one printed line.

## Out of Scope

- OS-1: The Plan stage verifying a spec's factual claims against the tree — same framework, different stage and files; it has its own recurrence record and gets its own spec.
- OS-2: Retrofitting projects other than `tobevisit-content` — `tobevisit-web` was not read in this session, and a blind retrofit is a guess.
- OS-3: The sync-script debt the manifest already records (every bootstrapped project carrying an older `sync-agents.sh`), named there as needing its own spec.
- OS-4: Any command, step count or output format in the template — a skeleton that ships a default command teaches the wrong one to every project that keeps it.

## Split Decision

**T1 and T3 both fire.** Four clusters: the three rules (α, `boundaries.md`), the template skeletons
(β), the bootstrap authorities (γ, manifest + guide + `ai-project.sh`), the downstream reconciliation
(δ, `tobevisit-content`). α, β and γ are independently testable — T1; δ is a different repo — T3.

**Recommendation: keep as one.** On δ, `boundaries.md § Ask first #5` requires a cross-repo change to
be coordinated *"via a single spec listing all repos in `affected-repos`"*; splitting would produce the
state FR-9 removes — α landing without δ leaves each rule stated twice, drifting. On α/β/γ the
exception is **E5** (documentation corpus), which applies only to a spec shipping *zero* behavioural
code change: FR-7's one printed line in `ai-project.sh` is the whole defect. **For the human:** accept
E5 over that line, or move FR-7 out and lose the most visible half of the bootstrap fix.

**Plan-stage override (P3).** Decomposition puts Tasks 1 and 2 in groups with no dependency between
them, firing P3. That is clusters α and β, which the Specify gate adjudicated above under **E5** and
`§ Ask first #5`; recorded as an override per `authoring-steps.md § C` step 6, table written at
`status: plan`. **P2 is `unknown`** — `ai-dotfiles` has no `docs/architecture/module-map.md` and no
bounded contexts to span. P1 does not fire at 5 tasks.

## Tasks

> All five tasks are `☑ done`; the spec closed on 2026-08-30.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | The three rules into system scope, and § Ask first #6 resolved. Each stated without naming any project's commands, numbered into § Always do, and not registered in `rule-canonical-map.md` — that inventory tracks *observed* verbatim restatements, there are none yet, and its linter cannot see sibling repos anyway. **Closes AC-1, AC-4 (FR-1, FR-2, FR-3, FR-8).** | `framework/boundaries.md` | `docs/rule-canonical-map.md`, `scripts/lint-rules.py`, `../../src/github.com/tobeverse/tobevisit-content/_canonical.md` | — | writing-docs | deep | ☑ done |
| 2 | The two section skeletons in the project template: `## Build and Run` as an ordered table of single-purpose steps each with its own exit status, and `## Verification by Change Type` with an empty two-column table and the broadest-command-by-default instruction. Placeholder rows only — no command, count or format. The workspace template gets neither: it has no build, by the manifest's own row. **Closes AC-2 (FR-4, FR-5).** | `framework/templates/project/_canonical.md` | `framework/templates/workspace/_canonical.md`, `../../src/github.com/tobeverse/tobevisit-content/_canonical.md` | — | writing-docs, bootstrapping-project | default | ☑ done |
| 3 | The bootstrap authorities corrected to the model they already run on: `_canonical.md` as a required project artifact, the three agent files as its renders, the manifest's section list extended with what Task 2 added, and `ai-project.sh`'s next-steps message pointing at `_canonical.md` instead of a generated file. **Closes AC-3 (FR-6, FR-7).** | `framework/skills/bootstrapping-project/references/scaffold-manifest.md`, `docs/bootstrapping-project.md`, `scripts/ai-project.sh` | `framework/templates/project/.github/scripts/sync-agents.sh`, `framework/boundaries.md` | 2 | bootstrapping-project, writing-docs | default | ☑ done |
| 4 | Remove the three now-duplicated rules from `tobevisit-content/_canonical.md`, keeping every verification fact specific to that project, and re-render. Cross-repo half of the spec, per `§ Ask first #5`. **Closes AC-5 (FR-9).** | `../../src/github.com/tobeverse/tobevisit-content/_canonical.md`, its `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md` | `framework/boundaries.md` | 1 | writing-docs | default | ☑ done |
| 5 | Closure verification: `make check` in `ai-dotfiles` (links-check, install-check, validate-specs, lint-rules, validate-anchors, tests), `make docs-check` in `tobevisit-content`, and a scaffold into a scratch directory driven only by the printed and documented steps — the evidence AC-2 and AC-3 both close on. Record counts and the scaffold transcript in Closure Evidence. **Closes AC-2, AC-3 evidence.** | this spec (Closure Evidence) | `scripts/ai-project.sh`, `Makefile` | 3, 4 | writing-specs | default | ☑ done |

## Closure Evidence

`make check` in `ai-dotfiles` exits **0** — links-check (142 files), install-check, validate-specs
(30 specs), lint-rules (13 rules / 45 phrases), validate-anchors (75 fragment links), and eight
self-test suites. `npm run build` in `tobevisit-content` exits **0** end to end. None of the five
criteria is observation-shaped: every `When` is a command or a documented step.

| AC | Evidence |
|---|---|
| AC-1 | § Always do #19, #20, #21 present in `boundaries.md`, one occurrence each. The falsifiable half is the second clause — that they name no project's commands: `grep -E "make \|npm \|jest\|tsc"` over the three new entries returns nothing. `profiles/personal/claude/boundaries.md` shows the new date, confirming propagation is a symlink and needs no sync step |
| AC-2 | `ai-project` into an empty scratch directory creates `_canonical.md` carrying both sections; `make sync-agents` renders them into all three agent files (2 of 2 in each). Re-run at closure with `make sync-agents-check` clean. `grep -cE "make (test\|build)\|npm \|jest"` over the scaffolded `_canonical.md` returns **0** — the skeleton ships no command, per OS-4 |
| AC-3 | The same scaffold, driven only by what is printed and documented: the next-steps line now reads *"Fill in `<placeholder>` markers in `_canonical.md`"*. It was captured failing first — the run before Task 3 printed `.github/copilot-instructions.md`, a generated file that `§ Always do #1` forbids editing and the next `make sync-agents` overwrites. All 11 manifest artifacts verified present against the real scaffold |
| AC-4 | § Ask first #6 reads *"closed 2026-07-12, not extended"* and routes the reader to #3 and #4. The `#stability-window` anchor is kept so dates in specs written under it still resolve; `make validate-anchors` passes at 75 links |
| AC-5 | Each of the three rules: 1 occurrence in `boundaries.md`, **0** in `tobevisit-content/_canonical.md`. The project keeps 21 mentions of its own commands. What replaced each removal is a reference that *adds* a local fact rather than restating the system one — the signature rule now reads that `src/app` compiles under a different `tsconfig`, so "who compiles against it" has two answers there |

### Deviation — the manifest gap was larger than the spec's own Current State

`§ Ask first #6` aside, the spec was written believing the fix was two missing sections. The manifest
turned out to describe a superseded model whole: `.github/copilot-instructions.md` as canonical,
`CLAUDE.md` as a slim `@`-import, and `_canonical.md` absent from the required artifacts. FR-6 covered
it, but the row count moved 10 → 11 and 6 → 7 rather than one row gaining a mention.

### Not done, deliberately

The three rules are **not** registered in `docs/rule-canonical-map.md`. That inventory tracks observed
verbatim restatements and there are none yet; more to the point, `lint-rules.py` searches only this
repository, so registering them would not have caught a restatement in `tobevisit-content` — the one
drift FR-9 exists to prevent. Decided at the Plan gate, recorded here so a later reader does not
mistake it for an oversight.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. This spec edits the files that
govern all other work: § Ask first #3 and #4 apply to its own tasks.

## Docs updates required

Every file in `affected-docs`, plus `tobevisit-content/_canonical.md` re-rendered with
`make sync-agents`. What changes in each is FR-1 through FR-9; not restated here.

## Rollout / migration notes

- FR-1 to FR-3 reach existing projects with no action — `boundaries.md` loads every session — while
  the template change is forward-only. That asymmetry is the whole shape of this spec: rules to
  system scope, skeletons to the template, and FR-9 to clear the one project already carrying both.
- No verification command changes behaviour; `make docs-check` and `make sync-agents-check` in
  `tobevisit-content` are the only mechanical gates this spec can fail.
