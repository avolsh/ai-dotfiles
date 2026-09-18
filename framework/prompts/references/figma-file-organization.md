# Figma file organization — naming & structure conventions

*Last updated: 2026-09-14*

<!-- Anchors in this file (per `docs/rule-canonical-map.md`): R16 `§ 4` (a frame ID names its screen and its state) · R17 `§ 5` (layout derived from IDs; reflow is ordinary) · R18 `§ 5` (`assertPlacement()` is the single gate) · R19 `§ 6` (an archived one-part ID is correct) · R20 `§ 6` (a quoted config path is one the schema declares) · R21 `§ 4` (breakpoints share an ID) · R22 `§ 4` (two placement questions) · R23 `§ 4` (behaviour row = flow @ breakpoint) · R24 `§ 3` (declared variant axes, Brand) · R25 `§ 3`/`§ 5` (longest locale, loadable fonts) · R26 `§ 6` (implementation badge) · R27 `§ 6` (rebuild beside). -->

Reference for the [Visualize sub-step](../visualize-spec.prompt.md). Applies
whenever a spec's `## Design` links Figma frames, or when creating /
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
  | `80 Behaviour` | Step-by-step sequences of transitions whose order variants alone do not show (§ 4) |
  | `90 Explorations` | WIP / divergent options not yet agreed |
  | `99 Archive` | Superseded frames kept for history |
  | `─────────` | Divider page (empty, label only) separating groups |

- **Platform first, domain second.** The top axis is the platform (`Web` /
  `iOS` / `Android`). Only create a platform page you actually ship — **never
  an empty `iOS` page "for later"**. Inside a platform page, group product
  domains as Figma **Sections** (`Billing`, `Inventory`, …), not as more
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

### Variant axes — one declared vocabulary

**A file declares one variant-axis vocabulary, and every component set uses
only declared axes.** Left undeclared, the same two concepts drift into
`width=desktop`, `width=1024`, `size=desktop` and `status=hovered` across one
file, and neither a reader nor Code Connect can map them.

- **The declaration lives in `docs/architecture/design-system.md`** — a table
  of property names and their allowed values (`state` = `default` / `hover` /
  `focused` / `disabled`; `tone` = …). A component set that needs a new axis
  or value adds it there first.
- **A breakpoint-valued axis reuses the frame breakpoint names.** It is
  `breakpoint=base|md|lg`, exactly the § 4 suffixes in their declared order —
  never a width (`1024`), never a device word (`desktop`).
- **One concept, one property.** Interaction state is `state`, never also
  `status`; `status` is left free for data states a component displays.

### Brand — logos and media ratios in `01 Foundations`

- **`01 Foundations` holds a `Brand` section of logo component sets** — one set
  per mark, all sharing one axis vocabulary (e.g. `variant=full|mark`,
  `tone=color|mono|inverse`) declared like any other axis.
- **UI components instance the `Brand` sets rather than redraw them.** A header
  logo is an instance of `Logo`, not a second `icon/logo` drawing; the icon
  catalog never holds a brand mark.
- **Media aspect ratios are tokens, declared in `Brand`** (`ratio/hero` = 16:9,
  `ratio/card` = 4:3, …) — not implied by the size a frame happens to be drawn
  at, which drifts on resize exactly as a size in a name does (§ 4).

### Text slots survive the longest locale

**Every text-bearing component is verified with the longest shipped locale
string, without auto-layout overflow.** A slot sized against English truncates
or bursts its container in `uk` or `ru`. Before a text-bearing component is
handed over, set each text layer to the longest translation the product ships
for it (or, before translations exist, a string 40 % longer than English),
read back that no child exceeds its parent's bounds, then restore the default.

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
  inside that platform (`Billing`, `Inventory`, `Settings`, …). **Frame =
  screen** inside the section. Frame order and position are not chosen — they
  are derived from the frame's ID by the § 5 layout.
- Don't make one page per screen (sidebar explosion) and don't pile every
  domain onto a flat page — Sections carry the domain grouping.
- **Automation note — coordinates:** a Figma **Section's children use
  section-relative coordinates**, not absolute. When placing frames into a
  Section programmatically, set each child's `x`/`y` in *local* grid
  coordinates (e.g. `x = 60 + (i%2)*1540`, `y = 160 + ⌊i/2⌋*1000`); absolute
  values overflow the section bounds and the frames scatter off-canvas.
- **Automation note — no frame may burst its section.** Applies to **every**
  frame you add, move, or resize — not just one you grew. The frame must stay
  inside its host Section **and** the Section must not collide with its
  neighbours. Grow the host to fit, then verify with a read:
  `frameBox ⊆ sectionBox` for every child **and** no two Section boxes
  intersect (canvas coords). Skipping this is what produces frames sitting on
  top of a neighbouring section's screens.
