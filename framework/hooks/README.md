# framework/hooks/ — canonical hook scripts

*Last updated: 2026-06-10*

Single-source enforcement scripts for the rules in
[`boundaries.md`](../boundaries.md) that all three harnesses (Claude Code,
Copilot CLI, Codex CLI) can invoke unmodified. Per-harness adapter configs —
which map each tool's hook event onto these scripts — are rendered by
`ai-profile-init` from `framework/templates/system/` (T3 of
`IMP-20260610-mechanize-framework-guardrails`).

## Contract

All scripts share one canonical payload shape, matching the common subset of
the three harnesses' hook protocols:

- **stdin** — JSON. The edited file is read from `.tool_input.file_path`,
  falling back to `.tool_input.path`, then `.file_path`; the working
  directory from `.cwd` when present.
- **exit codes** — `0` allow / no-op; `2` deny with the reason on stderr
  (PreToolUse); `1` findings on stderr (commit-time scan). Adapters translate
  the exit code into the tool-specific allow/deny response where needed.

A malformed or empty payload always allows — guards fail open on protocol
errors and rely on the git pre-commit backstop (FR-2) as the second line.

## Scripts

| Script | Event | Enforces |
|---|---|---|
| `spec-status-guard.sh` | PreToolUse (Edit/Write) | No code edits while the governing spec (matched via `affected-code`) is at `specify`/`plan` — [`spec-lifecycle.md § Status transitions`](../spec-workflows/spec-lifecycle.md) |
| `secrets-scan.sh` | PreToolUse (`git commit`) and git pre-commit | No secrets or `.env` / `.env.*` / `.dev.vars` in commits — [`boundaries.md § Never do #1`](../boundaries.md) |
| `stamp-refresh.sh` | PostToolUse (Edit/Write on `*.md`) | `*Last updated:*` stamp refreshed automatically — [`boundaries.md § Always do #10`](../boundaries.md#last-updated-stamp) |

`spec-status-guard.sh` never blocks Markdown or `docs/` paths (specs and docs
must stay editable during Specify/Plan); `stamp-refresh.sh` skips `_legacy/`,
`upstream/`, and `docs/specs/archived/` trees and always exits 0.

## Tests

`framework/scripts/test/hooks.test.sh` — fixture-based self-tests for all
three scripts; run directly. Wiring into `make check` lands with the
Makefile changes of T4 (same spec).
