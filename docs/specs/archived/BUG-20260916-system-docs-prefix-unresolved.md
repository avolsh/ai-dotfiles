---
id: BUG-20260916-system-docs-prefix-unresolved
type: BUG
date: 2026-09-16
status: done
closed: 2026-09-16
owner: alexvolsh
severity: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/agent-protocol.md
affected-code:
  - scripts/lib/profile-links.sh
  - scripts/ai-doctor.sh
  - scripts/test/profile-links.test.sh
  - scripts/test/ai-doctor.test.sh
skills:
  - writing-specs
model-suggestion: default
baseline-impact: none — profile wiring only; no docs/domain baseline
siblings:
  - IMP-20260916-resume-bottom-line-gaps
  - IMP-20260914-spec-next-instructions
---

# BUG-20260916-system-docs-prefix-unresolved

*Last updated: 2026-09-16*

## Summary

- **Goal:** Make `<system>/docs/…` resolve, so the ten framework references to `<system>/docs/agent-protocol.md` work.
- **Scope:** Profile wiring links `docs` into each tool home; `ai-doctor` checks it; the Path prefixes table lists it.
- **Out of scope:** Rewriting the references themselves.

## Bug Description

`<system>/` is the tool home (`profiles/<profile>/<tool>/`). `profile-links.sh` links `spec-workflows prompts
templates skills agents upstream` and `boundaries.md` from `framework/`, but `agent-protocol.md` lives at the repo's
`docs/`, which is never linked. Ten files name `<system>/docs/agent-protocol.md` — the system `_canonical.md` and its
three renders, the four spec templates, `spec-types.md`, `spec-templates-guide.md`. No `domain-refs:`: framework
tooling, no feature baseline.

## Steps to Reproduce

1. `ls $AI_DOTFILES/profiles/personal/claude/docs/agent-protocol.md`

## Expected Behavior

The path resolves to `$AI_DOTFILES/docs/agent-protocol.md`.

## Actual Behavior

```
ls: …/profiles/personal/claude/docs/agent-protocol.md: No such file or directory
```

A cold agent following the resume prompt first looked in `framework/docs/` (recorded in
`IMP-20260914-resume-spec-prompt` worked examples, § AC-1 cold re-run).

## Environment

- `ai-dotfiles` working tree, profile `personal`, 2026-09-16.

## Root Cause

`AI_LINKS_REFS` enumerates only `framework/` subdirectories; the operating-protocol docs sit outside `framework/`, and no
ref points at `$AI_DOTFILES/docs`. `ai-doctor.sh` checks the same list, so it never reported the gap.

## Design

Skipped — isolated bug fix.

## Fix Criteria

### AC-1: `docs` is wired and checked (regression test required)

Given a fixture dotfiles tree with `docs/agent-protocol.md`
When `ai_links_wire_profile` runs, then `ai-doctor` runs over the result
Then every tool home has a `docs` symlink resolving `docs/agent-protocol.md`, and `ai-doctor` fails when that link is
missing
Evidence: `scripts/test/profile-links.test.sh`, `scripts/test/ai-doctor.test.sh` red before, green after; real profile
path resolves after `ai personal` re-wiring

## Out of Scope

- OS-1: Moving `agent-protocol.md` under `framework/`.

## Split Decision

**Kept as one — E4.** One missing ref, its check and its tests.

## Tasks

> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Reproduce & write failing test: fixture expects a `docs` link per tool home and ai-doctor to flag its absence (AC-1). | `scripts/test/profile-links.test.sh`, `scripts/test/ai-doctor.test.sh` | `scripts/lib/profile-links.sh`, `scripts/ai-doctor.sh` | — | writing-specs | default | ☑ done |
| T2 | Link `$AI_DOTFILES/docs` as `<tool>/docs`, add it to ai-doctor's check, list it in the Path prefixes table; re-wire the real profile (AC-1). | `scripts/lib/profile-links.sh`, `scripts/ai-doctor.sh`, `docs/agent-protocol.md` | — | T1 | writing-specs | default | ☑ done |

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Owner approved requirements, plan and execution in
one message on 2026-09-16 ("just do it all now").

## Docs updates required

- `docs/agent-protocol.md` § Path prefixes — `<system>/docs/` in the resolved list.

## Rollout / migration notes

- Existing profiles gain the link on the next `ai <profile>` / `ai-profile-init.sh` run.

## Closure Evidence

| AC | Evidence |
|---|---|
| AC-1 | T1: `profile-links.test.sh` red (`missing docs link: claude/copilot/codex`), `ai-doctor.test.sh` red (`missing docs link fails (expected rc=1, got rc=0)`); T2: both green. Real profiles: `docs` link placed via `_ai_links_place` in `personal` and `work` tool homes; `ls profiles/personal/claude/docs/agent-protocol.md` resolves; `ai-doctor.sh personal` → `OK ✓`. `ai-doctor.sh work` fails 18 checks, none about `docs` — the `work` profile was never initialised (pre-existing) |
| Suites | `make check` exit 0 |


- **Divergences:** real profiles were patched with the single `docs` link rather than a full `ai <profile>` re-wire, to avoid re-rendering hooks into the live settings; the next `ai`/`ai-profile-init` run places the same link.
- **Accepted duplication:** none.

### Review

Not run — `severity: low`; closed review-after, owner approved execution in chat on 2026-09-16.
