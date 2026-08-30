# <project-name>

*Last updated: YYYY-MM-DD*

**Tech Stack:** <language / database / test framework>
**Codebase Layout:** <top-level dirs>

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

## Verification by Change Type

<!-- Fill the table with this project's own commands. Keep the two rules above it: they hold
     everywhere, and a project that rewrites them is usually about to narrow one by accident. -->

Run the broadest verification command by default. Narrow it only when you can show the change cannot
reach the part you are leaving out — "it looks unrelated" is not that showing.

A command's tail is not its result: read the exit status, and check that any summary you quote names
every part of the run (`<system>/boundaries.md` § Always do #19).

| What changed | Minimum verification |
|---|---|
| <exported signature, shared type, or anything another build compiles against> | <command> + <command> |
| <change confined to one testable unit> | <command> |
| Docs only | No build required |

## Build and Run

`<verification-sequence command>` runs the steps below in order: single-purpose commands, each with
its own exit status, the first non-zero one stopping the run. **No step rewrites the source it
checks** — formatting and code generation get their own developer command and never appear here
(`<system>/boundaries.md` § Always do #21).

| # | Step | What fails it |
|---|---|---|
| 1 | `<step>` | <the one condition that fails it> |
| 2 | `<step>` | <the one condition that fails it> |

- `<target>` — <what it runs, and when to reach for it instead of the whole sequence>

## Multi-agent file layout

This project has one canonical source — `_canonical.md` — and three
rendered files, one per agent, each containing identical full content:

- **GitHub Copilot** reads `.github/copilot-instructions.md`
- **Claude Code** reads `CLAUDE.md`
- **OpenAI Codex CLI** reads `AGENTS.md`

Edit `_canonical.md`; run `make sync-agents` to regenerate the three
rendered files. `make sync-agents-check` fails the build on drift.

Framework overview, skill catalog, two-scope resolution, multi-agent layout: `<system>/docs/ai-agent-framework.md`. Project-bootstrap authoring: `<system>/docs/project-bootstrap-guide.md`.
