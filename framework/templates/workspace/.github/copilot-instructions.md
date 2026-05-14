# <workspace-name> — workspace root

*Last updated: YYYY-MM-DD*

## Projects
| Project | Path | Purpose |
|---|---|---|
| <project-name> | `<path/to/project/>` | <one-line purpose> |

## Project routing
When a task targets a specific project, `cd` into it and read its `.github/copilot-instructions.md` first — that file carries the per-project read order and build/test commands.

## Shared safety
- External systems: <list shared APIs / databases / queues>; never commit `.env` or keys; cross-repo schema/output changes require a single coordinating spec.

## Cross-repository coordination
- Inter-project contracts (schema changes, output formats); cross-repo changes must list every repo in the spec's `affected-repos` front-matter.

Workspace-bootstrap authoring: `<system>/docs/workspace-bootstrap-guide.md`. Framework overview, two-scope model, skills catalog: `<system>/docs/ai-agent-framework.md`.