- **Automation note — a frame's slot comes from its ID, not from where content
  currently ends.** `max(child.y + child.height)` answers "where does content
  end", which is neither "where does this frame belong" nor "where may I
  write" — the section can end sooner, and past its edge you are writing into
  the next section's canvas territory. The slot is computed by the § 5 layout
  (screen number picks the row, state number the column); the section is then
  grown to hold the result.

### Frame level — mandatory ID tag

Every root (screen) frame on a **product (platform) page** is named:

```
[<ID>] <Entity> — <View> · <state> · <bp>   <ID> = <platform>-<screen>.<state>
```

`· <bp>` is present in a responsive file and absent in a single-breakpoint one
(see *Breakpoints* below); `· <state>` is omitted on the default `.01`.

Applies to product pages only. `00 Cover`, `01 Foundations` and `02 Components`
hold no application screens and are organised by § 1 and § 3. `80 Behaviour`
uses the `[B-…]` grammar under *Behaviour sequences* below.

- **`[<ID>]`** — *required*, and **both numeric parts are required**:
  `[W-11.01]`, `[W-11.02]`, `[I-03.01]` (iOS), `[A-07.02]` (Android). Each part is zero-padded to two digits. A screen
  with exactly one state is `[W-11.01]`, never `[W-11]` — so a screen that
  gains a second state never has to rename its first.
- **`<screen>` is the screen's handle for life.** Allocate it once as
  `max(<screen>) + 1` across that platform, then never reuse a retired number
  and never renumber to close a gap. This is the half a spec cites and a
  reader scans.
  **One exception, and only at the migration that introduces this convention:**
  a file converting from per-frame numbering may compact its screen numbers onto
  `1…N` once, because the gaps it starts with are residue of a scheme that had no
  screens — not history under this one — and the version cut that freezes the old
  file has already absorbed the citation break. After that first pass the rule
  above is absolute. The invariant a compaction produces (`ceiling == screen
  count`) is **not** one to maintain: holding it past the next retired screen
  would renumber every screen above the hole, which is the citation breakage this
  rule exists to prevent. Publish the count where a reader looks for it instead.
- **`<state>` is allocated inside its own screen** as `max(<state>) + 1` among
  that screen's frames. Two screens allocate independently, so a well-covered
  screen with eight states costs **one** top-level number, not eight.
- **`.01` is the default state** — the screen as a person first meets it.
  Exactly one per screen.
- **`<Entity> — <View>`** — em dash. `View` ∈ List / Detail / Edit / Create /
  Empty / Loading / Error / Console / Landing. `Landing` is a route that is
  neither a list nor a record — a home page, an about page, a campaign page.
- **`· <state>`** — readable state suffix (`· Empty`, `· Validation error`),
  and it names what `.<state>` numbers. Prefer a **variant property** for
  state where the screen is a component.
- **Step / wizard:** `[W-07.01] <Flow> · Step N — <View>`. Each step is its
  own route, so each step is its own screen.
- **Never** encode size in the name (Figma stores dimensions — it drifts on
  resize); a breakpoint is a declared name (`· lg`), never a width (`· 1024`).
- Use the **product's user-facing vocabulary**; never embed `v2`/`FINAL`/dates.

**Breakpoints — one ID, one frame per breakpoint.** A responsive file draws a
screen at several widths. Those frames are the same screen in the same state,
so they share one ID and differ only in the trailing `· <bp>`.

- **The project declares the breakpoints.** Their names and their order, narrow
  to wide, live in the breakpoint table of `docs/architecture/design-system.md`.
  A name not in that table is not a breakpoint, and a responsive file's frame
  without a declared `· <bp>` fails assertion A.
- **One ID may have one frame per breakpoint** — never two frames with the same
  ID and the same breakpoint.
- **A state may omit breakpoints it does not have.** A map view that exists only
  on narrow and wide screens is drawn at those two. The default `.01` is the
  exception: every breakpoint a screen is drawn at has its own `.01`.
- **A single-breakpoint file declares none and writes no suffix.** A desktop-only
  admin UI keeps the names it has; nothing here renames it.

**Worked example — a responsive list.** `design-system.md` declares `base`,
`md`, `lg`. `Places — List` is screen `03`, drawn at all three; its map-view
state exists at `base` and `lg` only. The five frames, in row order left to
right, are:

