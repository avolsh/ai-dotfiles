# Agent Protocol — Reference

*Last updated: 2026-04-09*

On-demand reference material. Load only when the relevant scenario applies.
See `.github/copilot/skills/agent-protocol/SKILL.md` for the core protocol.

## Determinism and traceability

- **Batch size:** configurable per operation via project-specific configuration
  (see project `AGENTS.md`).
- **Evaluation:** each item independently -- no cross-item influence.
- **Ordering:** stable sort by canonical ID before batching.
- **Traceability:** every AI-generated result must record:
  - `model` -- AI model name
  - `classifiedAt` -- ISO 8601 timestamp
  - `batchId`
  - `promptVersion` -- semver tag from prompt version constant

## Schema-code sync

- Reference schemas in `docs/reference/` are the **specification**.
- Source-code type definitions must conform to reference schemas.
- When an agent modifies a type definition, it MUST update the corresponding reference doc.
- When a human updates a reference schema, the corresponding spec must include code updates.

## Document freshness

- Every doc SHOULD include a `*Last updated: YYYY-MM-DD*` line after the title.
- Agents SHOULD flag docs that reference non-existent files or code paths.
- During spec implementation, agents MUST update the `Last updated` date on every modified doc.
- Docs not updated for 6+ months should be reviewed for staleness.

## Skills audit

The skills audit is a **separate on-demand task**, not part of automatic
bootstrap. Run it when the user explicitly requests it or as a setup task.

The agent verifies that system-scope and project-scope skills cover the
workspace's **high-leverage workflows**, using the **local submodule** at
`<system>/upstream/claude-skills/` as the reference catalog.

**Procedure:**

1. **Inventory existing system skills** --
   Read `.github/copilot/skills/` and list all skill folders.

2. **Inventory high-leverage workflows** --
   From workspace root files, project AGENTS docs, and active production code:
   list workflows that are recurring, non-obvious, error-prone, or
   expensive to rediscover.

3. **Gap analysis** --
   For each workflow, check:
   - Is there a concise always-on instruction already covering it?
   - Is there a system-scope skill covering it?
   - Is there a project-scope skill covering it?
   - If neither, would a skill materially reduce repeated mistakes?

4. **Check upstream skill catalog (local submodule)** --
   Read `<system>/upstream/claude-skills/` directory tree.
   For each justified gap, check if a matching skill exists upstream.
   If found: recommend merge/vendor/defer/do-not-vendor.
   If not found: log the gap for manual skill creation.

5. **Report** --
   Present to human:
   - Skills already present (system + project)
   - High-leverage gaps found
   - Candidate upstream matches
   - Recommendation per candidate
   - Gaps remaining (need manual authoring)
   - No files changed during the audit
