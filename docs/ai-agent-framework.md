# AI Agent Framework — Overview

*Last updated: 2026-06-14*

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
│   ├── ai-switch.sh               ← Switches active profile, persists env, links shared state
│   ├── lib/profile-links.sh       ← Single source of truth for profile wiring (switch + init)
│   └── ai-profile-init.sh         ← Renders profile tool subdirs (one-time per profile)
├── Makefile                       ← Entry-point wrapper; run `make help`
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

Profile-specific framework files stay in `profiles/<profile>/...`; user-level
state such as auth, history, projects, and plugins stays in
`$HOME/.{claude,copilot,codex}/` and is symlinked into the active profile on
each successful `ai <profile>` switch.

## Skills — what the AI knows

Skills are on-demand knowledge modules — conditionally-relevant
procedures the AI loads when needed, not all at once. They are also a
**shared language**: well-codified procedures mean a task means the same
thing on every harness, and make any future parallelization cheaper.

The full catalog lives in
[`framework/skills/README.md`](../framework/skills/README.md) — the single
source of truth. It covers the system-scope methodology skills, the vendored
tech-stack skills (TypeScript, Go, REST/GraphQL, Postgres, Kubernetes, cloud
infra), cross-cutting disciplines (frontend-design, TDD, systematic-debugging,
git-worktrees), their provenance, and coverage notes for stacks sourced
elsewhere (Figma, Cloudflare) or not yet covered (Java, MongoDB).

The operating protocol the AI follows is documented separately in
[`agent-protocol.md`](agent-protocol.md). Projects can also add their own
skills (e.g., `testing-with-jest`, `building-ddd-contexts`,
`running-pipeline-steps`).

## Sub-agents — the exception, not a tier

The base model is **one main agent**. Context is carried by the
**artifacts** — the spec and the plan — not by a cast of agent roles.
Sub-agents are not a next tier of seniority; they earn their existence
only on a **mechanical need**: context isolation, parallelism, or
read-only privilege. Role decomposition (author / architect / developer
as separate agents) is an anti-pattern — it serializes coupled decisions
and isolates context that belongs together. Spec authoring, the Split
check, and task decomposition therefore run **inline in the main
context** (see [`writing-specs/references/authoring-steps.md`](../framework/skills/writing-specs/references/authoring-steps.md)).

The one bespoke sub-agent is the read-only **reviewer**:

| Agent | When | Model | Tools | Purpose |
|---|---|---|---|---|
| `reviewer` | in-progress (recommended sub-step) | deep | read-only | Judges a change cold against its spec; returns `PASS` or `file:line → violated clause`. |

Precedent search at task-start is the main agent's own `Grep`/`Glob` or
the built-in read-only explore sub-agent — not a bespoke agent.

The contract — front-matter schema, body structure, the subagent-need
gate, fallback for non-Claude harnesses — lives at
[`framework/agents/README.md`](../framework/agents/README.md). Delegation
mechanics live at
[`docs/agent-protocol.md § Delegation contract`](agent-protocol.md#delegation-contract).

`make validate-specs` enforces the agent front-matter schema;
`make lint-rules` flags inline restatements of any agent's contract
outside `framework/agents/`.

## Boundaries — what the AI must NOT do

Three tiers of rules, from gentle to absolute:

| Tier | Examples |
|---|---|
| **Always do** | Run tests before committing, post preflight proof, log improvements |
| **Ask first** | Adding bounded contexts, changing AI prompts, modifying framework files |
| **Never do** | Commit secrets, skip Specify stage, mix refactoring with features, gold-plate |

Full list: [`framework/boundaries.md`](../framework/boundaries.md).

### Enforcement pyramid

The highest-leverage rules are enforced mechanically, in three layers
(earliest first); everything else remains prose-enforced:

1. **Harness hooks** — canonical scripts in
   [`framework/hooks/`](../framework/hooks/README.md), wired into Claude
   Code, Copilot CLI, and Codex CLI via adapter configs rendered by
   `ai-profile-init`: spec-status guard (PreToolUse), stamp refresh
   (PostToolUse), `ai doctor --fast` (SessionStart).
2. **Git pre-commit** (`make install-git-hooks`) — secrets scan + stamp
   freshness for every client, including IDE agents without CLI hooks.
3. **CI / `make check`** — `validate-specs`, `lint-rules`,
   `validate-anchors`, plus all script self-tests (`make tests`).

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

Three lanes scale the ceremony to the risk, smallest first: **Direct**
(≤2 files / ≤30 lines, no spec — Bottom Line + improvements-log entry),
**Trivial** (one combined gate), **Standard** (full gate sequence).
`low`/`trivial`-risk closures may run review-after (batch-reviewed) — see
[`spec-lifecycle.md`](../framework/spec-workflows/spec-lifecycle.md#direct-lane).

### Spec types

| Type | Prefix | Use when |
|---|---|---|
| **Change Request** | `CR-` | New feature, pipeline step, schema change |
| **Bug** | `BUG-` | Defect fix, incorrect behavior |
| **Improvement** | `IMP-` | Non-functional enhancement, refactor, performance |
| **Research** | `RES-` | Spike, investigation, proof of concept *(future)* |

Templates, per-type questions, and per-stage context lists live in
[`framework/spec-workflows/spec-types.md`](../framework/spec-workflows/spec-types.md).

## Process improvements

Every project keeps a `docs/improvements-log.md`. When the AI (or you)
notices a gap, friction, or better approach — it gets logged immediately.
This ensures the framework gets better over time rather than accumulating
hidden debt.

## Sync workflow (developer cheat sheet)

| Action | Command |
|---|---|
| List ai-dotfiles wrapper targets | `make help` |
| Initialize / re-initialize a profile's tool subdirs | `ai-profile-init <profile>` |
| Switch active profile | `ai <profile>` (e.g., `ai personal`) |
| Report active profile and current tool env vars | `ai` |
| Reset active profile env | `ai --reset` |
| Regenerate project `AGENTS.md` after editing `copilot-instructions.md` | `make sync-agents` (per project) |
| Verify no drift (used by CI) | `make sync-agents-check` |
| Validate spec corpus (front-matter, deps, naming, freshness, links, English-only, status invariants) | `make validate-specs` |
| Verify active-profile invariants (symlinks, manifest) | `make doctor` |
| Install the git pre-commit backstop (secrets, stamps) | `make install-git-hooks` |
| Run all script self-tests | `make tests` |
| Report framework-vs-product spec share by month | `make spec-metrics` |

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
