---
id: IMP-20260914-responsive-behaviour-and-design-first-figma
type: IMP
date: 2026-09-14
status: specify
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/prompts/references/figma-file-organization.md
  - framework/prompts/visualize-spec.prompt.md
  - framework/spec-workflows/spec-lifecycle.md
  - framework/templates/project/docs/architecture/design-system.md
  - docs/rule-canonical-map.md
affected-code:
  - scripts/validate-specs.py
  - scripts/test/validate-specs.test.sh
skills:
  - writing-specs
  - writing-docs
  - test-driven-development
model-suggestion: default
# Siblings live in `tobevisit-web` (IMP-20260914-figma-foundations-and-components-rebuild,
# IMP-20260914-figma-web-and-behaviour-rebuild) — named rather than linked; a spec does not reach across repos.
---

# IMP-20260914-responsive-behaviour-and-design-first-figma

*Last updated: 2026-09-14*

<!-- Length budget: ~137 body lines — nine independent convention gaps each need their own evidence line; FRs stay one line each. -->

## Summary

- **Goal:** Let the Figma convention describe a responsive, design-first product file — breakpoints,
  component behaviour sequences, shared variant axes, brand assets and implementation status.
- **Scope:** Amendments to `figma-file-organization.md` §§ 1, 3–7 and `assertPlacement()`, the
  `design-system.md` project template, one closure rule in `spec-lifecycle.md`, rule-map
  registration and a validator probe.
- **Out of scope:** Changing any project's Figma file — that is the two `tobevisit-web` siblings.

## Current State

**The convention was written against one project: a desktop-only, code-first admin UI.** Applying it
to `tobevisit-web` (Figma file v0.3, 7 pages, 19 product frames, 19 behaviour frames) exposes gaps:

