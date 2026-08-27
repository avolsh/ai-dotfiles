---
id: IMP-20260826-failure-diagnosability
type: IMP
date: 2026-08-26
status: done
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/handling-external-failures/SKILL.md
  - framework/skills/configuring-applications/SKILL.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
---
# IMP-20260826-failure-diagnosability
*Last updated: 2026-08-27*

## Summary
- **Goal:** Keep the one piece of information that identifies a cause — the upstream message at a boundary, the resolved value in a configuration — instead of only the class it belongs to.
- **Scope:** Two paragraphs: one in `handling-external-failures` on carrying a provider's own message through a permanent failure, one in `configuring-applications` on observing a setting where the process reads it.
- **Out of scope:** Logging, telemetry and error-reporting conventions; the classification rules themselves, which were correct in the incident below.

## Current State
`handling-external-failures` requires a boundary result to be classified before it is stored, and warns against collapsing outcomes. It says nothing about the provider's own account of a failure, and the omission reads as permission to discard it.

During CR-20260825-catalog-media-studio a Mapillary adapter raised `Mapillary answered 400` and dropped the response body. The classification was **right** — a 400 is permanent, and the code said so. What was missing was orthogonal to class: Mapillary had written `Invalid OAuth access token - Cannot parse access token`, which names the cause outright. Two rounds of debugging went into probing the API by hand to recover a sentence the process had already been handed and thrown away.

The same incident exposed the configuration half. The suspect value was inspected first by reading `.env.local`, then through a shell pipeline; both misled, in opposite directions — the file read stripped quotes `dotenv` preserves, and the shell probe failed to strip quotes the loader removes. The decisive check was three lines that imported the settings module and printed the resolved value's length and prefix. `configuring-applications` covers where a value may come from and says nothing about how to see what a running process actually holds, so the obvious move — read the file — is the one that answers a different question.

## Proposed Improvement
Two additions, each one paragraph, each in the skill that already owns its half.

`handling-external-failures`: a permanent failure carries the provider's own message alongside its class, bounded in length. Class and cause are different information, and only class is reconstructible from the outcome — a caller told "permanent" can retry correctly and still not know what to fix.

`configuring-applications`: a configuration value is diagnosed from what the process resolved, never from the file it came from. Every layer between them — loader quoting rules, schema defaults, store merge, parse function — can change the value, so the source file answers a question nobody asked.

**Measurable benefit:** on the incident above, the first change puts the causal sentence in front of the operator at the first failure instead of the third probe; the second replaces two misleading diagnostics with the one that decided it.

## Requirements
- FR-1: `handling-external-failures` MUST state that a permanent failure carries the provider's own message beside its classification, and MUST say the message is bounded in length so a large error document cannot become the error.
- FR-2: That paragraph MUST say plainly that classification and cause are different information, so the addition is not read as a restatement of the three-outcome rule it sits beside.
- FR-3: `configuring-applications` MUST state that a configuration value is diagnosed from the value the process resolved rather than from its source file, and MUST name what sits between the two: loader quoting, declared defaults, store merge and any parse function.
- FR-4: Both additions MUST carry the incident's shape as their worked example, so a reader meets the rule as something that happened rather than as advice.

## Acceptance Criteria
### AC-1: A permanent failure keeps its cause (FR-1, FR-2)
Given `handling-external-failures/SKILL.md` at HEAD
When the failure-classification section is read
Then it requires the provider's message beside the class, bounds its length, and states that the two are different information

### AC-2: Configuration is diagnosed where it is read (FR-3)
Given `configuring-applications/SKILL.md` at HEAD
When the diagnosis guidance is read
Then it directs the reader to the resolved value and names the four layers that can differ from the source file

### AC-3: Both rules are grounded (FR-4)
Given both skills at HEAD
When each new paragraph is read
Then each carries a concrete failure it would have shortened, not a generic caution

