---
id: IMP-20260902-frame-ids-and-section-layout
type: IMP
date: 2026-09-02
status: specify
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/prompts/references/figma-file-organization.md
  - framework/prompts/visualize-spec.prompt.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
---

# IMP-20260902-frame-ids-and-section-layout

*Last updated: 2026-09-02*

## Summary

- **Goal:** Make a frame's identifier say which screen it belongs to, and make where it sits follow
  from that identifier.
- **Scope:** A two-part frame ID (`[W-11.02]`), the rule that separates a screen from a state, the
  allocation rule for both halves, and a section layout derived from the ID — one row per screen,
  its states beside it. Supersedes the append-to-the-right placement clause that produced the
  scatter. Applies to product (platform) pages only.
- **Out of scope:** Renaming or re-laying-out any project's file — that is the migration spec.

## Current State

**One screen, two unrelated numbers.** `[W-11] Ingestion · Step 1 — Console` and
`[W-59] Ingestion · Step 1 — Console · month exhausted` are the same screen. Nothing but a
substring of the name says so, and the ID — the part specs cite, the part a reader scans — says the
opposite. The convention allocates a fresh top-level number per *frame*, so a screen's third state
is as far from it in ID space as an unrelated screen is.

**The ceiling is spent on variants.** `tobevisit-content` reached `W-59` across 59 frames covering
roughly 33 screens: 26 of them are states. Two digits run out at 99, and it is variants doing the
spending — a well-covered screen with eight states costs eight top-level numbers.

**The placement rule produces scatter, and it is doing what it says.** § 5 reads *"Slot taken from
the section box as a new right-hand column — never from sibling extents, never a new row."* Written
against overlaps, it is silent about grouping, so each new state lands wherever the section
currently ends. Measured on the live file: `Catalog` is 45% filled across 12 row bands, `Canonical`
53% in a single row 8 480px wide, and the `Map` screen's seven states sit in four different bands
with the first and last 3 100px apart vertically. Appending has also produced near-duplicate
columns (3 140 and 3 160) and rows (159 and 160) — the residue of "next free slot" arithmetic.

**Nothing above is a mistake by the agent that made it.** Each frame was placed exactly as the rule
directs. That is why this is a convention change rather than a review note.

**Two rules landed in this same doc earlier today, Direct lane, owner-directed** — "the current file
carries no divergence" (§ 6) and the page-level section-grid check (§ 5) — both from the same
Visualize run that surfaced the scatter. This spec builds on that text rather than re-deriving it:
the grid check it adds is what FR-4's layout is asserted against, and the no-divergence rule is what
makes FR-6's "reflow is ordinary" enforceable. Declared here because a cold reader will otherwise
open a reference doc that has moved since the last archived spec touched it.

## Proposed Improvement

Give the ID two parts — `[<platform>-<screen>.<state>]` — where the screen number is stable for the
life of the screen and the state number is allocated within it. `[W-11.01]` is the default state,
`[W-11.02]`, `[W-11.03]` are the others. A reader sees the grouping without reading the name; a spec
citing `W-11.03` says which screen it is about.

Then derive placement from the ID instead of from the section's current extent: one row per screen,
its states left to right in `.NN` order. Adding a state inserts it into its screen's row and reflows
the section, which is cheap — a section's layout is a pure function of its frame list, so it can be
regenerated at any time rather than patched.

**Measurable benefit.** On the corpus this convention is written for: 59 top-level IDs collapse to
~33, and the per-screen ceiling stops being shared. Layout: the `Map` screen's states go from four
row bands to one, and a section's fill ratio stops being a function of the order frames were added.

## Requirements

