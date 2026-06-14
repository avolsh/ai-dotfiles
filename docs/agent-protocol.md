# Agent Protocol

*Last updated: 2026-06-11*

Operating procedures for AI agents working in any project that participates in the AI Agent Framework: path prefixes, two-scope model, context loading order, checklists, output conventions, and the on-demand reference material (determinism, schema sync, doc freshness, skills audit).

---

## Path prefixes

Documentation uses three path prefixes to avoid fragile relative paths
(`../../..`). Agents and humans resolve them at read time.

| Prefix | Meaning | Example resolution |
|---|---|---|
| `<system>/` | The active tool's config dir — `$CLAUDE_CONFIG_DIR`, `$COPILOT_HOME`, or `$CODEX_HOME`, each pointing at `$AI_DOTFILES/profiles/<profile>/<tool>/`. Wired by `scripts/lib/profile-links.sh` (called by both `ai-switch.sh` and `ai-profile-init.sh`): `<system>/skills/`, `<system>/spec-workflows/`, `<system>/prompts/`, `<system>/templates/`, `<system>/agents/`, `<system>/upstream/`, and `<system>/boundaries.md` resolve via whole-dir/file symlinks into `$AI_DOTFILES/framework/`, with per-entry symlinks as the fallback inside CLI-owned real dirs (e.g. `codex/skills/`). | `<system>/skills/writing-specs/SKILL.md` → `$AI_DOTFILES/profiles/personal/claude/skills/writing-specs/SKILL.md` |
| `<project>/` | Per-repo project root. Holds `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `.github/copilot/instructions/`, and (when present) project-scope `.github/copilot/skills/`, `.github/copilot/prompts/`, `.github/copilot/agents/`. Project entries extend or override system-scope catalog entries on name collision. | `<project>/docs/architecture/` → `src/github.com/tobeverse/tobevisit-content/docs/architecture/` |
| `<workspace>/` | Optional. Host-specific workspace root for multi-project workspaces. The project list lives in `<workspace>/CLAUDE.md` (or `AGENTS.md`). Single-project hosts can omit; workspace-level steps in workflows are conditional on this placeholder being configured. | `<workspace>/CLAUDE.md` → `~/vcs/geeoz/tobevisit/CLAUDE.md` |

**Rules:**

- Use `<system>/` for framework artifacts (skills catalog, spec-workflows,
  prompts, templates, boundaries) rendered into the user's tool homes.
- Use `<project>/` for project-specific resources (architecture docs, specs,
  project-scope skills/prompts/agents).
- Use `<workspace>/` only for host workspace-level references (project
  list in `CLAUDE.md`/`AGENTS.md`). Mark workflow steps that read it as
  conditional.
- Shallow relative paths (single `../` within the same directory tree) are
  acceptable.
- Deep relative paths (`../../` or deeper crossing directory boundaries) MUST
  use a prefix instead.

---

## Two-scope model

Skills, boundaries, and protocol exist at two scopes. Agents load both.

| Scope | Location | Overrides |
|---|---|---|
| **System** | `$AI_DOTFILES/profiles/<profile>/{claude,copilot,codex}/` — the dirs `CLAUDE_CONFIG_DIR` / `COPILOT_HOME` / `CODEX_HOME` point at. Wired by the shared library `scripts/lib/profile-links.sh` (single source of truth for `ai-switch.sh` and `ai-profile-init.sh`): instruction-file link, `boundaries.md`, refs (`spec-workflows prompts templates skills agents upstream`), rendered hook adapters. Whole-dir symlinks normally; **per-entry symlinks as the fallback inside CLI-owned real dirs** (e.g. `codex/skills/` with its `.system/`). `profiles/<p>/claude/settings.json` may be a symlink into `~/.claude/settings.json` — the hooks merge intentionally writes through it. Each switch writes `~/.<tool>/.active-manifest` (`profile=`, `target=`, `timestamp=`); `--reset` removes it; `ai-doctor` validates `profile` and `target`. | Base layer |
| **Project** | Per-repo: `<project>/CLAUDE.md`, `<project>/AGENTS.md`, `<project>/.github/copilot-instructions.md`, `<project>/.github/copilot/instructions/`, **`<project>/.github/copilot/skills/`**, **`<project>/.github/copilot/prompts/`**, **`<project>/.github/copilot/agents/`** (when present) | Extends system; wins on name collision |

**Skill resolution order:** project scope → system scope. When a task lists a
skill name, check the project's `.github/copilot/skills/<name>/SKILL.md`
first, then fall back to `<system>/skills/<name>/SKILL.md`. A project skill
with the same name as a system skill **wins**. Project skills with novel
names add to the active set without displacing the system catalog.

The old workspace scope (a separate layer at the workspace root containing
duplicated framework artifacts) **no longer exists** post-migration. Framework
artifacts live in `<system>` only; per-repo rules live in `<project>` only;
host workspace-map references live behind the optional `<workspace>/`
placeholder.

**Multi-project navigation principles** (adapted from monorepo patterns):

1. **Workspace root `CLAUDE.md`/`AGENTS.md` defines the project map** --
   single source of truth for project locations, purposes, and build
   commands. Optional per host.
2. **Per-project AGENTS.md defines constraints** -- each project's rules are
   authoritative within its scope.
3. **Cross-project impact analysis** -- when changing shared framework docs
   in `<system>/`, assess impact on every project listed in the workspace
   root files.

---

## Context loading order

An AI agent starting work MUST read files in this order:

1. `<system>` instruction file for the active tool (`$CLAUDE_CONFIG_DIR/CLAUDE.md`,
   `$COPILOT_HOME/copilot-instructions.md`, or `$CODEX_HOME/AGENTS.md`) --
   framework bootstrap, wired by `scripts/lib/profile-links.sh`.
2. Target project `AGENTS.md` (or `CLAUDE.md`) -- project-specific rules.
3. `<workspace>/CLAUDE.md` (or `AGENTS.md`) -- only when routing is unclear,
   the change is cross-project, or shared framework files are involved. Skip
   if the host has no `<workspace>` configured.
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
| Quick fix / typo | `<system>` instruction file + project `AGENTS.md` | -- |
| Feature work (no spec) | Above + `<system>/boundaries.md` + relevant skill(s) | `agent-protocol.md` if ambiguity arises |
| Spec-driven work | Above + current spec + `agent-protocol.md` + `spec-lifecycle.md` + stage skills (see `spec-types.md` § Skills per stage) | Question templates, ADR conventions, this doc's on-demand sections for determinism/schema-sync/doc-freshness |
| Skills audit | `<workspace>/CLAUDE.md` + `<system>/skills/` + project `<project>/.github/copilot/skills/` + upstream catalog tree | Individual upstream `SKILL.md` files |
| Framework changes | Full protocol + both scopes | All framework docs |

**Rules:**
- `<workspace>/CLAUDE.md` is **not** auto-imported; read it on demand.
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

---

## Mechanical enforcement layer

Three behavioural rules are enforced by tooling, not prose (canonical
scripts: [`framework/hooks/README.md`](../framework/hooks/README.md);
introduced by IMP-20260610-mechanize-framework-guardrails):

| Layer | Mechanism | Enforces |
|---|---|---|
| Harness hooks (Claude Code, Copilot CLI, Codex CLI) | adapter configs rendered by `ai-profile-init` | spec-status guard (PreToolUse), stamp refresh (PostToolUse), `ai doctor --fast` (SessionStart) |
| Git pre-commit (`make install-git-hooks`) | `scripts/git-hooks/pre-commit` | secrets scan + stamp freshness for every client, incl. IDE agents |
| CI / `make check` | `validate-specs`, `lint-rules`, `validate-anchors`, `tests` | artifact-level invariants |

A hook denial is not an obstacle to route around — it is the rule firing.
Fix the state (e.g., advance the spec through its gate), don't bypass the
hook. `scripts/ai-doctor.sh` (`make doctor`) verifies profile symlinks and
manifest consistency; run it whenever `<system>/` path resolution misbehaves.
All remaining boundaries rules stay prose-enforced — hooks narrow the gap,
they do not replace judgment.

## Pre-flight checklist (before any file edit)

- [ ] Read the target project's architecture docs.
- [ ] Read the active spec's `## Summary` first, then the current stage /
      task details.