```
[W-03.01] Places — List · base
[W-03.01] Places — List · md
[W-03.01] Places — List · lg
[W-03.02] Places — List · Map view · base
[W-03.02] Places — List · Map view · lg
```

They sit in **one** row, because they are one screen: the `.01` group at
`base`, `md`, `lg`, then the `.02` group at `base`, `lg` (§ 5 layout). Three `[W-03.01]` frames are
not three defaults — there is one `.01` per breakpoint, which is what
`assertPlacement()` checks.

**Screen or state? The route decides.** Apply this before allocating anything —
it is what makes both halves mechanical rather than a judgement call.

| The surface you are about to draw | Is | Allocation |
|---|---|---|
| The same route as an existing frame | a **state** of that screen | next `.<state>` in that screen |
| A modal, overlay, drawer or panel over that route | a **state** — it does not move the user | next `.<state>` in that screen |
| A different route | its **own screen** | `max(<screen>) + 1`, `.01` |
| No route at all — a report, an export preview, an email | its **own screen**; the screen is the thing a person navigates to | `max(<screen>) + 1`, `.01` |

**Worked example.** The file holds `[W-11.01] Ingestion · Step 1 — Console` and
`[W-11.02] Ingestion · Step 1 — Console · rate limited`. A "month exhausted"
state of that console is drawn next. It is the same route with a banner over
it, so it is a state of screen `11`, not a new screen; the highest state within
screen `11` is `.02`, so the next is `.03`. It is named
`[W-11.03] Ingestion · Step 1 — Console · month exhausted` — derived from the
file alone, with nothing else consulted.

Examples: `[W-01.01] Invoice — List`, `[W-02.02] Invoice — Edit · Validation
error`, `[W-11.01] Ingestion · Step 1 — Console`.

### Where a drawing goes — two questions

Screen-or-state settles allocation once a drawing is on a platform page. These
two questions settle which page it belongs on at all, and they are asked in
order.

1. **Is the surface reused on several pages?** A header, a filter, a card, a
   language selector — then it is a **component variant** in `02 Components`,
   and each screen that shows it holds an instance. It is not redrawn as a
   state of every screen it appears on.
2. **Is the change specific to one route?** An overlay, a banner, an empty
   list on that route — then it is a **screen state** on the platform page, by
   the table above.

Either answer may add a third home, never replace it: **a transition whose
order is not obvious from the variants is additionally a sequence on
`80 Behaviour`.** Variants say what states exist; the sequence says in which
order a person moves through them. A drawing that is neither a surface nor a
transition — a logo master, a colour ramp — is a foundation (§ 3).

**Worked examples.**

- *Header search filter, opening in nine steps.* It is in the header, on every
  page — question 1: variants of the `Search Filter` component set. Nine steps
  are not readable from the variant list — so it is also a `[B-01.01]` …
  `[B-01.09]` flow. It is never a `[W-…]` state.
- *Photo gallery overlay on a place page.* Only the place route has it —
  question 2: `[W-04.02] Place — Detail · Gallery`. Open and closed are the
  whole story, so there is no flow.
- *Six 512 px logo masters.* Not a surface a screen shows, not a transition —
  `Brand` component sets in `01 Foundations` (§ 3).

### Behaviour sequences — `80 Behaviour`

A behaviour frame is one step of a flow, named:

```
[B-<flow>.<step>] <Flow> · Step N — <change> · <bp>
```

- **`<flow>` is the flow's handle for life** — allocated `max(<flow>) + 1` on
  the page, never reused, the same as a screen number. `<step>` is `N`,
  zero-padded; the first step is `.01`.
- **Steps are numbered independently per breakpoint.** A filter that takes nine
  steps at `base` and four at `lg` is `[B-01.01…09] · base` and
  `[B-01.01…04] · lg`; the same step number at two breakpoints need not show the
  same change. In a single-breakpoint file `· <bp>` is omitted, as on a
  platform page.
- **Show only the page region the transition needs** — the header and the open
  panel, not the whole page beneath them.
- **Compose it from component instances.** A behaviour frame redraws nothing;
  a surface missing from `02 Components` is built there first.
- **Cite the screen state a step equals** with `→ W-xx.yy` at the end of
  `<change>`: `[B-02.02] Gallery · Step 2 — Overlay open → W-04.02 · base`.
- **Layout: a row is one flow at one breakpoint.** Rows run by flow number,
  then declared breakpoint order; steps run left to right in step order. The
  § 5 layout and `assertPlacement()` apply with that row key.

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

