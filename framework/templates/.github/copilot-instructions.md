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
1. This file (`.github/copilot-instructions.md`)
2. `docs/README.md` — documentation index
3. Project-specific module map or architecture docs
4. Target code directory

## Non-negotiable rules

- One task at a time, preflight proof, "The Bottom Line" gate.
- Never commit `.env` or secrets.
- Include tests in the same change as feature logic.
- "continue" = next single task only.

## Available skills

| Skill | Path | When to use |
|---|---|---|
| `agent-protocol` | `.github/copilot/skills/agent-protocol/SKILL.md` | Context loading, checklists, output conventions |
<!-- Add project-specific skills below -->

## Workflows

| User says | Load prompt | Skills |
|---|---|---|
| "create CR", "new feature" | `.github/copilot/prompts/create-spec.prompt.md` | writing-specs, agent-protocol |
| "create IMP", "improve", "refactor" | `.github/copilot/prompts/create-spec.prompt.md` | writing-specs, agent-protocol |
| "bug", "triage" | `.github/copilot/prompts/bug-triage.prompt.md` | writing-specs |
| "plan", "break into tasks" | `.github/copilot/prompts/plan-spec.prompt.md` | writing-specs, model-selection |

## Note for non-Copilot agents

When you read a `.prompt.md` file and see `#skill:<name>`, load the
corresponding skill file: `.github/copilot/skills/<name>/SKILL.md`

## Build and Run
- `<build command>`
- `<test command>`

