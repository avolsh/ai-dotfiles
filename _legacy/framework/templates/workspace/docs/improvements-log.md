# Workspace Improvements Log

*Last updated: YYYY-MM-DD*

Workspace-wide log of process improvements, protocol gaps, anti-patterns,
and cross-project conventions discovered during coding sessions. Project-scope
findings live in each project's own `docs/improvements-log.md`; this log is
for things that apply across multiple projects in the workspace.

**Purpose:** surface recurring friction at the workspace layer, close gaps
before they repeat across projects, and inform future framework updates.

---

## How to add an entry

When you discover a workspace-level improvement during a task, append a
new entry at the **bottom** of this file using the template below. Do
**not** edit past entries; add a follow-up entry if needed.

**Timing rule (mandatory):** log improvements **immediately when discovered**.
Do not defer logging until the end of the task, after tests, or after review.

```markdown
### YYYY-MM-DD — <short title>

- **Spec / task:** CR/BUG/IMP id + task number, or "ad-hoc"
- **Category:** `protocol` | `skill` | `pattern` | `anti-pattern` | `tooling`
- **What was found:** one paragraph describing the problem or friction
- **What was changed:** file(s) updated and summary of the change, or "none — logged for review"
- **Suggested follow-up:** optional next action or owner
```

---

## Log

<!-- Append new entries below this line, newest at the bottom. -->