- FR-1: A root frame's ID on a **product (platform) page** MUST be `<platform>-<screen>.<state>` — two zero-padded parts, e.g. `W-11.02` — and the `.<state>` half MUST be present on every frame, including a screen that has exactly one. A screen that gains a second state must not have to rename its first.
- FR-2: The screen number MUST be stable for the life of the screen: allocated once as `max(screen) + 1` for that platform, never reused, never renumbered to close a gap. The state number is `max(state) + 1` within its own screen, so two screens allocate independently.
- FR-3: The boundary MUST be stated as a rule an agent can apply without judgement: the same route in the application is the same screen; a modal, overlay, or panel over that route is a **state** of it; a different route is its own screen. Where a surface has no route (a report, a preview), the screen is the thing a person navigates to.
- FR-4: A section's layout MUST be derived from the IDs it contains — one row per screen ordered by screen number, that screen's states left to right in state order, packed left from the section origin with one column gutter and one row gutter. Row height is the tallest frame in the row.
- FR-5: The § 5 clause "never a new row" MUST be superseded, naming what replaces it: a new screen is a new row, a new state is an insertion into its screen's row, and both reflow the section rather than appending to its far edge. The overlap and containment assertions it protects stay unchanged.
- FR-6: Reflowing a section MUST be described as an ordinary act rather than a migration — any run that adds a frame leaves the whole section conforming, because a layout derived from IDs is regenerated, not repaired.
- FR-7: Archived specs MUST keep the single-part IDs they were written with, and the framework MUST say so explicitly: the mismatch between an archived spec's `[W-59]` and a live `[W-11.03]` is expected, is resolved by the frozen key those specs resolve against, and is never to be "corrected".

## Acceptance Criteria

### AC-1: The ID says which screen (FR-1, FR-2, FR-3)

Given the convention as written
When an agent is asked where a newly drawn "month exhausted" state of the ingestion console belongs
Then it produces `[W-11.03]` — the screen's own number, the next free state — without consulting
anything but the file
Evidence: the rule text plus a worked example in `figma-file-organization.md`

### AC-2: Placement follows from the ID (FR-4, FR-5, FR-6)

Given a section holding screens with several states each
When a new state is added to a screen in the middle of the section
Then it lands beside that screen's other states, the section reflows, and the containment, overlap
and grid assertions all still pass
Evidence: the layout recipe and its snippet, exercised in the migration spec's first task

### AC-3: The old IDs are left alone (FR-7)

Given an archived spec citing `[W-59]`
When it is read after a project migrates to the two-part scheme
Then the framework states that this is expected and points at the frozen-key mechanism, and no rule
asks for the archived spec to be edited
Evidence: the rule text; the § 6 versioning subsection it cross-references

## Design

Skipped — a naming and placement convention with no UI surface of its own. The layout it defines is
shown by the worked example in the reference doc and exercised by the migration spec.

## Out of Scope

- OS-1: Renaming or re-laying-out `tobevisit-content`'s file — `IMP-20260902-frame-id-migration`.
- OS-2: A mechanical check for either rule. Worth having and recorded in the improvements log; this
  spec writes the convention the check would enforce, and a check without an agreed convention has
  nothing to assert.
- OS-3: Three-digit parts. Two digits per half is a ceiling of 99 screens and 99 states each; the
  corpus that prompted this is at 33 and 8.
- OS-4: Platform prefixes beyond the existing `W-`/`iOS-` scheme.
- OS-6: The `00 Cover`, `01 Foundations` and `02 Components` pages. The scheme identifies an
  application screen and its states; a cover, a token sheet and a component catalog are none of
  those, and § 3 already governs how they are organised.
- OS-5: Component and variable naming — unchanged by this spec.

## Split Decision

Split considered on 2026-09-02. **T1 does not fire.** The ID scheme and the layout rule are not
independently testable: FR-4 orders rows by screen number and columns by state number, so it has
nothing to order until FR-1 exists, and AC-2's "lands beside that screen's other states" is
unstatable without the scheme that says which those are. **T3 fires** against
`IMP-20260902-frame-id-migration` in `tobevisit-content` — a different repo — and that split is
taken: this spec is the convention, that one applies it, and it declares `depends-on` here.
**E5 (documentation corpus)** covers what remains: both FR clusters ship documentation under one
reference doc, share one conformance pass, and this spec ships zero behavioural code change.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `framework/prompts/references/figma-file-organization.md` — § 4 frame naming gains the two-part ID,
  the screen-vs-state rule and the allocation rule; § 5 replaces the "never a new row" clause with
  the ID-derived layout and its snippet; § 6 gains the archived-spec sentence; § 7 gains a checklist
  line per FR.
- `framework/prompts/visualize-spec.prompt.md` — the hard rules name the two-part ID and point at
  § 4, so an agent mid-run sees it without opening the reference.

## Rollout / migration notes

- Documentation only; nothing executes, so there is no deploy order and revert is a revert.
- Projects already on single-part IDs stay valid until they migrate: the convention describes the
  target, and each project's migration is its own spec against its own file.
- The migration spec is written against this text, so a change here before it closes is a change to
  its ground — the re-verification key in `spec-lifecycle.md § Rules #10` applies.