- [ ] Identify which bounded context the change belongs to.
- [ ] Read existing code in that context directory.
- [ ] Read relevant reference schemas from the project's docs.
- [ ] Read the baseline at
      `<project>/docs/domain/<feature>.md` if the change touches a
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
      [`baseline-citations.md`](baseline-citations.md).
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

## Canonical rules: the one-hop convention

Mandatory rules (MUST / Always / Never) live in exactly two canonical
files — `framework/boundaries.md` and
`framework/spec-workflows/spec-lifecycle.md` — or in a reference file
those two link **directly**. The invariant:

> An agent reading `boundaries.md` or `spec-lifecycle.md` MUST reach any
> mandatory rule's full statement in **at most one link hop**. Chains of
> two or more hops are where agents drift.

When editing framework rules:

- **Adding a rule:** state it fully in one of the two canonical files, or
  in a file they already link directly (e.g. `splitting-rules.md`,
  `bounded-autonomy-rules.md`). Do not bury it deeper.
- **Moving a rule:** keep its `<a id="...">` anchor with the statement and
  update the phrase entry in `docs/rule-canonical-map.md` in the same
  commit (the map is machine-read by `make lint-rules`).
- **Citing a rule:** link to its anchor; never restate the text —
  `make lint-rules` fails on verbatim duplicates, and
  `make validate-anchors` fails on links to renamed or missing anchors.