- **Every font family a file uses is loadable by the write runtime.** Check
  each family against `figma.listAvailableFontsAsync()` before the first
  write. A family the runtime cannot load — a local-only font such as
  `Helvetica Neue`, which fails with `font family does not exist` — makes every
  text node in it unwritable by an agent; name it at the gate as a **blocker
  for agent editing**. Replacing the family is the human's design decision;
  until it is made, the agent never skips the text or substitutes a font
  silently.
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
- **A section grows in whichever direction its IDs require, and the page
  reflows.** Sections are stacked vertically and all start at `x = 0`. A new
  state widens its screen's row; a new screen adds a row and makes the section
  taller, which pushes every section beneath it down by the page gutter. That
  push is ordinary rather than a migration — the layout below is recomputed,
  not patched — and the page-level grid check is what confirms it landed.

### Placement recipe — derive from the IDs, verify, then hand over

Placement is derived and asserted **in the same write call**, never eyeballed
and never confirmed only by a later screenshot. A screenshot shows one frame;
the assertion covers the whole page.

**A section's layout is a pure function of the frames it holds** — one row per
screen ordered by screen number, that screen's states left to right in state
order, packed left from the section origin with one column gutter and one row
gutter, each row as tall as its tallest frame. In a responsive file a state is
a **column group** rather than a column: its breakpoint frames run left to right
in the declared breakpoint order, and the next state's group follows. Nothing about it depends on the
order the frames were added, so it is never patched: **recompute the whole
section**, every time, and the result is the same layout a fresh run would
produce.

That makes reflow an ordinary act, not a migration. A new screen is a new row;
a new state is an insertion into its screen's row; both move their neighbours,
and moving them is the cheap half — children travel with their parents and node
IDs are untouched, so nothing that cites the file breaks. A run that adds one
frame therefore leaves the **whole** section conforming, and there is no such
thing as a section that is "due" a tidy-up.

```js
// 1. Recompute the section's layout from its IDs — screen = row, state = column
//    group, breakpoint = column inside the group
const GUTTER_X = 60, GUTTER_Y = 120, ORIGIN_X = 60, ORIGIN_Y = 160;
const BREAKPOINTS = ["base", "md", "lg"];     // design-system.md order; [] if single-breakpoint

const bpOf = name => {                        // "… · lg" -> 0-based rank, or -1
  const tail = name.split(" · ").pop();
  return BREAKPOINTS.indexOf(tail);
};
const parseId = n => {                        // "[W-11.03] … · lg" -> {screen, state, bp}
  const m = n.name.match(/^\[[A-Z]+-(\d{2})\.(\d{2})\]/);
  if (!m) throw new Error(`frame has no two-part ID: ${n.name}`);
  return { screen: +m[1], state: +m[2], bp: bpOf(n.name) };
};

// On 80 Behaviour `screen` is the flow and `state` the step, and a row is one
// flow at one breakpoint; on a platform page a row is one screen.
const BEHAVIOUR = figma.currentPage.name.endsWith("Behaviour");
const rowKey = ({ screen, bp }) => BEHAVIOUR ? screen * 100 + bp + 1 : screen;

const rows = new Map();                       // row key -> [{frame, state, bp}]
const live = n => !n.name.startsWith("[OLD]");   // § 6 rebuild — exempt until deleted
for (const f of section.children.filter(c => c.type === "FRAME" && live(c))) {
  const id = parseId(f), k = rowKey(id);
  if (!rows.has(k)) rows.set(k, []);
  rows.get(k).push({ f, state: id.state, bp: id.bp });
}

let y = ORIGIN_Y, widest = 0;
for (const k of [...rows.keys()].sort((a, b) => a - b)) {
  const row = rows.get(k).sort((a, b) => a.state - b.state || a.bp - b.bp);
  let x = ORIGIN_X;
  for (const { f } of row) { f.x = x; f.y = y; x += f.width + GUTTER_X; }
  widest = Math.max(widest, x - GUTTER_X);
  y += Math.max(...row.map(r => r.f.height)) + GUTTER_Y;   // row = tallest frame
}
section.resizeWithoutConstraints(widest + ORIGIN_X, y - GUTTER_Y + ORIGIN_Y);

// 2. Assert before returning — one routine, six assertions, throws on any
return assertPlacement();      // defined below; its return goes in the summary
```

### `assertPlacement()` — the single gate before hand-over

Six assertions used to be six paragraphs, and an assertion nobody is required
to run is an assertion that does not run. They are one named routine now. It
**throws** on the first failing set, naming the frame and which assertion it
failed; a `throw` rolls the whole `use_figma` write back (see the `throw` rule
above), so a violation never reaches the canvas. Its return value is what a
Visualize run reports at the gate.

