---
name: "agent-protocol"
description: "Operating procedures for AI agents. Context loading, checklists, output conventions, determinism. Use for spec-driven or non-trivial tasks."
---

# Agent Protocol

*Last updated: 2026-04-29*

Operating procedures for AI agents working in the workspace. Covers context
loading, checklists, output conventions, determinism, and document freshness.

## Path prefixes

Documentation uses two path prefixes to avoid fragile relative paths
(`../../..`). Agents and humans resolve them at read time.

| Prefix | Meaning | Example resolution |
|---|---|---|
| `<project>/` | Target project root (where project `AGENTS.md` lives) | `<project>/docs/architecture/` → `src/github.com/tobeverse/tobevisit-content/docs/architecture/` |

**Rules:**

- Use `<project>/` for project-specific resources (architecture docs, specs, project skills).
- Shallow relative paths (single `../` within the same directory tree) are acceptable.
- Deep relative paths (`../../` or deeper crossing directory boundaries) MUST
  use a prefix instead.

## Two-scope model

Skills, boundaries, and protocol exist at two scopes. Agents load both.

| Scope | Location | Overrides |
|---|---|---|
| **System** | `.github/copilot/skills/` (workspace root) | Base layer |
| **Project** | `<project>/.github/copilot/skills/` | Extends system; wins on conflict |

**Skill resolution order:** project scope then workspace scope. When a task
lists a skill name, check the project's `.github/copilot/skills/` first, then
fall back to the workspace `.github/copilot/skills/`.

**Multi-project navigation principles** (adapted from monorepo patterns):

1. **Root PROJECTS.md defines the workspace map** -- single source of truth
   for project locations, tech stacks, and build commands.
2. **Per-project AGENTS.md defines constraints** -- each project's rules are
   authoritative within its scope.
3. **Cross-project impact analysis** -- when changing shared framework docs
   in `.github/copilot/`, assess impact on all projects listed in `PROJECTS.md`.

## Context loading order

An AI agent starting work MUST read files in this order:

1. Root `AGENTS.md` (workspace root) -- bootstrap.
2. Target project `AGENTS.md` -- project-specific rules.
3. `PROJECTS.md` -- only when routing is unclear, the change is cross-project,
   or shared framework files are involved.
4. Relevant spec from the project's `docs/specs/active/` (if working on a spec).
   Once the spec exists, load the current spec file rather than the template.
   Read `## Summary` first to anchor Goal, Scope, and Out of scope before
   reading detailed requirements or tasks.
5. Specific docs referenced by the spec's `affected-docs` field that are
   needed for the current stage or task.
6. Existing code in the target bounded context directory needed for the
   current stage or task.
7. **The nearest existing implementation** -- if the task creates something
   that already has a precedent, read the existing one first and follow its
   structure, naming, error handling, and patterns.
8. **Skills listed for the current work** -- resolve using two-scope lookup
   (project then workspace). Read each `SKILL.md` before editing any file
   (code, spec, or doc). Skills apply to all workflow stages — Specify,
   Plan, Visualize, and Task — not only to coding. Skills are listed in the
   spec's front-matter `skills` field and the task row's "Skills" column, and
   they may also be restated in the spec's "Agent instructions" section.
   Load reference files inside the skill folder if deeper detail is needed.
   Open `skills/README.md` only when you need to discover or resolve a skill
   name; if the skill list is already known, read the relevant `SKILL.md`
   files directly. For spec creation or spec editing, load the workspace skill
   `<system>/skills/writing-specs/SKILL.md` unless a project-scope
   override exists.

### Context window budget

Load only what the current task requires. Not every task needs the full protocol.

| Task type | Load (minimum) | Load (on demand) |
|---|---|---|
| Quick fix / typo | Root `AGENTS.md` + project `AGENTS.md` | -- |
| Feature work (no spec) | Above + project `boundaries.md` + relevant skill(s) | `agent-protocol.md` if ambiguity arises |
| Spec-driven work | Above + current spec + `agent-protocol.md` + `spec-lifecycle.md` + stage skills (see `spec-types.md` § Skills per stage) | Question templates, ADR conventions, `agent-protocol-reference.md` for determinism/schema-sync/doc-freshness |
| Skills audit | `PROJECTS.md` + `.github/copilot/skills/` + upstream catalog tree | Individual upstream `SKILL.md` files |
| Framework changes | Full protocol + both scopes | All framework docs |

**Rules:**
- `PROJECTS.md` is **not** auto-imported; read it on demand.
- `affected-docs` and `affected-code` are planning inventories, not bulk-read
  lists. Load only the entries needed for the current stage or task, and skip
  unrelated or `(new)` entries until they become relevant.
- Agents SHOULD load files in priority order and stop when the immediate
  task's context is satisfied.
- Skills are always loaded on demand (never preloaded at session start).

### Minimizing exploratory reads

Exploratory reads (Glob/Grep to discover files, reading directories to
understand structure) are the main source of wasted tokens across sessions.
Three mechanisms eliminate most exploration:

1. **`module-map.md`** — use it for orientation instead of scanning
   directories. It maps bounded contexts to key files, workflow steps to
   contexts, and cross-cutting files to their purpose. Keep it up to date
   (see Post-task checklist).
2. **Specific `affected-code` paths in specs** — during the Plan step,
   refine directory-level entries into specific file paths. The task table's
   "Files" column must list exact paths so agents load only those files.
3. **Task table as the load manifest** — when starting a task, the agent
   reads the files listed in the task's "Files" column plus the nearest
   precedent. No directory scanning needed if the Plan step did its job.

## Pre-flight checklist (before any file edit)

- [ ] Read the target project's architecture docs.
- [ ] Read the active spec's `## Summary` first, then the current stage /
      task details.
