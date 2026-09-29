# framework/hooks/ — canonical hook scripts

*Last updated: 2026-09-29*

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
| `bash-write-guard.sh` | PreToolUse (Bash) | The same lease decision for a write made by a shell command, and no state-changing git verb — [`boundaries.md § Never do #10`](../boundaries.md#git-is-the-humans). Fails open, see below |
| `secrets-scan.sh` | PreToolUse (`git commit`) and git pre-commit | No secrets or `.env` / `.env.*` / `.dev.vars` in commits — [`boundaries.md § Never do #1`](../boundaries.md) |
| `stamp-refresh.sh` | PostToolUse (Edit/Write on `*.md`) | `*Last updated:*` stamp refreshed automatically — [`boundaries.md § Always do #10`](../boundaries.md#last-updated-stamp) |

`spec-status-guard.sh` never blocks Markdown or `docs/` paths (specs and docs
must stay editable during Specify/Plan); `stamp-refresh.sh` skips `_legacy/`,
`upstream/`, and `docs/specs/archived/` trees and always exits 0.

### `spec-status-guard.sh` spec trees

The guard walks up from the edited file and collects **every** ancestor owning
`docs/specs/active`, nearest first. A single-project repository yields exactly
one. A repository checked out inside a multi-project workspace yields two: its
own tree, and the workspace tree that governs cross-repo work — the shape
`<workspace>/` describes in
[`agent-protocol.md § Path prefixes`](../../docs/agent-protocol.md).

Each spec is matched against the path **as its own tree spells it**, so a
workspace spec leasing `src/<host>/<org>/<repo>/_cms` and a project spec leasing
`_cms` both match the same edit. Without this, a cross-repo spec governing the
change is invisible to the guard and every allow condition below fails on a path
its own repository's `specify`-stage specs lease
(`IMP-20260929-spec-guard-workspace-scope`).

The Markdown and `docs/` exemption is decided against the nearest tree, as
before.

### `spec-status-guard.sh` allow conditions

The guard evaluates **every** active spec in **every** collected tree before
deciding — it does not stop at the first `affected-code` match. A path leased by
one or more specs at `specify`/`plan` is still allowed when either condition
holds:

1. **A governing spec is past its gate** — an active spec at `in-progress`, in
   any collected tree, lists the same path in `affected-code`. The edit then has
   a spec whose plan the human approved, which is what the rule protects.
2. **The blocker is waiting on the edit** — the blocking spec's `depends-on:`
   names an active spec at `in-progress`, again from any collected tree. Safe by
   construction: a spec with an unmet `depends-on:` cannot advance past `specify`
   ([Rule #10](../spec-workflows/spec-lifecycle.md#depends-on-blocks-plan)), so
   it cannot hold a lease against the work it declared it cannot start without.

Otherwise the guard denies, naming the blocker with the earliest `date:`, the
tree that holds it, and both conditions on stderr. A genuine sequencing conflict
— several `specify`-stage specs that each really will rewrite the file, with no
dependency between them — still denies; that is a decision for the human, not
the hook.

### `bash-write-guard.sh`

The same decision, at the other door. `spec-status-guard.sh` is matched on the
file tools, so a write made through a shell command (`cp`, `sed -i`, a heredoc)
used to reach no guard at all; twice in one session it reached a leased path
minutes after a `Write` to the same tree had been refused
(`IMP-20260929-guarded-writes-through-bash`). This guard reads the command,
resolves what each write lands on, and asks the **same** decision — both doors
share `lib/spec-lease.sh`, so a path cannot be governed at one and free at the
other. It also refuses a state-changing git verb wherever it appears, including
inside a compound command, while leaving `status`, `log`, `diff`, `show` and
`branch --show-current` unrestricted.

**It fails open.** Anything it cannot read confidently — a path built from a
variable, a glob, a write inside an invoked script or interpreter — is allowed,
and it says nothing. This is deliberate: the guard is a backstop for convenience
mistakes, not a sandbox, and an agent that means to evade it can always write a
script and run it. A guard that denied what it did not understand would be
switched off within a day. The rules in `boundaries.md` still bind wherever it
fails open; this only makes the common case mechanical instead of remembered.

## Tests

`framework/scripts/test/hooks.test.sh` — fixture-based self-tests for all
hook scripts; wired into `make tests` (and `make check`).

**Planting secret-shaped fixtures:** assemble the value at runtime so the
test's own source never contains a contiguous match for the very scanner
it tests — e.g. `printf 'key = "%s%s"' "AKIA" "IOSFODNN7EXAMPLE"`. The
fixture file written during the test still holds a contiguous secret
(assertions unchanged), while the committed source stays clean for the
pre-commit backstop. Never add scanner allowlists for test files.