| | Assertion |
|---|---|
| A | Every root frame carries a two-part ID (§ 4), and in a responsive file a declared `· <bp>` |
| B | Exactly one `.01` per screen per breakpoint, and no ID drawn twice at one breakpoint |
| C | A screen's frames share one row and run left to right in state order, then breakpoint order within a state, and no two screens share a row |
| D | Every child sits inside its host Section box |
| E | No two Section boxes intersect |
| F | Page grid — sections share one left edge and one gutter |

```js
function assertPlacement() {
  const fails = [], GUTTER = 300;
  const ID = /^\[([A-Z]+)-(\d{2})\.(\d{2})\]/;
  const BPS = BREAKPOINTS;                         // same declared list as the layout
  const BEH = figma.currentPage.name.endsWith("Behaviour");   // row = flow @ breakpoint
  const box = n => { const b = n.absoluteBoundingBox;
    return { x: b.x, y: b.y, x2: b.x + b.width, y2: b.y + b.height }; };
  const secs = figma.currentPage.children
    .filter(c => c.type === "SECTION" && !c.name.startsWith("[OLD]"))  // § 6 rebuild
    .sort((a, b) => a.y - b.y);

  for (const s of secs) {
    const rows = new Map();                                  // screen -> frames
    for (const f of s.children.filter(c => c.type === "FRAME" && !c.name.startsWith("[OLD]"))) {
      const m = f.name.match(ID);
      if (!m) { fails.push(`A id-pattern · ${s.name} · ${f.name}`); continue; }
      if ((m[1] === "B") !== BEH) { fails.push(`A id-page · ${s.name} · ${f.name}`); continue; }
      const bp = BPS.indexOf(f.name.split(" · ").pop());
      if (BPS.length && bp < 0) { fails.push(`A breakpoint · ${s.name} · ${f.name}`); continue; }
      const k = BEH ? `${m[2]} @ ${BPS[bp] ?? "-"}` : m[2];
      if (!rows.has(k)) rows.set(k, []);
      rows.get(k).push({ f, state: +m[3], bp });
    }
    for (const [screen, row] of rows) {                      // screen = flow @ bp on Behaviour
      for (const bp of new Set(row.map(r => r.bp))) {        // bp = -1 when single-breakpoint
        const at = row.filter(r => r.bp === bp), label = bp < 0 || BEH ? "" : ` @ ${BPS[bp]}`;
        const defaults = at.filter(r => r.state === 1).length;
        if (defaults !== 1)
          fails.push(`B one-default · ${s.name} · screen ${screen}${label} has ${defaults} .01 frames`);
        const states = at.map(r => r.state);
        if (new Set(states).size !== states.length)
          fails.push(`B duplicate · ${s.name} · screen ${screen}${label} draws a state twice`);
      }
      const ys = [...new Set(row.map(r => Math.round(r.f.y)))];
      if (ys.length !== 1)
        fails.push(`C one-row · ${s.name} · screen ${screen} spans y ${ys}`);
      const key = r => `${r.state}:${r.bp}`;
      const leftToRight = row.slice().sort((a, b) => a.f.x - b.f.x).map(key);
      const ordered = row.slice().sort((a, b) => a.state - b.state || a.bp - b.bp).map(key);
      if (String(leftToRight) !== String(ordered))
        fails.push(`C order · ${s.name} · screen ${screen} reads ${leftToRight}, want ${ordered}`);
    }
    const bands = [...rows.values()].map(r => Math.round(r[0].f.y));
    if (new Set(bands).size !== bands.length)
      fails.push(`C row-sharing · ${s.name} · two screens share a row`);

    const sb = box(s);
    for (const c of s.children.filter(c => !c.name.startsWith("[OLD]"))) { const b = box(c);
      if (b.x < sb.x || b.y < sb.y || b.x2 > sb.x2 || b.y2 > sb.y2)
        fails.push(`D containment · ${s.name} ⊅ ${c.name}`); }
  }

  for (let i = 0; i < secs.length; i++)
    for (let j = i + 1; j < secs.length; j++) {
      const A = box(secs[i]), B = box(secs[j]);
      if (A.x < B.x2 && B.x < A.x2 && A.y < B.y2 && B.y < A.y2)
        fails.push(`E overlap · ${secs[i].name} ∩ ${secs[j].name}`); }

  const lefts = [...new Set(secs.map(s => Math.round(s.x)))];
  if (lefts.length > 1) fails.push(`F grid-left · sections start at ${lefts}`);
  secs.slice(1).forEach((s, i) => {
    const gap = Math.round(s.y - (secs[i].y + secs[i].height));
    if (gap !== GUTTER)
      fails.push(`F grid-gutter · ${secs[i].name} → ${s.name} = ${gap}, want ${GUTTER}`); });

  if (fails.length) throw new Error("assertPlacement FAILED\n" + fails.join("\n"));
  return `assertPlacement OK — ${secs.length} section(s), ` +
         `${secs.reduce((n, s) => n + s.children.length, 0)} frame(s)`;
}
```