- **Breakpoints have no slot.** § 4 says a breakpoint "is a `· sm/md/lg` suffix", but three frames
  sharing `[W-05.01]` fail assertion B (one `.01` per screen) and C (one row per screen's states).
  The web file draws every screen at 320 / 768 / 1024.
- **`80 Behaviour` and `[B-…]` are named but undefined.** § 4's own table makes an overlay over a
  route a *state* of that screen, so a header filter drawn as a nine-step sequence has no legal home.
  The web file's `Behavior` page holds exactly that: the search filter and language selector.
- **`<View>` is admin vocabulary** (List / Detail / Edit / …); a home or about page has no value.
- **Variant axes are unconstrained.** One file uses `width=desktop`, `width=1024`, `size=desktop`
  and `status=hovered` for the same two concepts.
- **Brand assets have no page.** The web file parks six 512 px logo masters on a `Logos` page, and
  the same mark again as `icon/logo`.
- **"The current file carries no divergence" assumes code-first.** In a design-first file the design
  leads the code; nothing says which frames are implemented, designed-only, or changed since.
- **No rule covers rebuilding a file** rather than renaming it in place.
- **Fonts are an unstated precondition.** The `use_figma` runtime cannot load a local font:
  `Helvetica Neue` fails with `font family does not exist`, so no text in it can be written by an agent.
- **Text slots are never checked against the longest locale** (`uk` / `ru` run longer than `en`).

## Proposed Improvement

Extend the convention rather than open a rival one. Breakpoints become a suffix that shares an ID;
Behaviour becomes a per-component sequence page; a two-question rule decides where any drawing goes;
a design-first file carries a per-frame implementation badge flipped at spec closure.

**Measurable benefit.** On the web file: all 38 product + behaviour frames receive a legal ID and
pass `assertPlacement()` (baseline 0); variant axis names across component sets drop from 4 to a
declared set; the placement of every existing drawing is decidable from the doc alone.

## Requirements

- FR-1: A product frame of a responsive file MUST carry a breakpoint suffix `· <bp>` whose names and order the project declares in `design-system.md`; one ID MAY have one frame per breakpoint, and a state MAY omit breakpoints it does not have.
- FR-2: The section layout MUST place a state's breakpoint frames left to right in declared order inside the state's column group, and `assertPlacement()` MUST check "one `.01` per screen per breakpoint" and breakpoint order within a state.
- FR-3: The doc MUST state the placement decision as two questions: a surface reused on several pages is a component variant in `02 Components`; a change specific to one route is a screen state on the platform page; a transition whose order is not obvious from variants is additionally a sequence on `80 Behaviour`.
- FR-4: A `80 Behaviour` frame MUST be named `[B-<flow>.<step>] <Flow> · Step N — <change> · <bp>`, show only the page region the transition needs, be composed of component instances, number steps independently per breakpoint, and cite `→ W-xx.yy` when a step equals a screen state; on that page a row is one flow at one breakpoint.
- FR-5: `<View>` MUST gain `Landing` for a route that is neither a list nor a record.
- FR-6: A file MUST declare one variant-axis vocabulary (property names and values) in `design-system.md`, and every component set MUST use only declared axes; breakpoint-valued axes MUST reuse the frame breakpoint names.
- FR-7: `01 Foundations` MUST hold a `Brand` section of logo component sets sharing one axis vocabulary, which UI components instance rather than redraw; media aspect ratios MUST be declared there as tokens, not as frame sizes.
- FR-8: A design-first file MUST mark every root frame on platform and behaviour pages with a `status/implementation` instance — `Implemented`, `Designed` or `Changed`, plus the spec ID — and `00 Cover` MUST summarise it per screen; code-first files omit it.
- FR-9: `spec-lifecycle.md` closure MUST require flipping those badges for every frame a design-first spec implemented or changed.
- FR-10: The doc MUST describe rebuild-beside migration: originals renamed `[OLD] <name>` and exempt from the taxonomy until deleted, per-screen before/after in the spec's `## Design`, deletion only after human confirmation, and node-ID changes resolved by the frozen key.
- FR-11: § 5 MUST require every font family a file uses to be loadable by the write runtime (`listAvailableFontsAsync`) and name a font that is not as a blocker for agent editing.
- FR-12: § 3 MUST require text-bearing components to be verified with the longest shipped locale string without auto-layout overflow.
- FR-13: The `design-system.md` template MUST gain source-of-truth mode, breakpoint table, variant-axis vocabulary and status legend sections.
- FR-14: New rule sentences MUST be registered in `docs/rule-canonical-map.md`, and `validate-specs` MUST have probe fixtures proving `[W-03.02] … · lg` and `[B-01.03] … · base` alt text pass.

## Acceptance Criteria

### AC-1: A responsive screen places itself (FR-1, FR-2, FR-5)

Given `Places — List` drawn at base, md and lg, with a map-view state only at base and lg
When an agent names and places those five frames from the doc alone
Then it produces `[W-03.01]`×3 and `[W-03.02]`×2 in one row, and `assertPlacement()` passes
Evidence: worked example in `figma-file-organization.md`; routine exercised in the web sibling

### AC-2: Every drawing has exactly one home (FR-3, FR-4, FR-7)

Given the header search filter, a place-page gallery overlay, and six logo masters
When the two-question rule is applied
Then the filter lands as variants + `[B-01.xx]` flow, the gallery as `[W-04.02]`, the logos as
`Brand` component sets — each with no second legal placement
Evidence: rule text with these three worked examples

### AC-3: Implementation status is visible and maintained (FR-8, FR-9)

Given a design-first spec that changed `[W-01.03]`
When it reaches closure
Then the lifecycle rule requires the badge to read `Implemented` with the spec ID, and the Cover
summary counts it
Evidence: closure rule text; badge applied in the web sibling

### AC-4: Conventions are enforceable (FR-6, FR-10, FR-11, FR-12, FR-13, FR-14)

Given the updated template and doc
When `make lint-rules` and the `validate-specs` test suite run
Then both pass with the new sentences registered and the breakpoint/behaviour ID fixtures green
Evidence: command output

## Design

Skipped — naming, placement and lifecycle convention with no UI surface of its own; its first
application is drawn in `IMP-20260914-figma-web-and-behaviour-rebuild`.

## Out of Scope

- OS-1: Migrating `tobevisit-web`'s Figma file — sibling specs.
- OS-2: Retrofitting `tobevisit-content` — desktop-only and code-first; no rule here changes it.
- OS-3: Figma prototype connections on `80 Behaviour` — optional, not required by any FR.
- OS-4: Code Connect mapping — needs a Dev seat (see content OS-5).

## Split Decision

Split — T3 + T6. The convention (this repo) and the migration (`tobevisit-web`, two siblings) target
different repos, and the human approved a three-spec split on 2026-09-14. This spec has no
dependency; both web siblings `depends-on` it.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `framework/prompts/references/figma-file-organization.md` — §§ 1, 3, 4, 5, 6, 7 per FRs.
- `framework/prompts/visualize-spec.prompt.md` — hard rules reference breakpoints, Behaviour, status.
- `framework/spec-workflows/spec-lifecycle.md` — closure rule (FR-9).
- `framework/templates/project/docs/architecture/design-system.md` — new sections (FR-13).
- `docs/rule-canonical-map.md` — new rule rows.
- `docs/improvements-log.md` — entry.

## Rollout / migration notes

- Must reach `done` before either `tobevisit-web` sibling advances to `plan`.
- Existing content-project files remain conforming: every new rule is conditional on a responsive or
  design-first file.
