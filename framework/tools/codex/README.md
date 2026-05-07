# Tool: OpenAI Codex CLI

## Instruction-file discovery path

**Assumed path:** `~/.codex/AGENTS.md`

**Verification status:** PARTIALLY VERIFIED — Codex CLI v0.128.0 is installed at
`/opt/homebrew/bin/codex`. The `~/.codex/` directory exists and uses `~/.codex/config.toml`
for runtime configuration. Neither `codex --help` nor `codex exec --help` explicitly documents
a global `AGENTS.md` instruction-file path; the tool reads per-project `AGENTS.md` files from
the working directory following the OpenAI agents convention.

**Verification method:**
```
codex --help | grep -i 'agents\|instruct\|global'
codex exec --help | grep -i 'agents\|instruct\|global'
```
Both returned no matches referencing a global instruction file path.

**Current best evidence:** The `AGENTS.md` convention for OpenAI tooling specifies per-project
`AGENTS.md` at the repository root. Global user-level agent instructions via `~/.codex/AGENTS.md`
follow the same convention as Claude Code's `~/.claude/CLAUDE.md`. If Codex does not read
`~/.codex/AGENTS.md` automatically, an alternative is to set `instructions` in `~/.codex/config.toml`
or pass `--instructions` at runtime. Validate before first use.

**Target in FR-9 tool→target map:** `~/.codex/AGENTS.md` (assumed; validate against Codex CLI docs).
If the actual path differs, update only the FR-9 `tool→target map` row in `scripts/ai-switch.sh`.

## Codex-specific constraints

- `@`-imports are NOT resolved by Codex (literal text). Rendered `AGENTS.md` must be fully
  self-contained with no `@`-imports.
- `~/.codex/config.toml` is NOT touched by `ai-switch.sh` (out of scope per FR-9 / OS-2).
- Codex does not consume system agents (`~/.codex/agents/` symlinks are not created per FR-9
  step 4 deliberate omission).

## Rendered output

`ai-switch.sh` writes `~/.codex/AGENTS.md` by rendering `AGENTS.md.template` via allowlisted
`envsubst`, appending the active profile's `AGENTS.md` body fragment, then appending
`preferences.md`. Because Codex does not resolve `@`-imports, the profile `AGENTS.md` body
must already be a flat self-contained fragment.

## Skills overlay

`ai-switch.sh` creates per-entry symlinks under `~/.codex/skills/` (skills only; no agents).
Reference symlinks also created:
- `~/.codex/spec-workflows` → `$AI_DOTFILES/framework/spec-workflows`
- `~/.codex/prompts` → `$AI_DOTFILES/framework/prompts`
- `~/.codex/templates` → `$AI_DOTFILES/framework/templates`
- `~/.codex/boundaries.md` → `$AI_DOTFILES/framework/boundaries.md`
