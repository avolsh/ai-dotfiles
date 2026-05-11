---
description: "Scaffold a new project with the workspace AI Agent Framework"
---
#skill:bootstrapping-project
#skill:agent-protocol

You are bootstrapping a new project into the workspace. Use this prompt
only when the project has **no `.github/copilot/` directory**. For
existing projects that need a refresh, use
[`update-project.prompt.md`](update-project.prompt.md) instead.

Full process: [`<system>/skills/bootstrapping-project/SKILL.md`](../skills/bootstrapping-project/SKILL.md).

## Preconditions

- Project directory exists (e.g., `src/github.com/<org>/<name>/`).
- Project has some code or build manifest (`package.json`, `Makefile`,
  `Cargo.toml`, `go.mod`, or equivalent).
- User has confirmed this project should be added to the workspace.

## Step 1 — Scan the project

Read:

1. `<project>/package.json`, `<project>/Makefile`, or equivalent build manifest.
2. `<project>/README.md` if it exists.
3. Top two levels of `<project>/src/` or equivalent source directory.
4. `<project>/.gitignore` (to see what's excluded — clue to secrets).

Extract:

- Primary language + framework
- Test framework
- Build and test commands
- High-level directory layout
- Any existing docs or specs

## Step 2 — Classify the project

Pick the closest category: `web`, `service`, `pipeline`, `library`, `cli`,
`mobile`. This drives which artifacts to emphasize (e.g., web projects get
an Atomic Design convention bullet; pipelines get a workflow-step section).

## Step 3 — Render artifacts

For every **Required** path in
[`scaffold-manifest.md`](../skills/bootstrapping-project/references/scaffold-manifest.md),
render the artifact from its template, filling placeholders with values
from the scan.

Artifacts to render (in this order):

1. `<project>/.github/copilot-instructions.md`
2. `<project>/AGENTS.md`
3. `<project>/CLAUDE.md`
4. `<project>/.github/copilot/instructions/general.md`
5. `<project>/docs/README.md`
6. `<project>/docs/specs/active/README.md`
7. `<project>/docs/specs/archived/README.md`
8. `<project>/docs/architecture/module-map.md` (minimal placeholder if
   no contexts yet)
9. `<project>/docs/improvements-log.md` (empty "Entries" section)

## Step 4 — Validate

- [ ] Every `<angle-bracket>` placeholder is replaced.
- [ ] Every relative link resolves (compute depth to workspace root).
- [ ] No `.env`, `.env.local`, or secret value appears anywhere.
- [ ] Build and test commands match what `package.json` / `Makefile` actually define.
- [ ] At least one "Non-negotiable rule" is project-specific (not just
      the generic boilerplate).

## Step 5 — Register in workspace root files

Add the project to the workspace root `CLAUDE.md`, `AGENTS.md`, and
`.github/copilot-instructions.md`:

- Add a row to the **Projects** table with name, path, and purpose.
- Add a routing section under **Project routing** with read-first order
  and main commands.

## Step 6 — Present and gate (hard stop)

Post:

- List of files to be created (with paths).
- Diff preview for workspace root files.
- Classification (web / service / pipeline / …) and rationale.
- Any open questions (e.g., uncertain stack choice).

**Wait for explicit human approval** before writing files. On approval,
write all artifacts in one pass and propose a single commit.

## Hard rules

- Never write files before the human approves the plan in Step 6.
- Never overwrite an existing file — if one is present, switch to the
  update prompt.
- Never invent commands — derive them from the project's manifests.
- Never skip `module-map.md` — write a minimal placeholder if necessary.