### AC-4: Neither skill repeats the other's rule
Given both skills at HEAD
When each is searched for the other's statement
Then each rule appears in exactly one skill, per the framework's single-statement rule

## Design
Skipped — two paragraphs of rule text in existing skills; no structure, data flow, schema, pipeline step or UI surface is involved.

## Out of Scope
- OS-1: What a caller *does* with the message — display, log, or both — which is a product decision.
- OS-2: `boundaries.md`. The always-on rule there ("a caught failure must not be recorded as a settled outcome") is unaffected: this sharpens what a correctly classified failure carries.

## Split Decision
Kept as one. Both halves answer one question — what information identifies a cause, and what is lost by keeping only its class — and both were found in a single incident whose two dead ends were the same mistake at two layers. Split, each is a one-paragraph spec whose motivation lives in the other.

## Tasks

> **Before starting Task T1, set `status: in-progress` in the front-matter above.**

Plan-stage safety net (`splitting-rules.md § 3`): P1 clear (3 tasks ≤ 12); P2 `unknown` — this repo ships no `docs/architecture/module-map.md`; the corpus is documentation only and no bounded context is in play; P3 clear — linear chain T1→T2→T3, no zero-dependency group: T2 is written against T1's landed paragraph to satisfy AC-4, and T3 closes every AC. Table stands.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Cause beside class (FR-1, FR-2, FR-4; closes AC-1): in `## Three outcomes, not one`, after the `failed-permanent (provider-404)` paragraph it extends, add one paragraph — a permanent failure carries the provider's own message beside its classification, bounded in length so a large error document cannot itself become the error; state plainly that class and cause are different information, and that only class is reconstructible from the outcome. Ground it in the Mapillary shape: `Mapillary answered 400` was a correct classification that discarded `Invalid OAuth access token - Cannot parse access token`. Extend the `description:` trigger list (e.g. "error body dropped", "provider message discarded") so the rule is reachable from the symptom; bump `*Last updated:*`. | `framework/skills/handling-external-failures/SKILL.md` | `docs/writing-skills.md` *(canonical shape)*; this spec; `docs/specs/archived/IMP-20260813-failure-semantics-rules.md` *(section precedent)* | — | writing-docs | deep | ☑ done |
| T2 | Diagnose where the value is read (FR-3, FR-4; closes AC-2, completes AC-3): add one paragraph to `configuring-applications` — a configuration value is diagnosed from what the process resolved, never from the file it came from — naming all four layers that can differ from the source (loader quoting, declared defaults, store merge, any parse function). Place it after `## One validated accessor`, whose accessor is the thing to read through. Ground it in the incident's two misleading probes (file read kept quotes `dotenv` strips; shell probe stripped quotes the loader keeps) against the three lines that decided it. The worked example concerns a secret, so phrase the diagnostic so it cannot be read as licence against `## Secrets never reach a log` — a length-and-prefix check at a terminal is not a log line. Bump `*Last updated:*`. | `framework/skills/configuring-applications/SKILL.md` | T1's landed paragraph *(non-overlap + shape)*; `docs/writing-skills.md`; this spec | T1 | writing-docs | deep | ☑ done |
| T3 | Separation + closure (AC-4, AC-3): grep each skill for the other's statement — the cause-beside-class rule must appear only in `handling-external-failures`, the resolved-value rule only in `configuring-applications`, per the framework's single-statement rule; confirm each new paragraph carries a concrete failure rather than a generic caution. Run `make check` (`links-check`, `install-check`, `validate-specs`, `lint-rules`, `validate-anchors`, `tests`), naming any pre-existing unrelated failure. Log to `docs/improvements-log.md` that a correctly classified failure discarded the one sentence naming its cause, and that the config half was diagnosed from a file three layers away from the value in play. Fill `## Closure Evidence`. | `docs/improvements-log.md`; `docs/specs/active/IMP-20260826-failure-diagnosability.md` | both skills at HEAD after T2; `framework/boundaries.md` *(OS-2: confirm untouched)* | T2 | writing-specs | default | ☑ done |

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- Covered by `affected-docs`: the skill text is the deliverable.
- `docs/improvements-log.md` — closure entry recording that a correctly classified failure discarded the one sentence naming its cause, and that its configuration half was diagnosed three layers away from the value in play.