**A, B and C are why the section grid holds without an agent remembering it.**
The layout above produces a conforming section; these assert that what actually
landed is that layout, on the whole page rather than around the frame just
touched. **F fixes what it finds** rather than only reporting it — aligning
sections is a move, children travel with them, and node IDs are untouched, so
nothing that cites the file breaks. Re-run the routine after the fix.

**Assert inside the frame too, not only across sections.** `D` passes happily
while new content overlaps a sibling *within* a frame or overflows its bottom
edge. A run that rebuilds a frame's interior extends the same check to the
frame's children — every child inside `0,0 → main.width,height`, and each
absolutely-positioned child against each flow child.

**`x`/`y` are parent-relative, and a full-bleed wrapper changes the parent.**
A screen frame that holds a sidebar plus a `Main` wrapper has two coordinate
spaces, and a number read off a frame-relative dump lands offset by the
wrapper's origin when written to a child of `Main` — the node overflows the
screen frame by exactly the sidebar's width, which reads as a sizing bug and is
not one. Convert deliberately, or read the sibling you are aligning to and copy
**its** `x`.

**Read the parent's `layoutMode` before assigning `x`/`y`.** Appending to an
auto-layout parent puts the node in the flow and silently ignores your
coordinates — it lands stacked at the end instead of where you asked. Either
place it in the flow deliberately (`insertChild` at the right index) or set
`layoutPositioning = "ABSOLUTE"` first. Two traps follow from this: removing a
flow child **reflows every sibling below it**, so coordinates read before the
removal are stale; and `resize()` pins **both** axes, so a card that should
grow with its content needs `layoutSizingVertical = "HUG"` afterwards or it
stays at its literal height while the content spills out.

## 6. Spec embeds & file versioning

How a spec references Figma, and how a file key is retired. Companion to the
Visualize hard rules in [`visualize-spec.prompt.md`](../visualize-spec.prompt.md).

### Screenshot embeds — link-wrapped, never stored

Figma screenshot URLs are **short-lived by design**: `get_screenshot` returns
a short-lived URL, and `download_assets` states outright that URLs are
temporary. A bare `![alt](asset-url)` therefore rots into unrecoverable alt
text, and the frame it documented becomes unreachable from the rendered page.

Every frame in a spec's `## Design` is a **link-wrapped image**:

```markdown
[![[W-12.01] Invoice — List](https://www.figma.com/api/mcp/asset/<uuid>)](https://www.figma.com/design/<fileKey>?node-id=<node-id>)
```

- **Alt text = the frame's `[<ID>] <Entity> — <View> · <state>` name** (§ 4).
  An expired image then still renders as a named screen, and it stays
  clickable — the reader loses the picture, never the reference.
- **Outer URL = the node link.** It carries `fileKey` + `node-id`, which is
  exactly what `get_screenshot` needs, so a spec regenerates its own images
  with no metadata stored anywhere else.
- **Never store the image.** No exported PNG/WebP committed to a repository,
  no upload to object storage or a CDN. The image is *regenerable*, not
  archived — that is what makes storing it unnecessary.
- **Regenerate at the gate.** Before a spec goes to the requirements gate, and
  whenever a spec with dead images is re-opened, re-run `get_screenshot` for
  every node URL under `## Design` and replace the image URLs in place.
  Freshness is a property of the process, not of the moment a frame was drawn.

### Source of truth — code-first or design-first

A project declares its mode in `docs/architecture/design-system.md`, and the
mode decides what a frame that differs from the product means.

- **Code-first** — the product leads and the file documents it. A frame that
  differs from the product is a defect; the next subsection applies whole, and
  frames carry no implementation badge.
- **Design-first** — the design leads and the code follows, so a frame ahead
  of the product is the normal state, not a divergence. What must never be
  unclear is *which* frames are ahead.

**A design-first file marks every root frame on platform and behaviour pages
with a `status/implementation` instance.** The badge is a component in
`02 Components` with one `status` axis and a spec-ID text property, placed
above the frame's top-left corner inside the section:

