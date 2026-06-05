# Project Bootstrap Guide

*Last updated: 2026-05-13*

Authoring guidance for the per-project instruction file
(`.github/copilot-instructions.md`) produced by `ai-project`. Conceptual
background — two-scope model, skill catalog, agent matrix — lives in
[`ai-agent-framework.md`](ai-agent-framework.md). This guide covers only
what the bootstrap author fills in or omits.

---

## Skill & prompt resolution (authoring rule)

All three tools (Claude Code, Copilot, Codex) follow the same two-scope
lookup order when resolving a skill or prompt name:

1. **Project scope first** — `.github/copilot/skills/<name>/SKILL.md` and
   `.github/copilot/prompts/<name>.prompt.md`
2. **System scope (fallback)** — `<system>/skills/<name>/SKILL.md` and
   `<system>/prompts/<name>.prompt.md`

Project scope wins on name collision. Since `CLAUDE.md` `@`-imports
`.github/copilot-instructions.md` and `AGENTS.md` is a generated copy of
it, the rule applies identically to all three tools — do not restate the
rule per-tool in the project template.

## Available skills (what to inline)

System-scope skills are populated under each tool's home by
`ai-switch.sh` (rendered from `ai-dotfiles`) and listed canonically in
[`ai-agent-framework.md`](ai-agent-framework.md). Do **not** copy the
system catalog into the project template — point at the framework doc
instead.

Inline in the project file only:

- Project-scope skills under `.github/copilot/skills/<name>/SKILL.md`.
- System-scope skills the project deliberately **overrides** (same name,
  project-specific behavior) — note the override and link to the
  project copy.

If the project has no project-scope skills at bootstrap time, the
"Available skills" section is omitted; the framework catalog covers
the active set.

## Note for non-Copilot agents (#skill: trigger)

When an agent reads a `.prompt.md` file and sees a line of the form
`#skill:<name>`, it MUST load the corresponding skill file using the
two-scope lookup order above: project scope
(`.github/copilot/skills/<name>/SKILL.md`) wins; otherwise fall back to
`<system>/skills/<name>/SKILL.md`. This convention is shared across
Copilot, Claude Code, and Codex.

## What stays in the project template

The slimmed `.github/copilot-instructions.md` retains only the
load-bearing project-scope content:

- `## Boundaries` — project-scope rules (the project-scope counterpart
  to system `<system>/boundaries.md`).
- `## Workflows` — the user-says-→-prompt trigger map. Load-bearing
  routing layer for the project agent.
- One-line placeholders for `Tech Stack`, `Codebase Layout`, and
  `Build and Run`.

Everything else (resolution rule, system skill catalog, multi-agent
notes, framework concepts) is reachable via
[`ai-agent-framework.md`](ai-agent-framework.md) and this guide.
