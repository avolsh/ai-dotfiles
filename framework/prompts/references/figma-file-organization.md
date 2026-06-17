# Figma file organization — naming & structure conventions

*Last updated: 2026-06-17*

Reference for the [Visualize sub-step](../visualize-spec.prompt.md). Applies
whenever a spec's `## Architecture` links Figma frames, or when creating /
restructuring a Figma file for a project. Goal: a sidebar that is scannable
at a glance and a design system that product files can consume without
duplication.

## 1. Page naming

- **One taxonomy per file, applied consistently.** Each page name = a
  **zero-padded numeric prefix** (sorts the sidebar deterministically) + a
  **Title Case** label. Numbers group and order; they are not decoration.
- **Recommended prefixes** (leave gaps so pages can be inserted without a
  global renumber):

  | Prefix | Page role |
  |---|---|
  | `00 Cover` | File purpose, owners, links, status legend (set as thumbnail) |
  | `01 Foundations` | Tokens visualised: color, type, spacing, grid, radius, elevation, icons |
  | `02 Components` | Component / variant library (omit once a separate library file exists) |
  | `10 Web`, `20 iOS`, `30 Android` | **Platform is the primary axis** — one page per platform actually shipped; domains live as **Sections** inside |
  | `80 Behaviour` | Complex transitions / prototype flows / navigation maps |
  | `90 Explorations` | WIP / divergent options not yet agreed |
  | `99 Archive` | Superseded frames kept for history |
  | `─────────` | Divider page (empty, label only) separating groups |

- **Platform first, domain second.** The top axis is the platform (`Web` /
  `iOS` / `Android`). Only create a platform page you actually ship — **never
  an empty `iOS` page "for later"**. Inside a platform page, group product
  domains as Figma **Sections** (`Reference Data`, `Billing`, …), not as more
  pages. This keeps the sidebar shallow while staying scannable.
- **Do** keep names short and stable (`10 Web`, not `Web screens v2 FINAL`).
- **Don't** put version numbers or dates in page names — use Figma file
  versioning / branches for that. **Don't** mix two prefix schemes (e.g.
  numeric + emoji) in one file.

## 2. How many pages in the sidebar

- **Lean is the rule.** A focused product file should sit around **5–9
  top-level pages**. Past ~12, the sidebar stops being scannable — either
  group with divider pages or split into multiple files.
- **A page = one platform (or one library/system layer).** Domains within a
  platform are **Sections**, not pages — this is what stops the sidebar from
  fragmenting into many shallow per-domain pages. Spawn a new *page* only for
  a new platform or a system layer.
- **Never park unrelated content off-canvas at negative coordinates** to
  avoid making a page — give it its own page or section instead.

## 3. Design system structure

- **Early stage:** keep the system as `01 Foundations` + `02 Components`
  pages inside the product file.
- **Once it stabilises:** promote it to a **dedicated, published library
  file**; product files *consume* it as a subscribed library. The system
  never lives twice.
- **Foundations are tokens, not swatches.** Every color, type, spacing,
  radius, and elevation value MUST be a Figma **variable** (in a collection,
  with modes for theming) or a **style** — never hardcoded. This is the same
  design-system-first rule the Visualize step enforces.

### Components page layout

- Organize the `02 Components` page into **named catalog frames by category**,
  never as loose components on the canvas: `Form Controls`, `Layout`,
  `Data Display`, `Icons`, … Each catalog is an auto-layout frame; a new
  component goes **into** its matching catalog, not dropped beside it.
- **Icons get their own `Icons` catalog frame** (a row/grid of the icon
  components), kept separate from structural/layout components.
- A component whose on-canvas name shows as `…` is usually just a very narrow
  node truncating its label — verify the real `name` before "fixing" it.

### Component naming (slash hierarchy)

Slashes create groups in the Assets panel and structure variants:

```
Button / Primary / Default
Button / Primary / Hover · Focused · Disabled   ← variant properties, not separate components
Input / Text / Default
Form Controls / Checkbox
```

- Use **variant properties** for states (Default/Hover/Focused/Disabled) and
  for size/tone — not separately named components.
- Component-set name = the family (`Button`); properties carry the rest.

### Variable / token naming (path hierarchy)

Token-path style, slash-separated, semantic over raw:

```
color/bg/default      color/text/muted      color/border/subtle
space/100  space/200  space/300             radius/sm  radius/md  radius/lg
```

- Prefer **semantic** names (`color/text/muted`) over raw values
  (`color/grey/600`); back semantics with a primitive layer if needed.
- Use **collections + modes** for theming (e.g. light/dark) rather than
  duplicate variables.

## 4. Product (app) pages & frame naming

### Page → Section → Frame

- **Page = platform** (`10 Web`, `20 iOS`, `30 Android`). **Section = domain**
  inside that platform (`Reference Data`, `Places`, `Settings`, …). **Frame =
  screen** inside the section. Order frames left→right by flow:
  **List → Detail → Edit → states**.
- Don't make one page per screen (sidebar explosion) and don't pile every
  domain onto a flat page — Sections carry the domain grouping.
- **Automation note — coordinates:** a Figma **Section's children use
  section-relative coordinates**, not absolute. When placing frames into a
  Section programmatically, set each child's `x`/`y` in *local* grid
  coordinates (e.g. `x = 60 + (i%2)*1540`, `y = 160 + ⌊i/2⌋*1000`); absolute
  values overflow the section bounds and the frames scatter off-canvas.
