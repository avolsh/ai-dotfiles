# ADR-0002: figma-file-versioning-and-screenshot-durability

- Date: 2026-08-20
- Status: accepted

## Context

[ADR-0001](ADR-0001-figma-file-organization-conventions.md) settled how a
Figma file is *organized*, but not how a spec *cites* one. The Visualize
sub-step instructed the agent to "link the frames (file key + node IDs) and
embed screenshots", which in practice produced a bare
`![Frame name](https://www.figma.com/api/mcp/asset/<uuid>)`.

Two independent defects followed.

**Screenshot URLs are short-lived by design.** `get_screenshot` returns a
short-lived URL and `download_assets` states outright that URLs are temporary.
Evidence at the time of this decision: **49 such image links across 12
archived `tobevisit-content` specs**, every sampled one returning
`404 {"error":true,"status":404}`. Because the markup was a bare image with
the node link on a separate line as inline code, a dead URL rendered as
unrecoverable alt text — nothing in the rendered document could be clicked or
regenerated.

**Node links resolve against a live file.** A project declares one file key;
the file behind it keeps changing after a spec closes. Closed specs therefore
illustrated their design with whatever the file looked like *later*, while the
existing rule (correctly) forbids retro-editing keys inside archived specs.

## Decision

Adopt two coupled rules, owned by the framework and enforced at Visualize:

- **Reference doc:** `framework/prompts/references/figma-file-organization.md`
  § 6 (format, versioning + freeze procedure, caveats).
- **Enforcement:** a `Screenshot embeds (Figma)` hard rule plus the
  `Confirm the Figma file` step in `framework/prompts/visualize-spec.prompt.md`.
- **Scaffold:** `templates/project/docs/architecture/design-system.md` ships
  the version table so a new project inherits the declaration site.

The rules themselves:

- **Link-wrapped image.** Every frame under `## Design` is an image wrapped in
  its node link, with the frame's `[<ID>] <Entity> — <View> · <state>` name as
  alt text. An expired URL degrades into a named, clickable reference instead
  of dead text — and the outer link carries `fileKey` + `node-id`, exactly the
  input needed to rebuild the image.
- **No stored images.** Screenshots are never committed to a repository and
  never uploaded to object storage or a CDN. The image is *regenerable*, which
  is what makes archiving it unnecessary.
- **Regenerate at the gate.** Before the requirements gate, and whenever a spec
  with dead images is re-opened, every image URL under `## Design` is re-run
  through `get_screenshot` and replaced in place. Freshness becomes a property
  of the process rather than of the moment the frame was drawn.
- **Freeze-on-version.** The copy is the **successor**, not the archive: work
  moves to the duplicate, the predecessor is frozen (renamed `· frozen`, moved
  to the archive project, `00 Cover` status updated). Closed specs keep their
  key, which now points at an immutable file.
- **Ask every run.** Before its first Figma read, Visualize asks whether to
  continue with the declared key or adopt a new one, defaulting to continue.
- **One declaration site.** Every key — current and superseded — lives in the
  project's `docs/architecture/design-system.md` version table; prose elsewhere
  points at it.

## Alternatives Considered

- **Commit an exported PNG/WebP next to the spec** — rejected by the owner.
  It is the only option that renders offline and in diffs, and freezing
  removes its staleness objection, but it puts binaries in the repository to
  archive content that is regenerable from the node link.
- **Upload screenshots to R2 or a CDN** — rejected: adds a publish step and a
  second place that can rot; durability would depend on bucket lifecycle
  rather than on Figma.
- **`figma.com/embed` iframe** — rejected: does not render in Markdown on
  GitHub or in editors, and requires the reader to be logged in with file
  access.
- **Keep the bare image and accept decay** — rejected: this is the status quo
  that produced 49 unrecoverable links.
- **Cut the copy as an archive of the old state and keep working in the
  original** — rejected: it forces retro-editing keys inside closed specs,
  contradicting the immutability of archived specs. The direction of the copy
  is the whole decision.
- **Ask about the file only at milestone boundaries, or auto-detect them** —
  rejected: only the human knows a milestone was cut. The question is one
  keystroke with a safe default, so asking every run costs less than a missed
  rotation.
- **Repair the 49 dead links in archived specs** — rejected by the owner:
  archived specs are immutable post-closure.

## Consequences

- A spec shows pictures when it was recently regenerated, and named clickable
  links otherwise. This is the accepted trade for storing nothing: the
  reviewer at the gate always sees images, a reader months later always sees
  working references.
- The Visualize sub-step gained a mandatory human interaction. A run against a
  project that declares no key yet skips it.
- **Known limitation:** the Figma plan caps files per team, and this was not
  verified when the decision was taken. A copy-per-milestone cadence spends
  that budget; check the ceiling before committing to a rhythm.
- **Known limitation:** once a design system is promoted to a separate
  published library, freezing the product file does not freeze what it
  renders — the library keeps publishing into it.
- **Depends on a Figma behaviour:** node IDs survive file duplication, which
  is what lets a closed spec's `node-id` resolve inside the successor file.
  Verify once per rotation.
- **Tooling gap surfaced:** `scripts/validate-specs.py` `check_link_integrity`
  matches links without skipping code spans or fenced blocks, so documenting
  this format inside a spec requires writing the example with `https://`-shaped
  placeholders (external prefixes are skipped). Tracked separately.
- Examples in the reference doc and the Visualize prompt were also returned to
  project-agnostic vocabulary, restoring the ADR-0001 consequence that the
  reference doc carries generic examples only.
