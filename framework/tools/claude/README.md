# Tool: Claude Code

## Instruction-file discovery path

**Verified path:** `~/.claude/CLAUDE.md`

**Verification source:** Claude Code CLI `claude --help` output (v2.1.132); the `--bare` flag
description explicitly lists "CLAUDE.md auto-discovery" as a feature that flag disables, confirming
the tool's built-in global-instruction lookup. The Anthropic Claude Code documentation (Settings
section) documents `~/.claude/CLAUDE.md` as the user-level global instruction file that Claude Code
reads on every session start, prior to project-local `CLAUDE.md` files.

**Resolution order (Claude Code):**
1. `~/.claude/CLAUDE.md` — system/user-global layer (populated by `ai-switch.sh`)
2. Project-local `CLAUDE.md` (at the working directory root) — project layer
   - Project `CLAUDE.md` may use `@`-imports to pull in sibling files (e.g., `.github/copilot-instructions.md`)

**Target in FR-9 tool→target map:** `~/.claude/CLAUDE.md` ✓ confirmed.

## Rendered output

`ai-switch.sh` writes `~/.claude/CLAUDE.md` by rendering `CLAUDE.md.template` via allowlisted
`envsubst`, appending the active profile's `CLAUDE.md` body fragment, then appending
`preferences.md`. The rendered file is the complete system-scope instruction set for the active
profile.

## Skills and agents overlay

`ai-switch.sh` also creates per-entry symlinks under `~/.claude/skills/` and `~/.claude/agents/`
pointing into `framework/skills/` and `framework/agents/` (plus profile overlays). Claude Code
resolves skills via the `<system>/skills/<name>` pattern using these symlinks.

Reference symlinks also created at the tool home root:
- `~/.claude/spec-workflows` → `$AI_DOTFILES/framework/spec-workflows`
- `~/.claude/prompts` → `$AI_DOTFILES/framework/prompts`
- `~/.claude/templates` → `$AI_DOTFILES/framework/templates`
- `~/.claude/boundaries.md` → `$AI_DOTFILES/framework/boundaries.md`
