---
id: IMP-20260829-english-only-and-domain-data
type: IMP
date: 2026-08-29
status: specify
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

## Tasks

Pending — Plan stage only.

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
