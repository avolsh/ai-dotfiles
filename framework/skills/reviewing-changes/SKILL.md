---
name: "reviewing-changes"
description: "Spec-conformance review checklist for a code change (diff). Use when reviewing a diff/PR against its spec, running the reviewer sub-step before closure, or acting as a cold reviewer in a separate session. Triggers: review, code review, reviewer, check the diff."
---

# Reviewing Changes

*Last updated: 2026-06-05*

The shared review language for the framework. Both the read-only
[`reviewer`](../../agents/reviewer.md) sub-agent (Claude) and a separate
empty-context session (Codex / Copilot) load **this one skill** so a
review means the same thing on every harness.

## When to use

- Running the recommended reviewer sub-step before closing a spec
  ([`spec-lifecycle.md`](../../spec-workflows/spec-lifecycle.md)).
- Reviewing a diff or PR against the spec it claims to implement.
- Acting as a cold reviewer in a fresh session (spec + `git diff` only).

## Inputs

- The **spec** (its Requirements + Acceptance Criteria are the rubric).
- The **change**: read the `git diff` yourself with a read-only tool —
  do not rely on a summary handed to you.

Review the diff *cold*: judge what the code does against what the spec
says, not against the author's narrative.

## The checklist

Judge the change on exactly five dimensions:

1. **Coverage** — every Acceptance Criterion has corresponding
   implementation **and** a test. Flag any AC with no code or no test.
2. **Scope** — the diff implements the spec's FRs and nothing beyond.
   Flag gold-plating, out-of-scope additions, or mixed refactor+feature.
3. **Contract** — public interfaces, schemas, outputs, and cross-layer
   contracts match what the spec specifies. Flag drift.
4. **Bugs** — correctness defects: logic errors, unhandled edge cases,
   broken invariants, regressions.
5. **Minimality** — no unnecessary complexity, duplication, or dead
   code; the change is the smallest that satisfies the spec.

## What to ignore

Formatting, naming taste, import order, and other cosmetics. Those are
the linter's and formatter's job — not the reviewer's. Do not raise them.

## Output contract

Either:

```
PASS
```

or one finding per line, nothing else:

```
<path>:<line> → <FR/AC id> violated: <one-line what + which dimension>
```

Diagnose only — never edit. The main agent is the arbiter: it decides
which findings to apply, applies them, and re-runs the review for **at
most 1–2 cycles**. The reviewer is not a gate and does not replace the
human closure gate.

## References

- [`framework/agents/reviewer.md`](../../agents/reviewer.md) — the read-only sub-agent that runs this checklist.
- [`docs/writing-skills.md`](../../../docs/writing-skills.md) — skill authoring conventions.