| `status` | Meaning | Spec ID |
|---|---|---|
| `Implemented` | The product matches the frame | the spec that shipped it |
| `Designed` | Drawn, not yet built | the spec that will build it, or `—` |
| `Changed` | Built, then redrawn; the product still shows the earlier design | the spec that redrew it |

- **`00 Cover` summarises it per screen** — one line per screen ID with its
  count per status (`W-03 · 3 Implemented · 2 Designed`), regenerated whenever
  a badge flips.
- **The badge flips at spec closure**, by the rule in `spec-lifecycle.md`; a
  frame whose spec closed and still reads `Designed` is a divergence, and the
  next subsection applies to it.
- **Code-first files omit the badge and the Cover summary.**

### The current file carries no divergence

The current file is the live design, not a gallery of what things used to look
like. Freezing is what preserves a "before"; a stale frame left in the current
file preserves nothing and misinforms every reader who opens it. In a
design-first file, a frame badged `Designed` or `Changed` is ahead of the
product by declaration and is not a divergence; a badge that misstates the
product is.

- **A frame that contradicts today's product is a defect, and fixing it is part
  of the run that found it.** Not a follow-up, not a note in the spec. This
  includes a frame naming a configuration key that no longer exists, a unit
  that was renamed, a field that was removed, or a value the current
  configuration contradicts.
- **Correcting the base frame and drawing the proposal are two different acts.**
  While the spec is unapproved, the base frame gets **today's truth** — what the
  product does now — and the proposed state goes in its own `· <state>` frames.
  Never write an unapproved proposal into the base frame.
- **At closure, the base frame gets what landed.** The state variants stay as
  variants. A spec that changed a surface and left the base frame showing the
  pre-change design has not finished its documentation.
- **The checkable half — a dotted configuration path in a frame is one the
  project's settings schema declares.** The rest of this subsection needs a
  reader who knows the product; this one does not. It is a set-membership test
  against a file that is in the repository, so it can be run rather than
  reviewed. A project names its schema source in
  `docs/architecture/design-system.md`, beside its file-key version table — one
  declaration site, as with the keys themselves. The check is wired **per
  project**, because only the project has the schema; the framework states the
  rule and where the source is named. A quoted path the schema does not declare
  is a divergence, and the first rule above applies to it: corrected in the run
  that found it.
- **"Archived specs link to it" is not a reason to leave it stale.** Archived
  specs resolve against **frozen** keys, which is the entire point of the
  rotation scheme below — their links are correct by construction, and nothing
  about them constrains the current file. An agent that reaches for this
  argument has mistaken the scheme for its opposite.

### File versioning — freeze, never rewrite

A node link resolves against a **live** file: the design it shows keeps
changing after the spec closes. Cutting a copy is what makes a closed spec's
links truthful again.

- **The copy is the successor, not the archive.** Duplicate the current file,
  continue work in the duplicate, leave the predecessor untouched. The reverse
  — copying as an archive and continuing in the original — forces retro-edits
  of keys in closed specs. Never do it.
- **Ask every run.** Before its first read of the project's declared key, the
  Visualize sub-step asks whether to continue with the current file or adopt a
  new one; the default is continue. The question fires on **every** run
  because only the human knows a milestone has been cut.
- **Rotate before any further call.** A supplied key updates the version table
  first; the rest of the run then reads and writes that key alone.
- **One declaration site.** Every key the project **owns** — current and
  superseded — lives in its `docs/architecture/design-system.md` version
  table. A key belongs to exactly one project: another project's file that
  this repo only reads is a **citation, not a declaration**, and stays with
  the fact that cites it.

  | File key | Version | Status | Frozen on |
  |---|---|---|---|
  | `<key>` | v0.2 | current | — |
  | `<key>` | v0.1 | frozen | 2026-08-20 |

  No other live doc repeats a key; prose elsewhere points at the table.
- **Freezing is an act, not a label.** Rename the predecessor
  `… v0.1 · frozen`, move it to the archive project, and update its
  `00 Cover` status. A file nobody actually froze keeps drifting, and the
  whole scheme buys nothing.
- **Never retro-edit archived specs.** They keep the key they were designed
  against; that key is now frozen, so their links are correct by construction.
- **An archived spec's one-part frame ID is correct, not stale.** After a
  project migrates to the two-part scheme (§ 4), an archived spec citing
  `[W-59]` sits beside a live `[W-11.03]`. That is the expected result, not a
  defect: the archived spec resolves against a **frozen** key, and in that file
  the frame is still named `[W-59]`. Nothing is out of sync, no rule anywhere
  asks for a reconciliation, and an archived spec's IDs are never "corrected".

### Rebuild beside, never rename in place

