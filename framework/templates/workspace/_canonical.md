# <workspace-name> — workspace root

*Last updated: YYYY-MM-DD*

## Projects
| Project | Path | Purpose |
|---|---|---|
| <project-name> | `<path/to/project/>` | <one-line purpose> |

## Project routing
When a task targets a specific project, `cd` into it and read its agent-instructions file first (`CLAUDE.md`, `AGENTS.md`, or `.github/copilot-instructions.md` — pick the one for your agent). That file carries the per-project read order and build/test commands.

## Shared safety
- External systems: <list shared APIs / databases / queues>; never commit `.env` or keys; cross-repo schema/output changes require a single coordinating spec.

## Cross-repository coordination
- Inter-project contracts (schema changes, output formats); cross-repo changes must list every repo in the spec's `affected-repos` front-matter.

## Multi-agent file layout

This workspace has one canonical source — `_canonical.md` — and three
rendered files, one per agent, each containing identical full content:

- **GitHub Copilot** reads `.github/copilot-instructions.md`
- **Claude Code** reads `CLAUDE.md`
- **OpenAI Codex CLI** reads `AGENTS.md`

Edit `_canonical.md`; run `make sync-agents` to regenerate the three
rendered files. `make sync-agents-check` fails the build on drift.

Workspace-bootstrap authoring: `<system>/docs/workspace-bootstrap-guide.md`. Framework overview, two-scope model, skills catalog: `<system>/docs/ai-agent-framework.md`.
