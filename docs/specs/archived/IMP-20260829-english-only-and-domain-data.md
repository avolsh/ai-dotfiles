---
id: IMP-20260829-english-only-and-domain-data
type: IMP
date: 2026-08-29
status: done
owner: alexvolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/agent-protocol.md
affected-code:
  - scripts/validate-specs.py
skills:
  - writing-specs
model-suggestion: default
---

# IMP-20260829-english-only-and-domain-data

*Last updated: 2026-08-30*

## Summary

- **Goal:** Let `validate-specs` run clean on a repository whose subject matter is not English, so it
  can finally join a build instead of being kept out of one.
- **Scope:** Narrow `check_english_only` so it flags prose written in another language and not the
  data, glyphs and identifiers a spec legitimately quotes.
- **Out of scope:** Relaxing the rule that a spec's own **prose** is written in English.

## Current State

`check_english_only` flags any run of characters outside a Latin/punctuation allow-list, one finding
per line. It has no notion of what the run *is*.

In `tobevisit-content` this leaves the validator permanently red on correct content. Of the 21
findings that remain after a full backlog clearing, **20 are `english_only` and none is a defect**
(log, 2026-08-22 and 2026-08-28):

- Six are Ukrainian **data** — `Берестейський` in a geography example, the `Українська` endonym in
  the languages fixture. This is a Ukrainian travel corpus; the words are the subject, not a lapse.
- The rest are UI glyphs a spec quotes from the surface it describes: `⏳`, `📍`, `⬜`, `⤓`, emoji.

The consequence is recorded twice: the check is hard-coded with no allowlist, so the repository kept
`validate-specs` out of `make docs-check` and wrote the reason into three places instead. A check that
cannot be run is a check that guards nothing, and 55 genuine findings were cleared by hand while this
one stayed red.

## Proposed Improvement

Distinguish the two cases the rule already means to treat differently.

A quoted run — inside backticks, a fenced block, a table cell that is evidently a value, or a
front-matter field — is data the spec is reporting and is not prose. A glyph outside any letter
category is not language at all. What remains, an unquoted run of letters from another script in a
sentence, is what the rule was written for and keeps failing.

**Measurable benefit:** 20 false findings → 0, on a corpus with 95 specs. The outcome that matters is
downstream: `validate-specs` becomes eligible for `make docs-check`, which is what its three recorded
exclusions were waiting for.

## Requirements

- FR-1: `check_english_only` MUST NOT flag a run inside inline code, a fenced block, or a front-matter value — those are quoted data, and a spec that must not quote its own corpus cannot describe it.
- FR-2: The check MUST NOT flag characters that belong to no letter category — symbols, emoji, box drawing, dingbats — because a glyph is not a language and the rule is about prose.
- FR-3: The check MUST still flag an unquoted run of non-Latin **letters** in narrative prose, and a test MUST prove it does, so the narrowing does not silently retire the rule.
- FR-4: `BUG-TEMPLATE.md` MUST list every front-matter field `check_front_matter_schema` requires, so a BUG written from the template is not born invalid.
- FR-5: The validator's own suite MUST carry a fixture drawn from the real failures — a Ukrainian place name in backticks, a bare emoji, and a genuine non-English sentence — so the three cases are pinned by example rather than by rule wording.

## Acceptance Criteria

### AC-1: Quoted domain data passes (FR-1)

Given a spec quoting `Берестейський` in backticks and a fenced block holding a Ukrainian fixture
When the check runs
Then neither is reported
Evidence: unit test

### AC-2: Glyphs pass (FR-2)

Given a spec whose prose quotes `⏳`, `📍`, `⬜`, `⤓` and an emoji
When the check runs
Then none is reported
Evidence: unit test

### AC-3: Prose in another language still fails (FR-3)

Given a spec with an unquoted Ukrainian sentence in its Summary
When the check runs
Then it is reported, naming the line and the excerpt
Evidence: unit test — the case that proves the rule survived the narrowing

### AC-4: The real corpus comes back clean (FR-1, FR-2)

Given `tobevisit-content`'s 95 specs
When `make validate-specs` runs against that root
Then the `english_only` count is 0 and the remaining finding count is stated
Evidence: one run, count recorded before and after

### AC-5: A BUG from the template validates (FR-4)

Given a BUG spec created from `BUG-TEMPLATE.md` with fields filled
When `check_front_matter_schema` runs
Then no `schema_missing_field` finding is produced
Evidence: unit test over the template

## Design

Skipped — no UI surface; one predicate narrowed and one template field.

## Out of Scope

- OS-1: Wiring `validate-specs` into any project's `make docs-check`. That is the consuming
  repository's decision and its own change; this spec removes the reason it could not.
- OS-2: The other finding classes. `link_broken` on a link written inside backticks as an example is
  the same shape as this defect and worth a look, but it is one finding and a separate judgement.
- OS-3: Making the allow-list configurable per repository. A rule about prose does not need to vary
  by repo once it stops matching data.

## Split Decision

Not split. FR-1 through FR-3 are one predicate — narrowing it without the counter-example test would
retire the rule rather than fix it, so they close together (**E1**, one read path). FR-4 is two lines
in a template and rides along under **E4**: it is the same root cause, a check and the artefact it
judges disagreeing, and it is the reason every BUG spec starts invalid.