Renaming a file that is far from the convention into shape — frame by frame,
section by section — leaves it half-conforming for the whole run and loses the
"before" as it goes. When a file is rebuilt rather than extended:

- **The originals stay beside the rebuild, renamed `[OLD] <name>`.** An
  `[OLD]` frame, section or page is exempt from the taxonomy, the ID grammar
  and `assertPlacement()` until it is deleted; nothing new is ever named
  `[OLD]`.
- **The spec's `## Design` shows each screen before and after** — the `[OLD]`
  frame beside its rebuilt `[W-…]` frame, both as link-wrapped images.
- **`[OLD]` content is deleted only after the human confirms** the rebuild at
  the gate, never by the run that built it.
- **Rebuilt frames get new node IDs.** A citation of an original's node resolves
  through the frozen key (*File versioning* above) — freeze the file before the
  rebuild starts, and a closed spec's links stay correct by construction.

### Caveats

- **Node IDs survive duplication** — a spec written against `node-id=51:2`
  finds the same node in the successor file. Verify once per rotation: the
  scheme depends on it.
- **A subscribed library still drifts.** Once the design system is promoted to
  a separate published library (§ 3), freezing the product file does not
  freeze what it renders — the library keeps publishing into it. Freeze the
  pair, or accept the drift knowingly.
- **The Figma plan caps files per team.** A copy-per-milestone cadence spends
  that budget. Check the ceiling before committing to a rotation rhythm.

## 7. Quick checklist (Visualize sub-step)

- [ ] Pages follow one numeric + Title Case taxonomy; ≤ ~9 top-level pages.
- [ ] Platform is the top axis (`10 Web`/`20 iOS`/…); no empty platform pages;
      domains are **Sections**, not pages.
- [ ] Every root frame on a product page named `[<ID>] <Entity> — <View> ·
      <state>` with `<ID>` a two-part `<platform>-<screen>.<state>` (§ 4) —
      both halves present, `.01` on a single-state screen, exactly one `.01`
      per screen; size never in the name.
- [ ] Responsive file: every product frame ends in a breakpoint declared in
      `design-system.md`; one ID per breakpoint; a state's breakpoint frames
      left to right in declared order (§ 4, § 5).
- [ ] Each drawing placed by the two questions — reused surface → component
      variant, one-route change → screen state, non-obvious order → also a
      `[B-<flow>.<step>]` flow on `80 Behaviour`, one row per flow per
      breakpoint, built from instances (§ 4).
- [ ] Component sets use only the declared variant axes; logos live as
      `Brand` component sets in `01 Foundations`; media ratios are tokens (§ 3).
- [ ] Text-bearing components verified with the longest shipped locale; every
      font family loadable by `listAvailableFontsAsync`, or named as a blocker
      (§ 3, § 5).
- [ ] Design-first file: every root frame on platform and behaviour pages
      badged `Implemented` / `Designed` / `Changed` with a spec ID, and
      `00 Cover` summary current (§ 6).
- [ ] Rebuild: originals renamed `[OLD]`, before/after in `## Design`, deleted
      only after human confirmation (§ 6).
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
- [ ] Every frame added, moved, or resized asserted in-script: every child
      inside its host Section box, no two Section boxes intersecting. Placement
      is never chosen: the host section's layout is recomputed whole from its
      IDs (§ 5) — one row per screen in screen order, that screen's states left
      to right in state order — and the section grown to the result.
- [ ] `assertPlacement()` (§ 5) called before hand-over and its return recorded:
      two-part IDs, one `.01` per screen per breakpoint, each screen's frames in one
      row ordered by state then breakpoint,
      child containment, no section overlap, one left edge and one gutter for
      every section — grid defects corrected in the same run, then re-asserted.
- [ ] Every Figma frame in `## Design` is a link-wrapped image whose alt text
      is the frame's `[<ID>] <Entity> — <View> · <state>` name; no screenshot
      file committed to a repository or uploaded to external storage.
- [ ] No frame in the current file contradicts today's product — a base frame
      found stale is corrected in the same run, separately from any proposed
      state drawn beside it.
- [ ] Every dotted configuration path quoted in a frame is one the project's
      settings schema declares (schema source named in the project's
      `design-system.md`; the check itself is wired per project).
- [ ] Screenshots regenerated immediately before the requirements gate.
- [ ] The file-key question asked before the first Figma read; any new key
      rotated into the version table before any further Figma call.
- [ ] A superseded file renamed `· frozen`, moved to the archive project, and
      its `00 Cover` status updated.
- [ ] No archived spec's frame IDs rewritten to the two-part form — they resolve
      against a frozen key and are correct as written.
