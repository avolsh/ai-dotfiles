# Figma file organization — naming & structure conventions

*Last updated: 2026-09-02*

<!-- Anchors in this file (per `docs/rule-canonical-map.md`): R16 `§ 4` (a frame ID names its screen and its state) · R17 `§ 5` (layout derived from IDs; reflow is ordinary) · R18 `§ 5` (`assertPlacement()` is the single gate) · R19 `§ 6` (an archived one-part ID is correct) · R20 `§ 6` (a quoted config path is one the schema declares). -->

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
  | `80 Behaviour` | Complex transitions / prototype flows / navigation maps |
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
[<ID>] <Entity> — <View> · <state>          <ID> = <platform>-<screen>.<state>
```

Applies to product pages only. `00 Cover`, `01 Foundations` and `02 Components`
hold no application screens and are organised by § 1 and § 3.

- **`[<ID>]`** — *required*, and **both numeric parts are required**:
  `[W-11.01]`, `[W-11.02]`, `[I-03.01]` (iOS), `[A-07.02]` (Android),
  `[B-02.01]` (Behaviour). Each part is zero-padded to two digits. A screen
  with exactly one state is `[W-11.01]`, never `[W-11]` — so a screen that
  gains a second state never has to rename its first.
- **`<screen>` is the screen's handle for life.** Allocate it once as
  `max(<screen>) + 1` across that platform, then never reuse a retired number
  and never renumber to close a gap. This is the half a spec cites and a
  reader scans.
- **`<state>` is allocated inside its own screen** as `max(<state>) + 1` among
  that screen's frames. Two screens allocate independently, so a well-covered
  screen with eight states costs **one** top-level number, not eight.
- **`.01` is the default state** — the screen as a person first meets it.
  Exactly one per screen.
- **`<Entity> — <View>`** — em dash. `View` ∈ List / Detail / Edit / Create /
  Empty / Loading / Error / Console.
- **`· <state>`** — readable state suffix (`· Empty`, `· Validation error`),
  and it names what `.<state>` numbers. Prefer a **variant property** for
  state where the screen is a component.
- **Step / wizard:** `[W-07.01] <Flow> · Step N — <View>`. Each step is its
  own route, so each step is its own screen.
- **Never** encode size in the name (Figma stores dimensions — it drifts on
  resize); breakpoints, if needed, are a `· sm/md/lg` suffix, not digits.
- Use the **product's user-facing vocabulary**; never embed `v2`/`FINAL`/dates.

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
gutter, each row as tall as its tallest frame. Nothing about it depends on the
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
const GUTTER_X = 60, GUTTER_Y = 120, ORIGIN_X = 60, ORIGIN_Y = 160;

const parseId = n => {                        // "[W-11.03] …" -> {screen, state}
  const m = n.name.match(/^\[[A-Z]+-(\d{2})\.(\d{2})\]/);
  if (!m) throw new Error(`frame has no two-part ID: ${n.name}`);
  return { screen: +m[1], state: +m[2] };
};

const rows = new Map();                       // screen -> [{frame, state}]
for (const f of section.children.filter(c => c.type === "FRAME")) {
  const { screen, state } = parseId(f);
  if (!rows.has(screen)) rows.set(screen, []);
  rows.get(screen).push({ f, state });
}

let y = ORIGIN_Y, widest = 0;
for (const screen of [...rows.keys()].sort((a, b) => a - b)) {
  const row = rows.get(screen).sort((a, b) => a.state - b.state);
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
| A | Every root frame carries a two-part ID (§ 4) |
| B | Exactly one `.01` per screen |
| C | A screen's states share one row and run left to right in state order, and no two screens share a row |
| D | Every child sits inside its host Section box |
| E | No two Section boxes intersect |
| F | Page grid — sections share one left edge and one gutter |

```js
function assertPlacement() {
  const fails = [], GUTTER = 300;
  const ID = /^\[[A-Z]+-(\d{2})\.(\d{2})\]/;
  const box = n => { const b = n.absoluteBoundingBox;
    return { x: b.x, y: b.y, x2: b.x + b.width, y2: b.y + b.height }; };
  const secs = figma.currentPage.children
    .filter(c => c.type === "SECTION").sort((a, b) => a.y - b.y);

  for (const s of secs) {
    const rows = new Map();                                  // screen -> frames
    for (const f of s.children.filter(c => c.type === "FRAME")) {
      const m = f.name.match(ID);
      if (!m) { fails.push(`A id-pattern · ${s.name} · ${f.name}`); continue; }
      if (!rows.has(+m[1])) rows.set(+m[1], []);
      rows.get(+m[1]).push({ f, state: +m[2] });
    }
    for (const [screen, row] of rows) {
      const defaults = row.filter(r => r.state === 1).length;
      if (defaults !== 1)
        fails.push(`B one-default · ${s.name} · screen ${screen} has ${defaults} .01 frames`);
      const ys = [...new Set(row.map(r => Math.round(r.f.y)))];
      if (ys.length !== 1)
        fails.push(`C one-row · ${s.name} · screen ${screen} spans y ${ys}`);
      const leftToRight = row.slice().sort((a, b) => a.f.x - b.f.x).map(r => r.state);
      const ordered = row.map(r => r.state).sort((a, b) => a - b);
      if (String(leftToRight) !== String(ordered))
        fails.push(`C state-order · ${s.name} · screen ${screen} reads ${leftToRight}`);
    }
    const bands = [...rows.values()].map(r => Math.round(r[0].f.y));
    if (new Set(bands).size !== bands.length)
      fails.push(`C row-sharing · ${s.name} · two screens share a row`);

    const sb = box(s);
    for (const c of s.children) { const b = box(c);
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

### The current file carries no divergence

The current file is the live design, not a gallery of what things used to look
like. Freezing is what preserves a "before"; a stale frame left in the current
file preserves nothing and misinforms every reader who opens it.

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
      two-part IDs, one `.01` per screen, each screen's states in one ordered row,
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
