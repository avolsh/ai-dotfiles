# <project-name>

*Last updated: YYYY-MM-DD*

## Purpose
<one-line description>

## Tech Stack
- Language: <language>
- Database: <database>
- Testing: <test framework>

## Codebase Layout
```
src/
  <key directories>
docs/
  architecture/          -- system design
  specs/                 -- active and archived specs
```

## Context Loading
Read in this order before making changes:
1. The active tool's `<system>` instruction file (e.g., `~/.claude/CLAUDE.md`,
   `~/.copilot/AGENTS.md`, `~/.codex/AGENTS.md`) — framework bootstrap.
2. This file (`.github/copilot-instructions.md`) — project rules.
3. `docs/README.md` — documentation index.
4. Project-specific module map or architecture docs.
5. Target code directory.

## Non-negotiable rules

- One task at a time, preflight proof, "The Bottom Line" gate.
- Never commit `.env` or secrets.
- Include tests in the same change as feature logic.
- "continue" = next single task only.

## Available skills

System-scope skills are populated under each tool's home directory by
`ai-switch.sh` (rendered from `ai-dotfiles`). Project-scope skills, if any,
live under `.github/copilot/skills/` and override system entries with the
same name.

| Skill | Path | When to use |
|---|---|---|
| `agent-protocol` | `<system>/skills/agent-protocol/SKILL.md` | Context loading, checklists, output conventions |
<!-- Add project-specific skills below, pointing at <project>/.github/copilot/skills/<name>/SKILL.md -->

## Workflows

| User says | Load prompt | Skills |
|---|---|---|
| "create CR", "new feature" | `<system>/prompts/create-spec.prompt.md` | writing-specs, agent-protocol |
| "create IMP", "improve", "refactor" | `<system>/prompts/create-spec.prompt.md` | writing-specs, agent-protocol |
| "bug", "triage" | `<system>/prompts/bug-triage.prompt.md` | writing-specs |
| "plan", "break into tasks" | `<system>/prompts/plan-spec.prompt.md` | writing-specs, model-selection |

## Note for non-Copilot agents

When you read a `.prompt.md` file and see `#skill:<name>`, load the
corresponding skill file: `<system>/skills/<name>/SKILL.md` (or the
project-scope equivalent at `.github/copilot/skills/<name>/SKILL.md` if
it exists — project wins on name collision).

## Build and Run
- `<build command>`
- `<test command>`

