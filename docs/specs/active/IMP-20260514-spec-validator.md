---
id: IMP-20260514-spec-validator
type: IMP
date: 2026-05-14
status: in-progress
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/ai-agent-framework.md
  - docs/spec-workflow-guide.md
affected-code:
  - scripts/validate-specs.py
  - Makefile
  - .github/workflows/validate.yml
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
siblings:
  - IMP-20260514-dedup-rule-statements
  - IMP-20260514-framework-subagents
  - IMP-20260514-trivial-lane
  - IMP-20260514-research-lane
---

# IMP-20260514-spec-validator

*Last updated: 2026-05-14*

## Summary

- **Goal:** Add a deterministic spec-corpus validator (front-matter, deps graph, naming, freshness, link integrity, English-only) wired into `make sync-agents-check` and a new ai-dotfiles CI workflow.
- **Scope:** New `scripts/validate-specs.py`, Makefile target `validate-specs`, GitHub Actions workflow `.github/workflows/validate.yml`.
- **Out of scope:** REQ-ID enforcement in source code (only checks spec front-matter and AC citations cross-reference baseline files); changing any existing spec; runtime telemetry; pre-commit hook installation in project repos; deleting `env/ai-dotfiles/_legacy/` (owner keeps it for final verification; will remove out-of-band).

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 80k-150k |
| Human attention | 3 gates (specify + plan + closure); ~10 min/gate |
| Re-Specify tripwire | Validator surface area grows past 8 distinct check classes; OR backtest corpus produces zero historical findings (signal: checks are wrong, not the corpus) |

## Current State

Spec discipline is enforced by agent goodwill alone. Concrete evidence in the existing corpus (`env/ai-dotfiles/docs/specs/archived/`, ~9 IMPs from 2026-05-13):

- Front-matter values are author-discretion; no schema enforcement.
- `siblings:` and `depends-on:` are filled by hand; no cycle detection, no dangling-ID detection.
- `*Last updated:*` stamps drift silently — no freshness check.
- `<TYPE>-YYYYMMDD-<kebab>.md` naming is convention, not enforced.
- Cross-references inside specs (markdown links to other framework files) can rot when files move; no link-integrity check.
- The `boundaries.md` rule "Write all file output in English" is unverified.

`cites-reqs:` omitted — framework-tooling work, no project requirements baselines touched.

## Proposed Improvement

Introduce `scripts/validate-specs.py` running these check classes against `docs/specs/{active,archived}/`:

1. **Front-matter schema** — every required field present and well-typed per `spec-lifecycle.md § Front-matter schema`.
2. **Filename ↔ id parity** — basename without `.md` equals the `id` field.
3. **Naming pattern** — matches `^(CR|BUG|IMP|RES)-\d{8}-[a-z0-9-]+\.md$`.
4. **Dependency graph** — every `siblings:` / `depends-on:` ID resolves to an existing file; no cycles; no `plan`/`in-progress` spec with unmet `depends-on:` (per `spec-lifecycle.md § Rules #10`).
5. **Freshness** — `*Last updated:*` ≤ 60 days for any spec in `active/`.
6. **Link integrity** — every relative markdown link inside a spec resolves at HEAD.
7. **English-only** — file body matches a permissive ASCII-extended regex; flags Cyrillic, CJK, etc. (boundaries.md "Always do #8").
8. **Status invariants** — no `specify` spec has a non-empty `## Tasks` table; no `done` spec lives in `active/`.

Wire `make validate-specs` (runs Python). Hook into existing `make sync-agents-check` (chains validators) and add a new `.github/workflows/validate.yml` running on push/PR.

**Measurable benefit:** Backtest validator against `docs/specs/archived/` — must surface ≥5 concrete issues. Run cost ≤2 s on the current corpus.

## Requirements

- FR-1: `scripts/validate-specs.py` MUST implement all 8 check classes listed in § Proposed Improvement.
- FR-2: The validator MUST exit non-zero when any check fails and zero when all pass; MUST emit a structured report (one finding per line: `path:lineno:check:message`).
- FR-3: `make validate-specs` and `make sync-agents-check` MUST invoke the validator; `make sync-agents-check` MUST fail when the validator fails.
- FR-4: A GitHub Actions workflow at `.github/workflows/validate.yml` MUST run the validator on push to any branch and on pull requests; MUST block merge when red.
- FR-5: Running the validator against `docs/specs/archived/` at HEAD before any fixes MUST surface ≥5 distinct findings (backtest baseline captured in Closure Evidence).
- FR-6: The validator MUST complete in ≤2 s on the current corpus (`time make validate-specs`).
- FR-7: The validator MUST have zero third-party dependencies — stdlib only (`pathlib`, `re`, `yaml` via `tomllib`-style parser implemented inline, or PyYAML if already in toolchain — to be decided in Plan).

## Acceptance Criteria

### AC-1: All 8 check classes implemented (FR-1)

Given the validator source at HEAD
When `grep -c "^def check_" scripts/validate-specs.py` runs
Then it returns ≥8
And each check has at least one passing and one failing fixture in `tests/` (if Plan stage adds fixtures) OR a documented hand-test in Closure Evidence

### AC-2: Exit codes and report format (FR-2)

Given a corpus with a deliberately-broken spec (injected: malformed front-matter)
When `make validate-specs` runs
Then exit code is non-zero
And stdout contains a line matching `^docs/specs/.+\.md:\d+:[a-z_]+:.+$`

### AC-3: Hook integration (FR-3)

Given a corpus with a deliberately-broken spec
When `make sync-agents-check` runs
Then it exits non-zero with the validator finding in its output