- [ ] Identify which bounded context the change belongs to.
- [ ] Read existing code in that context directory.
- [ ] Read relevant reference schemas from the project's docs.
- [ ] Read the baseline at
      `<project>/docs/requirements/<feature>.md` if the change touches a
      feature with an existing baseline.
- [ ] Check for active specs that may conflict with the change.
- [ ] **Read the nearest precedent implementation** -- find the closest
      existing code that does something similar, list the files read, and
      identify the patterns to follow.
- [ ] **Load all skills listed for the current work** -- resolve project-first,
      then workspace. List each loaded skill with its full path (system or
      project scope). This applies to spec editing (Specify, Plan) as well
      as coding (Task).

## Task-start hard gate (mandatory proof in chat)

Before the first file edit of each task, the agent MUST post a short preflight
note in chat containing all of the following:

- `Task #` being implemented
- precedent files read (paths)
- loaded skill files (full `SKILL.md` paths -- system or project scope)

No code/doc edits are allowed before this proof note is posted.

## Post-task checklist

This checklist applies **after every task**, not only once at the end of
a spec. Each task must independently pass all checks before proceeding.

- [ ] All acceptance criteria satisfied with documented evidence.
- [ ] Edge cases identified and tested.
- [ ] Error scenarios tested with proper error handling.
- [ ] No scope creep -- nothing built outside spec.
- [ ] Build and test pass per project's `AGENTS.md` § Build and Run.
- [ ] Affected docs updated (reference, how-to, glossary).
- [ ] Touched baselines updated to reflect post-closure actual state -- see
      FR-12 in
      `<system>/skills/writing-specs/references/baseline-citations.md`.
- [ ] `*Last updated: YYYY-MM-DD*` date set on every modified doc.
- [ ] No broken links or missing references in affected docs.
- [ ] **Pipeline step verified** (if the task touches a workflow step) -- verify output.
- [ ] **Module map updated** -- if the task added, removed, or renamed bounded
      contexts, key files, workflow steps, or cross-cutting files, update the
      project's `module-map.md`. This keeps future sessions from needing
      exploratory reads to discover what changed.
- [ ] **Process improvements logged** -- if you noticed a protocol gap,
      anti-pattern, or better approach, append an entry to the project's
      improvements log immediately (do not defer).
- [ ] Post **"The Bottom Line"** using the canonical format below and
      wait for explicit human approval before starting the next task.

## The Bottom Line — canonical format

Every post-task Bottom Line MUST include exactly these required fields,
in this order:

| Field | Content |
|---|---|
| Task # | The completed task number and title. |
| Files touched | Files created, edited, moved, or deleted. |
| Acceptance criteria satisfied | AC IDs or requirement IDs completed by the task. |
| Tests / verification run | Commands, manual checks, or the reason tests were not run. |
| Divergences flagged | Any deviation from the approved spec, plan, or expected evidence. Use `none` when there are no divergences. |
| Open questions | Questions still blocking future work. Use `none` when there are no open questions. |

Other framework files MUST cross-reference this section rather than
duplicating the field list.

## Doc update trigger matrix

| Code change type | Docs to update |
|------------------|----------------|
| New domain entity / concept | Glossary entry, update glossary index |
| New pipeline step | Architecture docs, how-to guides |
| Schema change (type definitions) | Reference schemas |
| New AI prompt | AI schema reference or new schema file |
| New external integration | System architecture doc |
| Architecture decision | New ADR |
| New category / taxonomy | Category/taxonomy reference doc |
| Config change | Relevant how-to runbook |
| Code change in a baselined feature | Update `<project>/docs/requirements/<feature>.md` to reflect post-closure state (FR-12 / closure rule) |
| New/renamed bounded context, key file, or workflow step | `module-map.md` |

## Agent output conventions

| Artifact | Convention |
|----------|------------|
| Generated code | Must follow existing patterns in the target directory |
| Generated docs | Must use the same markdown style as existing docs |
| Commit messages | `[agent] <type>: <description>` |
| Branch naming | `agent/<spec-id>-<short-description>` |
| PR description | Must reference the spec id and list all affected files |

## Controlled refactoring

Refactoring and feature work must not be mixed in the same task.
If a refactor is needed to support a feature, it must be a separate
task (or a separate spec if the scope is large).

## Standard agent directives

All boundary rules from `boundaries.md` apply (system + project scope).
Below are additional protocol details not covered by boundaries.

**Before coding each task:**
1. Follow the pre-flight checklist (above).
2. Identify the task scope -- which module and directories you will touch.

**During the task:**
3. Implement only this task. Do not modify files outside the declared scope.
4. Include tests for new domain entities and pure functions.
5. **Note any friction, protocol gap, or better approach you encounter** --
   append the formal entry to the project's improvements log immediately
   when discovered.

**After the task:**
6. Follow the post-task checklist (above).
7. Update the task status in the spec.

### Interpreting "continue" in spec work

When a user says "continue spec implementation", this grants permission for
the **next single task only**. After that task, the agent must stop again and
wait for explicit approval to proceed.

**On bug fix:**
Follow the bug-fix protocol in the BUG template.

**On spec completion:**
1. Verify all acceptance criteria.
2. Cross-check `docs/` against `src/` for discrepancies.
3. Follow the spec status lifecycle to close and archive.

## Reference material (on demand)

The following are in `references/protocol-reference.md`.
Load only when the relevant scenario applies:

- **Determinism and traceability** -- AI pipeline batch processing rules
- **Schema-code sync** -- type definition ↔ reference schema rules
- **Document freshness** -- last-updated date and staleness rules
- **Skills audit** -- on-demand audit procedure