- **Automation note — a grown frame must not burst its section.** When you
  resize a screen frame taller (e.g. adding a section of content), the frame
  must stay inside its host Section **and** the Section must not collide with
  the next one. Grow the Section to `frameRelativeY + frameHeight + padding`,
  then verify with a read: `frameBottom ≤ sectionBottom` **and**
  `sectionBottom < nextSection.y` (canvas coords). Resizing a frame without
  this check overlaps the neighbouring Section.

### Frame level — mandatory ID tag

Every root (screen) frame is named:

```
[<ID>] <Entity> — <View> · <state>
```

- **`[<ID>]`** — *required*. Platform letter + zero-padded sequence, unique
  per platform: `[W-01]`, `[W-02]`, `[I-01]` (iOS), `[A-01]` (Android),
  `[B-01]` (Behaviour). Gives every screen a stable handle for specs / tickets
  / hand-off, independent of its title.
- **`<Entity> — <View>`** — em dash. `View` ∈ List / Detail / Edit / Create /
  Empty / Loading / Error / Console.
- **`· <state>`** — readable state suffix (`· Empty`, `· Validation error`).
  Prefer a **variant property** for state where the screen is a component.
- **Step / wizard:** `[W-07] <Flow> · Step N — <View>`.
- **Never** encode size in the name (Figma stores dimensions — it drifts on
  resize); breakpoints, if needed, are a `· sm/md/lg` suffix, not digits.
- Use the **product's user-facing vocabulary**; never embed `v2`/`FINAL`/dates.

Examples: `[W-01] Countries — List`, `[W-02] Countries — Edit · Validation error`,
`[W-11] Ingestion · Step 1 — Console`.

### Layer level (inside frames)

- **Name layers by role or content, never tool defaults** (`Frame`,
  `Group`, `Rectangle`, `Text`). Auto-layout containers get semantic names:
  `Row`, `Toolbar`, `Field`, `Header`, `Body`.
- **Don't blanket-rename deep one-off leaves** — diminishing returns. The
  80/20 is structural and reused layers; trivial decoration can stay.
- **Prefer componentizing over hand-renaming copies.** A recurring
  structure that shows up as dozens of identical `Frame` / `Cell` layers
  (table rows/cells, cards, buttons, inputs, badges) should be promoted to a
  **component** in `02 Components`. Instances then inherit a clean name, and
  you fix naming, duplication, and future Code Connect in one move — far
  better than renaming N copies by hand.

## 5. Build mechanics (`use_figma` write API)

Construction rules for *generating* frames programmatically — the companion to
the discovery half of the design-system-first rule in
[`visualize-spec.prompt.md`](../visualize-spec.prompt.md).

- **Enumerate before you write.** Before the first `use_figma` write, list every
  `COMPONENT` / `COMPONENT_SET` in the file (walk `figma.root`) and note which
  catalog each lives in. You cannot reuse what you did not look up — skipping
  this is what leads to redrawing primitives that already exist.
- **Instance, never copy.** A repeated pill/badge/chip → `comp.createInstance()`
  (override `fills` + nested text), not a hand-drawn rounded rectangle. A
  repeated card/row → make **one component** and instance it per record; never
  paste the same node N times. This is the §4 "componentize over copies" rule
  applied at build time.
- **Auto-layout owns spacing.** Any new component or section frame uses
  `layoutMode` + `itemSpacing` + padding (and `layoutSizingHorizontal = "FILL"`
  for fluid children). **Never hand-compute child `x`/`y` offsets** — manual
  absolute positioning is what produces cramped, mis-aligned, and overflowing
  frames. Let auto-layout hug content; read back `node.height` afterwards if you
  need it.
- **`throw` rolls back the whole write.** Ending a script with `throw` (e.g. the
  throw-to-read-id trick) discards every mutation in that call. Surface an
  id/size in a **separate read-only call**, or **measure-then-resize inline** in
  the same non-throwing script — never `throw` to read a value you still need to
  apply.
- **`figma.currentPage = page` throws** — use `await figma.setCurrentPageAsync(page)`.
  You rarely need to switch pages: `getNodeByIdAsync` + screenshot-by-node-id
  work cross-page.

## 6. Quick checklist (Visualize sub-step)

- [ ] Pages follow one numeric + Title Case taxonomy; ≤ ~9 top-level pages.
- [ ] Platform is the top axis (`10 Web`/`20 iOS`/…); no empty platform pages;
      domains are **Sections**, not pages.
- [ ] Every root frame named `[<ID>] <Entity> — <View> · <state>` (ID tag
      required; size never in the name).
- [ ] No tool-default layer names (`Frame`/`Group`/`Cell`) on structural or
      reused layers; recurring structures componentized, not hand-renamed.
- [ ] `00 Cover` set as the file thumbnail with a status legend.
- [ ] Foundations + Components on their own pages (or a separate library file).
- [ ] No hardcoded styles; values come from variables / styles.
- [ ] Components use slash naming + variant properties.
- [ ] Components page organized into category catalog frames (Form Controls /
      Layout / Data Display / Icons), no loose components; icons in their own frame.
- [ ] No content parked off-canvas to dodge creating a page.
- [ ] Existing components enumerated before writing; repeated pills/cards built
      as instances of one component, not hand-drawn copies.
- [ ] New components/sections use auto-layout for spacing; no hand-computed
      child `x`/`y`.
- [ ] Any frame grown taller keeps `frameBottom ≤ sectionBottom < nextSection.y`
      (host section grown, neighbour not overlapped).
