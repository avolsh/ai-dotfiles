---
description: "Bring an existing project's AI Agent Framework artifacts up to date"
---
#skill:bootstrapping-project
#skill:agent-protocol

You are updating an existing project so its framework artifacts match
the current workspace conventions. Use this prompt when the project
already has some `.github/copilot/` content but it may be stale or
incomplete. For brand-new projects, use
[`bootstrap-project.prompt.md`](bootstrap-project.prompt.md) instead.

Full process: [`<system>/skills/bootstrapping-project/SKILL.md`](../skills/bootstrapping-project/SKILL.md).

## Preconditions

- Project exists in `<workspace>/PROJECTS.md`.
- Project has at least `.github/copilot-instructions.md` or `AGENTS.md`
  already in place.

## Step 1 — Inventory

Read every **Required** path from
[`scaffold-manifest.md`](../skills/bootstrapping-project/references/scaffold-manifest.md)
that exists in the project, plus any **Recommended** paths.

Build a three-column table:

| Path | State | Notes |
|---|---|---|
| `.github/copilot-instructions.md` | present / missing | last updated YYYY-MM-DD |
| `docs/architecture/module-map.md` | missing | — |
| … | … | … |

## Step 2 — Diff against templates

For every present path, diff against the template in
`scaffold-manifest.md`. Flag:

- **Broken links** — references to files at old paths that no longer exist
  (e.g., `docs/agents/` instead of `.github/copilot/`).
- **Stale lifecycle** — any mention of `draft` status or 5-status flow.
- **Stale `*Last updated:*` dates** — older than 6 months.
- **Missing sections** — template has a section the artifact doesn't.
- **Project-specific rules that must be preserved** — do NOT overwrite
  these; re-integrate into the updated version.

## Step 3 — Propose minimal patches

For each flagged issue, write the smallest patch that fixes it. Preserve:

- Project-specific tech stack, commands, directory layout.
- Project-specific non-negotiable rules and boundaries.
- Project-specific skills and prompts.

Do not replace project content with generic template content just
because the template is "cleaner". Templates are starting points, not
end states.

For missing paths, render them from the template with project values.

## Step 4 — Present and gate (hard stop)

Post:

- Inventory table (Step 1).
- List of proposed changes, one per path (new file vs edit).
- For edits: short summary of what's fixed (e.g., "Point spec-templates
  reference to new `spec-workflows/templates/` location").
- For new files: reason why missing matters.

**Wait for explicit human approval** before applying changes.

## Step 5 — Apply and verify

On approval, apply patches in one pass. Then verify:

- [ ] Every link resolves (test by reading each referenced file).
- [ ] `.env` / secret material is absent from every touched artifact.
- [ ] Lifecycle mentions are consistent (4-status: specify / plan /
      in-progress / done).
- [ ] `*Last updated:*` is today's date on every modified doc.
- [ ] `PROJECTS.md` row still matches reality — update if the path,
      purpose, or build commands changed.

## Hard rules

- Never replace a project's non-negotiable rules with the generic
  template's rules — merge, don't overwrite.
- Never touch `docs/specs/archived/` — archived specs are historical.
- Never rewrite active specs to match new status names — existing specs
  keep their original status; only new specs use the 4-status lifecycle.
- Never expand scope beyond framework artifacts. Code changes require a
  separate spec.

## Anti-patterns

- **Sweeping rewrite** — touching every file because "it's easier than
  diffing." Diffs are reviewable; rewrites aren't.
- **Silent lifecycle migration** — renaming `draft` to `specify` in old
  specs. Don't do that. Update only new specs.
