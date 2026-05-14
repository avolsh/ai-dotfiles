---
description: "Specify stage for a BUG — reproduce and document the defect"
---
#skill:writing-specs
#skill:agent-protocol

Specify stage for a BUG — reproduction-first questions; mandatory "reproduce with failing test" first task. Lifecycle: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). New features → [`create-spec.prompt.md`](create-spec.prompt.md).

## Preconditions
- User reports incorrect behaviour (defect, regression, wrong output).

## Steps
1. **Load context** — project `.github/copilot-instructions.md`, [`spec-types.md`](../spec-workflows/spec-types.md), [`bug-questions.md`](../spec-workflows/questions/bug-questions.md), project `module-map.md`, and any `docs/requirements/<feature>.md` baselines per [`docs/baseline-citations.md`](../../docs/baseline-citations.md).
2. **Ask ≤10 questions** ([`docs/spec-asking-questions.md`](../../docs/spec-asking-questions.md)). Start with reproduction (Q1). Mandatory each round: Q2 (Multi-defect) — independent defects MUST become separate BUG specs.
3. **Create BUG spec(s)** — one per independent defect (cross-linked via `siblings:` per [`splitting-rules.md § 5`](../skills/writing-specs/references/splitting-rules.md)). Copy [`BUG-TEMPLATE.md`](../spec-workflows/templates/BUG-TEMPLATE.md), file `BUG-YYYYMMDD-<kebab>.md`. Fill front-matter (`status: specify`, `severity`, `siblings:` if split), `## Summary`, `## Bug Description`, `## Steps to Reproduce`, `## Expected Behavior`, `## Actual Behavior`, `## Environment`, `## Root Cause` (or `Under investigation`), `## Fix Criteria` (AC-1 fixed, AC-2 no regressions), `## Out of Scope`. Set `## Architecture` = `Skipped — isolated bug fix`. Leave `## Tasks` empty.
4. **Fill `## Split Decision`** — *Single defect.* or *Split into: `<sibling-BUG-ids>`. This spec owns the `<defect-name>` defect.*
5. **Gate** — post per-spec summary (ID + path, severity + blast radius, suspected root cause, similar code paths, `cites-reqs:` or net-new justification). Wait for explicit approval; hand off to [`plan-spec.prompt.md`](plan-spec.prompt.md).

## Hard rules
- Task 1 of any BUG plan = "Reproduce & write failing test"; fix lands Task 2+. `status` stays `specify` until plan approval. Never bundle independent defects (Q2 mandatory each round). Never request the gate without `## Split Decision` filled in every spec.
