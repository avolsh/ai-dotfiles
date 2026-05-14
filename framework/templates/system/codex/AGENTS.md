# System Agent Instructions

*Rendered by `ai-profile-init.sh` — do not edit. Canonical source: `$AI_DOTFILES/framework/templates/system/codex/AGENTS.md`.*

**Active profile:** $AI_PROFILE

@boundaries.md

## Workflows

| User says | Load prompt |
|---|---|
| "create CR", "new feature", "specify" | `<system>/prompts/create-spec.prompt.md` |
| "create IMP", "improve", "refactor" | `<system>/prompts/create-spec.prompt.md` |
| "visualize", "architecture" | `<system>/prompts/visualize-spec.prompt.md` |
| "bug", "triage", "investigate issue" | `<system>/prompts/bug-triage.prompt.md` |
| "plan", "break into tasks" | `<system>/prompts/plan-spec.prompt.md` |

Framework overview — skills catalog, two-scope model, multi-agent notes, spec-type table: `docs/ai-agent-framework.md`.
Spec lifecycle and human-gate rules: `docs/spec-workflow-guide.md`.