**Plan-stage override (2026-08-30).** **P3** fires: Task 3 (FR-4, the template assertion) has zero
dependencies on the FR-1..FR-3 group. It is recorded as an override, not re-run — the cluster is the
one the Specify gate already named under **E4**, and the human elected that exception there. Table
written at `status: plan`; the signal is surfaced at the Plan gate so it can still be rejected.

## Tasks

> **Before starting Task 1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| 1 | Fixtures first (FR-5). Add the three real-failure cases to the self-test harness: `Берестейський` in backticks plus a fenced Ukrainian block (AC-1); bare `⏳`, `📍`, `⬜`, `⤓` and an emoji (AC-2); an unquoted Ukrainian sentence in a Summary (AC-3). Run them against today's predicate and record that AC-1 and AC-2 fail — the harness must see the defect before it is narrowed away. | `scripts/test/validate-specs.test.sh` | `scripts/validate-specs.py`, `src/github.com/tobeverse/tobevisit-content/docs/specs/archived/` | — | writing-specs | default | ☑ done |
| 2 | Narrow `check_english_only` (FR-1, FR-2, FR-3). Mask inline-code spans, fenced blocks and front-matter values before matching; then match on letter category rather than the complement of an allow-list, so a glyph is never a finding. An unquoted non-Latin letter run in prose is still reported, with line and excerpt. Task 1's three cases go green and the whole suite stays green. | `scripts/validate-specs.py` | `scripts/test/validate-specs.test.sh` | 1 | writing-specs | default | ☑ done |
| 3 | Prove AC-5 instead of assuming it (FR-4). `BUG-TEMPLATE.md` already carries every `_REQUIRED_FIELDS` entry, so the defect FR-4 names is already closed; widen the harness's existing template assertion from `affected-docs` alone to every `schema_missing_field`, and add the field only if the widened assertion fails. | `scripts/test/validate-specs.test.sh`, `framework/spec-workflows/templates/BUG-TEMPLATE.md` | `scripts/validate-specs.py` | — | writing-specs | default | ☑ done |
| 4 | AC-4 on the real corpus. Run the validator against `tobevisit-content` and record the count per class before and after — baseline measured 2026-08-30: 22 findings across 99 specs, 21 `english_only` + 1 `link_broken`. Adjudicate the residual: `CR-20260615-admin-configuration-management.md:97` quotes `так може` in unquoted prose, which FR-3 requires to keep firing. | this spec (Evidence) | `src/github.com/tobeverse/tobevisit-content/docs/specs/` | 2, 3 | writing-specs | default | ☑ done |
| 5 | Docs (FR-1..FR-3). State the narrowed rule where "file output is English" is stated, or record that the existing wording already holds unchanged. | `docs/agent-protocol.md` | `framework/boundaries.md`, `scripts/validate-specs.py` | 2 | writing-specs | default | ☑ done |

## Evidence

Measured 2026-08-30, `tobevisit-content` corpus, per class before → after:

| Class | Before | After |
|---|---|---|
| `english_only` | 21 | 1 |
| `link_broken` | 1 | 1 |
| **Total** (99 specs) | **22** | **2** |

The baseline is larger than `## Current State` records (21 findings over 95
specs, logged 2026-08-22/28) because the corpus grew; the shape is unchanged.

- **AC-1, AC-2, AC-3** — `./scripts/test/validate-specs.test.sh`, three fixtures
  drawn from the real failures. Written first and recorded failing against the
  old predicate (AC-1 and AC-2 red, five assertions), green after.
- **AC-4** — one run, counts above. `english_only` is 1, not 0: see the
  divergence below. `link_broken` is untouched by design (OS-2).
- **AC-5** — passes against `BUG-TEMPLATE.md` unmodified.
- **Regression** — `make check` green: 29 specs, 1 agent, 13 checks, plus every
  self-test suite.

### Divergences

- **FR-4's defect was already closed.** `BUG-TEMPLATE.md` already carries every
  `_REQUIRED_FIELDS` entry plus `severity`; IMP-20260826 fixed it. Nothing was
  added to the template. What was missing was the proof: the harness asserted
  silence on `affected-docs` alone, so the template could have lost any other
  field unnoticed. The assertion now covers all of `schema_missing_field`.
- **AC-4 lands at 1, not 0.**
  `CR-20260615-admin-configuration-management.md:97` writes `так може` in
  unquoted prose — a human's non-committal answer quoted with straight double
  quotes inside a Split Decision. FR-3 **requires** this to keep firing; the
  check is right and the line is not. Reaching 0 is a one-line edit in
  `tobevisit-content` (backticks around the quoted answer), which is that
  repository's change — this spec's `affected-repos` is `ai-dotfiles` alone.
  Left for the consuming repo, in the shape of OS-1.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. AC-4 runs against the
`tobevisit-content` spec corpus by path — the validator takes a root argument.

## Docs updates required

- `docs/agent-protocol.md` — if the narrowed rule changes what "file output is English" means in
  practice, say so where the rule is stated.

## Rollout / migration notes

- No migration. The change only removes findings; a repository that was passing keeps passing.
- Record the before/after finding count per class, not a total (log, 2026-08-20: an analyser's
  finding count is a measurement, not an estimate).
