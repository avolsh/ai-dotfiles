# Design System

*Last updated: YYYY-MM-DD*

The design system for <surface> (<stack>). State whether **Figma is the
source of truth** (design-first) or the code is (code-first) — the loop
differs, and every later decision hangs off it.

---

## Figma version table

**The single declaration site for every Figma file key this project owns** —
current and superseded. No other live doc repeats one; prose elsewhere points
here, so cutting a new version is a one-line edit. Another project's file that
this repo only reads is a **citation, not a declaration** — it stays with the
fact that cites it and never enters this table.

| File key | File name | Version | Status | Frozen on |
|---|---|---|---|---|
| `<fileKey>` | `<file name>` | v0.1 | current | — |
<!-- One row per key. Exactly one row is `current`; the rest are `frozen`
     with the date they were retired. Never delete a row — a frozen key is
     what makes a closed spec's node links resolve to the design it was
     written against. Never retro-edit keys inside archived specs. -->

Rotation and freeze procedure (duplicate as successor, rename the
predecessor `· frozen`, move it to the archive project, update `00 Cover`):
`<system>/prompts/references/figma-file-organization.md` § 6.

## Token taxonomy

| Group | Tokens | Notes |
|---|---|---|
| `color/*` | <semantic names> | <ramp / theming notes> |
| `space/*`, `radius/*`, `font/*` | <values> | |
<!-- Foundations are Figma variables or styles — never hardcoded values. -->

## Primitive catalog (Figma components)

<Slash-named components with variant properties: `Button / Primary`, `Input`,
`Table`, … Every primitive binds fills/strokes/spacing/radius to variables.>

## Figma ↔ code mapping

| Figma | Code |
|---|---|
| `<variable / component>` | `<code token / component>` |

## Rules (design-system-first)

1. **No hardcoded styles** — in code or in Figma; values come from tokens.
2. **Instance, never copy** — a repeated structure is one component, instanced.
3. **Discover before building** — enumerate the existing library first; build a
   missing primitive as a library component, never inline.