## Rollout / migration notes
- No migration. Existing adapters are not audited by this spec; it states the rule new and revisited boundaries are written against.

## Closure Evidence
| AC | Evidence | Verdict |
|---|---|---|
| AC-1 | `handling-external-failures/SKILL.md § Three outcomes, not one` carries a new paragraph directly after the store-the-classification one it extends: a permanent outcome records what the provider actually said — its error message or the reason field from its body — **truncated to a bounded length, so a large error document cannot itself become the error** (FR-1), and states plainly that **class and cause are different information, and only the class is reconstructible from the outcome**, with the consequence spelled out — a caller told `permanent` stops retrying correctly and still has no idea what to fix (FR-2). | met |
| AC-2 | `configuring-applications/SKILL.md § One validated accessor` carries a new paragraph: a value is diagnosed where the process reads it, never from the file it came from, naming all four layers between the two — loader quoting rules, declared default, store merge, and any parse function the value passes through — and why each matters: each can make the file and the effective value differ, so the source file answers a question nobody asked (FR-3). Placed under the accessor section because the accessor is the thing to read through. | met |
| AC-3 | Both paragraphs carry the CR-20260825-catalog-media-studio incident, not a generic caution (FR-4). The failure half names the discarded string verbatim — `Mapillary answered 400` classified correctly, `Invalid OAuth access token - Cannot parse access token` dropped — and the two rounds of hand-probing it cost. The configuration half names both misleading probes and the direction each misled in (file read kept quotes `dotenv` strips; shell probe stripped quotes the loader keeps) against the three lines that settled it. | met |
| AC-4 | Separation verified by grep at HEAD. `configuring-applications` matches none of `provider`, `permanent`, `classif`, `beside the class`; `handling-external-failures` matches none of `resolved value`, `source file`, `loader`, `quoting`, `store merge`, `parse function`, `.env`. Each rule states itself in exactly one skill, per the framework's single-statement rule. | met |
| Closure | `make check` → exit 0, every target green: `links-check` (140 files), `ai-install --check`, `validate-specs` (28 specs, 13 checks), `lint-rules` (10 canonical rules, 31 phrases), `validate-anchors` (70 fragment links across 139 files), and the eight self-test suites. No pre-existing unrelated failures to name. `framework/boundaries.md` confirmed untouched per OS-2. Both skills' `*Last updated:*` bumped to 2026-08-27. | met |

**Deviation from the plan, T2.** The approved T2 row did not call for a `description:` change — only T1 did. Both trigger lists were extended anyway ("error body dropped", "only a status code to go on"; "env var not taking effect", "wrong config value at runtime"), on the same reasoning the plan gave for T1: a rule reachable only from its own vocabulary is a rule nobody loads mid-incident, and the configuration half is the one a reader meets while already holding a value that looks wrong. Both skill descriptions were re-surfaced by the harness on save.

**Note carried into the text, T2.** The configuration paragraph's worked example concerns an OAuth token, and the diagnostic it endorses prints that value's length and prefix. The paragraph says explicitly that this is a check run at a terminal, deliberately narrow — length and prefix tell two candidate values apart without putting the value anywhere it persists — and that `§ Secrets never reach a log` below is not relaxed by it. The plan flagged this as the likeliest place for the implementation to drift; it is stated in the shipped text rather than left to the reader.

**Review-after closure** (`spec-lifecycle.md § Review-after closure`, `risk: low`): flipped to `done` and archived on evidence, for batch review by the owner. The reviewer sub-step was not run — non-blocking at this risk level, and this session is configured not to spawn sub-agents unbidden.