### AC-4: CI runs the check (FR-4)

Given a PR with a deliberately-broken spec pushed to a branch
When CI runs
Then the `validate-specs` job is red
And the PR cannot be merged until fixed

### AC-5: Backtest yields ≥5 historical findings (FR-5)

Given the validator at HEAD
When run against `docs/specs/archived/` *before any fix-up of historical specs*
Then ≥5 distinct findings are emitted
And the findings are recorded verbatim in Closure Evidence
And the measurable benefit is verified

### AC-6: Performance budget (FR-6)

Given the current corpus
When `time make validate-specs` runs
Then real wall time is ≤2 s

### AC-7: Zero third-party deps (FR-7)

Given the validator at HEAD
When `grep -E "^(import|from) " scripts/validate-specs.py` runs
Then every imported module is in Python stdlib (or PyYAML if explicitly approved in Plan)

## Architecture

Skipped — adds a tooling script + Makefile target + CI workflow. No bounded-context, schema, or pipeline impact on the framework itself; new code is leaf-level under `scripts/`.

## Out of Scope

- OS-1: Extending REQ-ID enforcement to source-code comments (validator only checks spec front-matter and AC text).
- OS-2: Auto-fixing findings (validator is read-only).
- OS-3: Telemetry / metrics emission (separate concern, deliberately deferred).
- OS-4: Pre-commit hook installation in tobevisit-content / tobevisit-web / tobevisit-docs — projects opt in via their own `make sync-agents-check`.
- OS-5: Rewriting historical specs surfaced by the backtest; findings are recorded but specs in `archived/` are immutable per convention.
- OS-6: Deleting `env/ai-dotfiles/_legacy/` — owner keeps the directory for final verification of the slim-* work and will remove it out-of-band.

## Split Decision

Kept as one spec. Per `splitting-rules.md § 2`: no T1–T6 trigger fires — all 8 check classes share a single executable (`validate-specs.py`), a single AC surface (exit code + report format), and a single closure metric (backtest ≥5 findings).

## Tasks

> **Before starting Task F1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| F1 | Bootstrap: scaffold `scripts/validate-specs.py` (stdlib only — confirm Python ≥3.11 for `tomllib` or use inline minimal YAML parser; document decision in script docstring); add `make validate-specs` target invoking the script; implement one trivial check class (filename pattern, FR-1 check #3) as the harness shape; print structured findings per FR-2 format. Verify with a hand-injected fixture. | `scripts/validate-specs.py`; `Makefile` | `framework/spec-workflows/spec-lifecycle.md` *(front-matter schema)*; `Makefile` *(pre-edit)* | — | writing-specs | default | ☑ done |
| F2 | Front-matter schema check (FR-1 check #1) + dependency graph check (FR-1 check #4): parse front-matter; validate every required field per `spec-lifecycle.md § Front-matter schema`; build sibling/depends-on graph; detect cycles; flag dangling IDs; enforce rule #10 (no `plan`/`in-progress` with unmet `depends-on:`). | `scripts/validate-specs.py` | `framework/spec-workflows/spec-lifecycle.md`; all 5 specs under `docs/specs/active/` *(test corpus)* | F1 | writing-specs | default | ☑ done |
| F3 | Mechanical-shape checks (FR-1 checks #2, #3, #8): filename ↔ `id` field parity; naming pattern regex; status invariants (no `## Tasks` table at `specify`; no `done` in `active/`; no `specify` in `archived/`). | `scripts/validate-specs.py` | `docs/specs/{active,archived}/*.md` *(corpus)* | F1 | writing-specs | fast | ☑ done |
| F4 | Content checks (FR-1 checks #5, #6, #7): `*Last updated:*` ≤60 days for active/; resolve every relative markdown link inside spec body; ASCII-extended English-only body check (flag Cyrillic / CJK / etc., with allowlist for proper nouns documented in script). | `scripts/validate-specs.py` | `docs/specs/{active,archived}/*.md` | F1 | writing-specs | fast | ☑ done |
| F5 | Backtest + integration + perf budget (FR-3, FR-5, FR-6): run validator against `docs/specs/archived/` at HEAD before any fix-up; capture ≥5 findings verbatim into a `tests/backtest-baseline.md` artifact; hook `make validate-specs` into `make sync-agents-check`; verify `time make validate-specs` ≤2 s. | `scripts/validate-specs.py`; `Makefile` *(sync-agents-check chain)*; `tests/backtest-baseline.md` *(new)* | `docs/specs/archived/*.md` | F2; F3; F4 | writing-specs; writing-docs | deep | ☐ pending |
| F6 | CI workflow + docs (FR-4): `.github/workflows/validate.yml` running on push + PR; block merge when red; add `make validate-specs` row to `docs/ai-agent-framework.md § Sync workflow`; note CI validation in `docs/spec-workflow-guide.md`. | `.github/workflows/validate.yml` *(new)*; `docs/ai-agent-framework.md`; `docs/spec-workflow-guide.md` | existing `.github/scripts/sync-agents.sh` *(precedent for repo conventions)* | F5 | writing-docs | default | ☐ pending |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/ai-agent-framework.md` — add a row to the "Sync workflow" table for `make validate-specs`.
- `docs/spec-workflow-guide.md` — note that CI validates spec front-matter on PR.

## Rollout / migration notes

- Land validator + CI before merging the other three sibling specs so dedup / sub-agents / trivial-lane work is protected by the check.
- Backtest output goes into Closure Evidence verbatim; do not fix-up surfaced specs in this IMP (they live in `archived/`).
