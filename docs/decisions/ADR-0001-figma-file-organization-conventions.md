# ADR-0001: figma-file-organization-conventions

- Date: 2026-06-17
- Status: accepted

## Context

The Visualize sub-step already enforced a *design-system-first* rule, but the
framework documented **nothing** about how a Figma file should be organized:
how to name pages, how many pages a file should carry, how the design system
is structured, and how product frames and layers are named. Figma coverage
was delegated entirely to the Figma MCP `/figma-*` skills, which teach *how to
generate* design, not a team standard for *how a file is laid out*.

Without a standard, files drift into recognizable anti-patterns — a single
catch-all page holding every screen, design-system primitives parked
off-canvas at negative coordinates, and hundreds of tool-default layer names
(`Frame`, `Cell`). A documented, enforceable convention was needed at the
visualization step so every project's Figma file is scannable and its design
system is consumable without duplication.

## Decision

Adopt a written Figma file-organization convention, owned by the framework and
referenced from the Visualize sub-step:

- **Reference doc:** `framework/prompts/references/figma-file-organization.md`
  (full taxonomy + Visualize checklist).
- **Enforcement:** a `File organization (Figma)` hard rule in
  `framework/prompts/visualize-spec.prompt.md`.

The convention itself:

- **Pages** — one taxonomy per file: a zero-padded **numeric prefix** +
  Title Case label. **Platform is the primary axis**: `00 Cover`,
  `01 Foundations`, `02 Components`, `10 Web` / `20 iOS` / `30 Android`
  (one per platform actually shipped — never an empty page "for later"),
  `80 Behaviour`, `90 Explorations`, `99 Archive`.
- **Count** — lean: ~5–9 top-level pages; sub-group within a page using
  Figma **Sections** rather than spawning pages; never park content off-canvas.
- **Domains = Sections.** Product domains live as Figma Sections inside a
  platform page, not as separate pages. Hierarchy:
  **Page (platform) → Section (domain) → Frame (screen)**.
- **Design system** — Foundations are Figma variables/styles (never
  hardcoded); slash-named components with variant properties; token-path
  variables; promote to a published library once stable.
- **Frames** — every root (screen) frame is named
  `[<ID>] <Entity> — <View> · <state>`, where `<ID>` is a platform letter +
  zero-padded sequence (`[W-01]`, `[I-01]`, `[A-01]`, `[B-01]`). The ID tag
  is **required** on every root frame — a stable handle for specs / tickets /
  hand-off, decoupled from the title. Size is **never** encoded in the name
  (Figma stores dimensions; encoding drifts on resize).
- **Layers** — no tool defaults on structural/reused layers; fix recurring
  duplicates by **componentizing**, not hand-renaming copies.
- **Components page** — organized into named catalog frames by category
  (`Form Controls`, `Layout`, `Data Display`, `Icons`); icons get their own
  `Icons` catalog frame; no loose components on the canvas.

## Alternatives Considered

- **Emoji-prefixed pages** (`📕 Cover`, `📐 Foundations`) — rejected: numeric
  prefixes sort the sidebar deterministically and read cleaner.
- **Domain as the primary page axis** (`10 Reference Data`, `20 Places`, …) —
  rejected: fragments the sidebar into many shallow per-domain pages; doesn't
  extend to multi-platform products. Domains became Sections instead.
- **One page per screen** — rejected: sidebar explosion, breaks the lean rule.
- **Single catch-all page** — rejected: not scannable; mixes domains.
- **Coded frame names** `web0003.0320.01` (platform+number+size+state) —
  rejected: opaque without a legend, fights the "scannable" goal, duplicates
  size that drifts on resize, buries state in a number instead of a variant.
  Kept only the human-readable parts + a short ID tag.
- **Platform pages even when single-platform** — accepted but constrained: a
  web-only file is just `10 Web`; never create empty `iOS`/`Android` pages.
- **Embedding the full convention inline in the prompt** — rejected: bloats
  the deliberately terse prompt. Kept as a linked reference doc instead.
- **No framework doc, rely on the Figma MCP skills** — rejected: those teach
  generation, not a team file-organization standard.

## Consequences

- The Visualize sub-step now audits Figma files against this convention via
  its checklist; new files are expected to conform.
- The reference doc stays **project-agnostic** (generic examples only);
  project-specific application is recorded in the project, not the framework.
- **Known limitation:** the Figma Plugin API cannot set the file thumbnail —
  the `00 Cover` frame must be set as thumbnail manually.
- **Naming insight folded into the convention:** prefer *adopting existing
  components as instances* over hand-renaming detached copies — added to the
  Layer-level guidance in `figma-file-organization.md`.
- **Implementation note (Figma Sections):** a Section's children use
  section-relative coordinates; programmatic placement must use local grid
  coordinates or frames overflow the section. Folded into the reference doc.
