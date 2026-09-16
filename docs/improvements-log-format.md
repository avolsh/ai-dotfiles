# Improvements Log — Format

*Last updated: 2026-09-16*

Authoring format and timing rule shared by `docs/improvements-log.md`
files at both project and workspace scopes. Each scope's log file is a
thin shell carrying only its scoping intro and a pointer back here.

---

## How to add an entry

When you discover an improvement during a task, append a new entry at
the **bottom** of the relevant `docs/improvements-log.md` using the
template below. Do **not** edit past entries; add a follow-up entry if
needed.

**Timing rule (mandatory):** log improvements **immediately when
discovered**. Do not defer logging until the end of the task, after
tests, or after review.

### Entry template

```markdown
### YYYY-MM-DD — <short title>

- **Spec / task:** CR/BUG/IMP id + task number, "Direct lane (…)", or "ad-hoc"
- **Closed:** YYYY-MM-DD
- **Category:** `protocol` | `skill` | `pattern` | `anti-pattern` | `tooling`
- **What was found:** one paragraph describing the problem or friction
- **What was changed:** file(s) updated and summary of the change, or "none — logged for review"
- **Suggested follow-up:** optional next action or owner
```

**`Closed`** is the date the change landed. It is required on a
Direct-lane entry — one whose `Spec / task` line says `Direct lane` —
dated on or after 2026-09-16; `make validate-specs` reports
`log_closed_missing` otherwise. On any other entry it is optional. Past entries are not back-filled.

## Which log to write to

- **Project scope** — issues specific to one project go in that
  project's `docs/improvements-log.md`.
- **Workspace scope** — issues that span multiple projects or apply at
  the workspace layer go in the workspace `docs/improvements-log.md`.
