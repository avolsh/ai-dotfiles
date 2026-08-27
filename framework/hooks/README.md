# framework/hooks/ — canonical hook scripts

*Last updated: 2026-08-27*

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
| `spec-status-guard.sh` | PreToolUse (Edit/Write) | No code edits while the governing spec (matched via `affected-code`) is at `specify`/`plan`, subject to the allow conditions below — [`spec-lifecycle.md § Status transitions`](../spec-workflows/spec-lifecycle.md) |
| `secrets-scan.sh` | PreToolUse (`git commit`) and git pre-commit | No secrets or `.env` / `.env.*` / `.dev.vars` in commits — [`boundaries.md § Never do #1`](../boundaries.md) |
| `stamp-refresh.sh` | PostToolUse (Edit/Write on `*.md`) | `*Last updated:*` stamp refreshed automatically — [`boundaries.md § Always do #10`](../boundaries.md#last-updated-stamp) |

`spec-status-guard.sh` never blocks Markdown or `docs/` paths (specs and docs
must stay editable during Specify/Plan); `stamp-refresh.sh` skips `_legacy/`,
`upstream/`, and `docs/specs/archived/` trees and always exits 0.

### `spec-status-guard.sh` allow conditions

The guard evaluates **every** active spec before deciding — it does not stop at
the first `affected-code` match. A path leased by one or more specs at
`specify`/`plan` is still allowed when either condition holds:

1. **A governing spec is past its gate** — an active spec at `in-progress` lists
   the same path in `affected-code`. The edit then has a spec whose plan the
   human approved, which is what the rule protects.
2. **The blocker is waiting on the edit** — the blocking spec's `depends-on:`
   names an active spec at `in-progress`. Safe by construction: a spec with an
   unmet `depends-on:` cannot advance past `specify`
   ([Rule #10](../spec-workflows/spec-lifecycle.md#depends-on-blocks-plan)), so
   it cannot hold a lease against the work it declared it cannot start without.

Otherwise the guard denies, naming the blocker with the earliest `date:` and
restating both conditions on stderr. A genuine sequencing conflict — several
`specify`-stage specs that each really will rewrite the file, with no dependency
between them — still denies; that is a decision for the human, not the hook.

## Tests

`framework/scripts/test/hooks.test.sh` — fixture-based self-tests for all
hook scripts; wired into `make tests` (and `make check`).

**Planting secret-shaped fixtures:** assemble the value at runtime so the
test's own source never contains a contiguous match for the very scanner
it tests — e.g. `printf 'key = "%s%s"' "AKIA" "IOSFODNN7EXAMPLE"`. The
fixture file written during the test still holds a contiguous secret
(assertions unchanged), while the committed source stays clean for the
pre-commit backstop. Never add scanner allowlists for test files.