The invariant was verified to hold for the full rule corpus on 2026-06-10
(IMP-20260610-reduce-self-referential-overhead, T1 trace).

---

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
| Code change in a baselined feature | Update `<project>/docs/domain/<feature>.md` to reflect post-closure state (closure rule) |
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

## Delegation contract

Spec authoring, the Split check, and task decomposition run **inline in
the main context** ([`writing-specs/references/authoring-steps.md`](../framework/skills/writing-specs/references/authoring-steps.md));
they are not delegated. A sub-agent is used only on mechanical need
(isolation / parallelism / read-only) — see the gate in
[`framework/agents/README.md`](../framework/agents/README.md). The one
bespoke sub-agent is the read-only `reviewer`.

### Claude Code path

Use the `Agent` tool:

```
Agent({
  subagent_type: "<name>",            # matches the agent's `name:` field
  description: "<short task summary>",
  prompt: "<self-contained brief>"     # everything the agent needs cold
})
```

Three orchestration rules: the prompt MUST be **self-contained**
(sub-agents start cold — include all paths, inputs, expected-output
formats), produce a **single deliverable**, and never **nest delegation**
(keep the call graph one level deep).

### Copilot / Codex fallback path

These harnesses do not implement an `Agent`-style sub-call. The
principle is harness-independent: run the agent as a **separate
empty-context session** whose only inputs are the brief the contract
names. For the `reviewer` that is the spec + `git diff` + the
`reviewing-changes` skill.

### Task-start preflight (precedent files)

The pre-flight checklist's "precedent files read" item (per
[`boundaries.md § Always do #4`](../framework/boundaries.md)) is the
main agent's own `Grep`/`Glob` over the task's Files column — or the
built-in read-only explore sub-agent returning a summary for heavy
digging. There is no bespoke precedent agent.

### Agent contract reference

Full schema, body structure, naming convention, and the inline example
are in [`framework/agents/README.md`](../framework/agents/README.md).
Enforcement:

- `make validate-specs` → `agent_schema_*` checks for required fields, filename ↔ `name` parity, enum compliance, `tools-allowed` non-empty
- `make lint-rules` → flags inline restatements of an agent's `description:` field outside `framework/agents/`

## Standard agent directives

All boundary rules from [`boundaries.md`](../framework/boundaries.md) apply
(system + project scope). Below are additional protocol details not covered
by boundaries.

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

---

## On-demand reference

Load the relevant subsection when the scenario applies.

### Determinism and traceability

- **Batch size:** configurable per operation via project-specific configuration
  (see project `AGENTS.md`).
- **Evaluation:** each item independently -- no cross-item influence.
- **Ordering:** stable sort by canonical ID before batching.
- **Traceability:** every AI-generated result must record:
  - `model` -- AI model name
  - `classifiedAt` -- ISO 8601 timestamp
  - `batchId`
  - `promptVersion` -- semver tag from prompt version constant

### Schema-code sync

- Reference schemas in `docs/reference/` are the **specification**.
- Source-code type definitions must conform to reference schemas.
- When an agent modifies a type definition, it MUST update the corresponding reference doc.
- When a human updates a reference schema, the corresponding spec must include code updates.

### Document freshness

- Every doc SHOULD include a `*Last updated: YYYY-MM-DD*` line after the title.
- Agents SHOULD flag docs that reference non-existent files or code paths.
- During spec implementation, agents MUST update the `Last updated` date on every modified doc.
- Docs not updated for 6+ months should be reviewed for staleness.

### Skills audit

The skills audit is a **separate on-demand task**, not part of automatic
bootstrap. Run it when the user explicitly requests it or as a setup task.

The agent verifies that system-scope and project-scope skills cover the
workspace's **high-leverage workflows**, using the **local submodule** at
`<system>/upstream/claude-skills/` as the reference catalog.

**Procedure:**

1. **Inventory existing system skills** --
   Read `.github/copilot/skills/` and list all skill folders.

2. **Inventory high-leverage workflows** --
   From workspace root files, project AGENTS docs, and active production code:
   list workflows that are recurring, non-obvious, error-prone, or
   expensive to rediscover.

3. **Gap analysis** --
   For each workflow, check:
   - Is there a concise always-on instruction already covering it?
   - Is there a system-scope skill covering it?
   - Is there a project-scope skill covering it?
   - If neither, would a skill materially reduce repeated mistakes?

4. **Check upstream skill catalog (local submodule)** --
   Read `<system>/upstream/claude-skills/` directory tree.
   For each justified gap, check if a matching skill exists upstream.
   If found: recommend merge/vendor/defer/do-not-vendor.
   If not found: log the gap for manual skill creation.

5. **Report** --
   Present to human:
   - Skills already present (system + project)
   - High-leverage gaps found
   - Candidate upstream matches
   - Recommendation per candidate
   - Gaps remaining (need manual authoring)
   - No files changed during the audit
