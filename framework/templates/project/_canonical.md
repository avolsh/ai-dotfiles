# <project-name>

*Last updated: YYYY-MM-DD*

**Tech Stack:** <language / database / test framework>
**Codebase Layout:** <top-level dirs>
**Build and Run:** <build / test commands>

## Boundaries

- Never commit `.env` or secrets; follow existing patterns; include tests with feature logic; update `*Last updated:*` on every modified doc.
- One task at a time; preflight proof; "Bottom Line" gate; "continue" = next single task; log improvements immediately in `docs/improvements-log.md`.
- System-scope rules: `<system>/boundaries.md`. Add project-specific rules below.

## Workflows

| User says | Load prompt |
|---|---|
| "create CR", "new feature", "specify" | `<system>/prompts/create-spec.prompt.md` |
| "create IMP", "improve", "refactor" | `<system>/prompts/create-spec.prompt.md` |
| "visualize", "architecture" | `<system>/prompts/visualize-spec.prompt.md` |
| "bug", "triage", "investigate issue" | `<system>/prompts/bug-triage.prompt.md` |
| "plan", "break into tasks" | `<system>/prompts/plan-spec.prompt.md` |

## Multi-agent file layout

This project has one canonical source — `_canonical.md` — and three
rendered files, one per agent, each containing identical full content:

- **GitHub Copilot** reads `.github/copilot-instructions.md`
- **Claude Code** reads `CLAUDE.md`
- **OpenAI Codex CLI** reads `AGENTS.md`

Edit `_canonical.md`; run `make sync-agents` to regenerate the three
rendered files. `make sync-agents-check` fails the build on drift.

Framework overview, skill catalog, two-scope resolution, multi-agent layout: `<system>/docs/ai-agent-framework.md`. Project-bootstrap authoring: `<system>/docs/project-bootstrap-guide.md`.
