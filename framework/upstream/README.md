# upstream/ — external skill & agent catalogs

*Last updated: 2026-06-10*

Read-only submodules used as a **quarry**: cherry-pick entries, copy them
into `framework/skills/` (or a project's `.github/copilot/skills/`), and
adapt to the framework's format (two-scope model, `<system>/` prefixes).
Never symlink upstream content directly into the active catalog — an
upstream update must not silently change agent behaviour
(see `framework/boundaries.md § Ask first`).

## Submodules

| Path | Upstream | Purpose |
|---|---|---|
| `mcp-server-guide/` | `figma/mcp-server-guide` | Figma MCP server reference |
| `anthropic-skills/` | `anthropics/skills` | Official Anthropic skill catalog; canonical SKILL.md format reference |
| `superpowers/` | `obra/superpowers` | Methodology skills (TDD, debugging, planning) — cherry-pick only; its workflow does not replace the spec lifecycle |
| `volt-skills/` | `VoltAgent/awesome-agent-skills` | 1000+ cross-harness skills (Claude Code, Codex, Cursor) |
| `wshobson-agents/` | `wshobson/agents` | Sub-agent definitions and multi-harness plugins; convert to skills unless a mechanical sub-agent need exists (`framework/agents/README.md`) |

## Updating

Submodules are pinned to a SHA. Update deliberately, review the diff —
catalog updates are framework-file changes:

```sh
git submodule update --remote framework/upstream/<name>
git diff --submodule framework/upstream/<name>
```

References inside `framework/` files use `<system>/upstream/...`, which
resolves here via the symlinks created by `ai-switch.sh` step 4a.
