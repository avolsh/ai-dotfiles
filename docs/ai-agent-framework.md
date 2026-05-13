# AI Agent Framework — Overview

*Last updated: 2026-05-12*

This repo implements an **AI Agent Framework** — a set of conventions,
skills, and guardrails that let AI coding agents (GitHub Copilot, Claude
Code, OpenAI Codex CLI) work safely and consistently across multiple
projects.

---

## What it does

The framework solves three problems:

1. **Consistency** — Every change, in every project, follows the same
   spec-driven workflow with human approval gates.
2. **Context** — Agents know what to read, in what order, so they don't
   waste time guessing or scanning the codebase.
3. **Safety** — Hard rules prevent agents from skipping steps, committing
   secrets, or building features nobody asked for.

## How it's organized

```
ai-dotfiles/
├── framework/
│   ├── boundaries.md              ← Rules: always do / ask first / never do
│   ├── spec-workflows/            ← The spec lifecycle (stages, templates, questions)
│   ├── skills/                    ← Reusable knowledge modules
│   ├── prompts/                   ← Workflow triggers ("create CR", "plan", etc.)
│   └── templates/                 ← Bootstrap templates
│       ├── system/                ← Per-tool system templates (rendered by ai-profile-init)
│       ├── workspace/             ← Workspace scaffold templates (used by ai-workspace)
│       └── project/               ← Project scaffold templates (used by ai-project)
├── profiles/
│   └── personal/                  ← Identity-level prefs + pre-built tool subdirs
│       ├── profile.env
│       ├── preferences.md
│       ├── claude/                ← Pre-built — CLAUDE_CONFIG_DIR target
│       ├── copilot/               ← Pre-built — COPILOT_HOME target
│       └── codex/                 ← Pre-built — CODEX_HOME target
├── scripts/
│   ├── ai-switch.sh               ← Exports CLAUDE_CONFIG_DIR/COPILOT_HOME/CODEX_HOME
│   └── ai-profile-init.sh         ← Renders profile tool subdirs (one-time per profile)
├── docs/
│   ├── ai-agent-framework.md      ← This document
│   └── spec-workflow-guide.md     ← Four-status lifecycle walkthrough
└── README.md                      ← Getting Started + setup guide

Each project repo:
├── .github/copilot-instructions.md  ← Project rules (references <system>/... for framework)
├── AGENTS.md                         ← Generated copy (Codex), no @-imports
├── CLAUDE.md                         ← @-import (Claude Code)
├── .github/scripts/sync-agents.sh    ← Project-local regeneration script
└── docs/specs/active/                ← In-flight specs
```

## Multi-agent support

Each agent reads a different file but the content is the same:

| Agent | Reads | Mechanism |
|---|---|---|
| **GitHub Copilot** | `.github/copilot-instructions.md` | Auto-discovery |
| **Claude Code** | `CLAUDE.md` | Resolves `@.github/copilot-instructions.md` recursively |
| **OpenAI Codex CLI** | `AGENTS.md` | Mechanical copy (no `@`-import support) |

Drift between sources is prevented at the project level by
`make sync-agents` (which invokes `.github/scripts/sync-agents.sh`).
Edit `.github/copilot-instructions.md`, run `make sync-agents`, never
edit `AGENTS.md` by hand.

## Two-scope model

Everything exists at two levels. **Project rules win** when they conflict
with system rules.

| Scope | What it covers | Location |
|---|---|---|
| **System** | Framework skills, prompts, spec templates, boundaries — pre-built per profile, addressed via `CLAUDE_CONFIG_DIR` / `COPILOT_HOME` / `CODEX_HOME` | `profiles/<profile>/{claude,copilot,codex}/` |
| **Project** | Tech-stack rules, project skills, coding conventions | `.github/copilot/` inside each project |

## Skills — what the AI knows

Skills are on-demand knowledge modules. The AI loads them when needed,
not all at once.

| Skill | What it teaches the AI |
|---|---|
| **agent-protocol** | How to load context, run checklists, format output |
| **writing-specs** | How to write specs, ask questions, plan tasks |
| **model-selection** | Which AI model tier (fast/default/deep) to use per task |
| **bootstrapping-project** | How to set up a new project with the framework |
| **writing-docs** | Doc conventions, glossary format, freshness rules |

Projects can add their own skills (e.g., `testing-with-jest`,
`building-ddd-contexts`, `running-pipeline-steps`).

## Boundaries — what the AI must NOT do

Three tiers of rules, from gentle to absolute:

| Tier | Examples |
|---|---|
| **Always do** | Run tests before committing, post preflight proof, log improvements |
| **Ask first** | Adding bounded contexts, changing AI prompts, modifying framework files |
| **Never do** | Commit secrets, skip Specify stage, mix refactoring with features, gold-plate |

Full list: [`framework/boundaries.md`](../framework/boundaries.md).

## The spec workflow

All work follows four statuses with human gates between each, then a
final directory move on completion:

```
specify → plan → in-progress → done   →   docs/specs/archived/
```

The four statuses are tracked in the spec front-matter; `archived/` is a
**directory move**, not a separate status. See
[Spec Workflow Guide](spec-workflow-guide.md) for the full walkthrough
with diagrams.

## Process improvements

Every project keeps a `docs/improvements-log.md`. When the AI (or you)
notices a gap, friction, or better approach — it gets logged immediately.
This ensures the framework gets better over time rather than accumulating
hidden debt.

## Sync workflow (developer cheat sheet)

| Action | Command |
|---|---|
| Initialize / re-initialize a profile's tool subdirs | `ai-profile-init <profile>` |
| Switch active profile | `ai <profile>` (e.g., `ai personal`) |
| Regenerate project `AGENTS.md` after editing `copilot-instructions.md` | `make sync-agents` (per project) |
| Verify no drift (used by CI) | `make sync-agents-check` |

## Key principles

1. **Human gates** — The AI never proceeds without your approval.
2. **One task at a time** — No multi-task autopilot. "Continue" = next
   single task only.
3. **Specs before code** — No coding until the spec is approved. This
   catches 80% of mistakes before a line is written.
4. **Autonomous specs** — Work that can be logically separated and
   tested independently becomes separate specs. The Specify stage
   always runs a Split check before the gate.
5. **Tests with features** — Every task includes its own tests. No
   "I'll add tests later."
6. **Living documents** — Specs, module maps, and docs are updated in
   place as work happens — not after.
