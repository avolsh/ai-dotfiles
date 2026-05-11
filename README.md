# ai-dotfiles

Personal AI Agent Framework dotfiles — skills, spec-workflows, prompts, and
identity profiles for GitHub Copilot, Claude Code, and OpenAI Codex CLI.

> **Keys are never committed.** API keys live in `keys/` (gitignored). The
> tracked backend env files reference `keys/` paths; they never contain literal
> key material.

---

## Directory layout

```
ai-dotfiles/
├── framework/          ← Layer 1: single source of truth (tool-agnostic, identity-agnostic)
│   ├── skills/         ← Reusable knowledge modules (agent-protocol, writing-specs, …)
│   ├── spec-workflows/ ← Spec lifecycle, types, templates, questions
│   ├── prompts/        ← Workflow trigger prompts ("create CR", "plan", …)
│   ├── templates/      ← Bootstrap templates for new projects
│   ├── tools/          ← Per-tool instruction templates (rendered into ~/.claude/ etc.)
│   ├── upstream/       ← Upstream skill catalog placeholder (see upstream/README.md)
│   └── boundaries.md   ← Rules: always do / ask first / never do
├── profiles/           ← Layer 2: per-identity overlays
│   ├── personal/       ← Active profile (profile.env, CLAUDE.md, preferences.md, …)
│   └── work.example/   ← Stub profile — populate when needed
├── backends/           ← Backend env files (auth-exclusive, unset-before-export)
│   ├── local.env       ← Local LLM endpoint
│   └── cloud-claude.env ← Anthropic cloud (reads API key from keys/)
├── scripts/
│   ├── ai-switch.sh    ← Renders framework + profile → each tool's home directory
│   └── sync-agents.sh  ← Regenerates profiles/personal/AGENTS.md (single-profile fork)
├── docs/
│   ├── ai-agent-framework.md  ← Framework overview (what it is, how it's organized)
│   └── spec-workflow-guide.md ← Four-status spec lifecycle walkthrough
├── keys/               ← Gitignored: anthropic.key, *.local.env
└── Makefile            ← sync-agents, sync-agents-check, help
```

---

## Getting Started

### 1. Read these two docs

| Doc | What you'll learn | Time |
|---|---|---|
| [AI Agent Framework Overview](docs/ai-agent-framework.md) | What the framework is, how it's organized, what the AI can and can't do | 5 min |
| [Spec Workflow Guide](docs/spec-workflow-guide.md) | The four-status lifecycle every change follows, with diagrams | 5 min |

### 2. Know the key files

The framework renders into two layers — **system** (your tool home dirs) and
**project** (each repo). Project rules extend the system layer and win on conflict.

| File | Where | Read by | Purpose |
|---|---|---|---|
| `~/.claude/CLAUDE.md` | Tool home (rendered) | Claude Code | System-scope agent instructions |
| `~/.codex/AGENTS.md` | Tool home (rendered) | Codex CLI | System-scope agent instructions |
| `~/.copilot/AGENTS.md` | Tool home (rendered) | Copilot CLI | System-scope agent instructions |
| `.github/copilot-instructions.md` | Each project | GitHub Copilot | Project rules — references `<system>/...` for framework |
| `AGENTS.md` | Each project | OpenAI Codex CLI | Mechanical copy of `copilot-instructions.md`, no `@`-imports |
| `CLAUDE.md` | Each project | Claude Code | Thin `@`-import file |
| `docs/specs/active/` | Each project | humans / agents | Specs currently being worked on |

> Edit `.github/copilot-instructions.md`, then run `make sync-agents`.
> The CI gate (`agents-drift-check.yml`) fails any PR that leaves
> `AGENTS.md` out of sync.

### 3. Start working

Trigger phrases below map 1:1 to `<system>/prompts/*.prompt.md`.

| What you want | What to say | What happens |
|---|---|---|
| Build a feature | `create CR`, `new feature`, `specify` | AI asks questions → writes spec → waits for approval |
| Improve / refactor | `create IMP`, `improve`, `refactor` | AI writes improvement spec → waits for approval |
| Fix a bug | `bug`, `triage`, `investigate issue` | AI investigates → writes bug spec → waits for approval |
| Visualize architecture | `visualize`, `architecture` | AI adds Mermaid diagrams to current spec |
| Plan an approved spec | `plan`, `break into tasks` | AI breaks the spec into vertical-slice tasks |
| Add a new project | `bootstrap project`, `new project` | AI scans the repo → scaffolds framework files |
| Refresh project framework | `update project framework`, `refresh docs` | AI re-bootstraps an existing project |
| Approve & advance | `continue` | Approves the current task; AI starts the next single task |

### 4. Remember three things

1. **You approve everything.** The AI stops at every gate and waits.
2. **"Continue" = one task.** Not "do everything." Just the next task.
3. **Specs before code.** The AI won't write code until you've approved
   the spec and plan.

---

## ai-switch.sh

Switch the active profile and backend in one command:

```bash
ai personal local        # local LLM, personal identity
ai personal cloud-claude # Anthropic cloud, personal identity
```

These aliases are defined in `~/.zshrc` (appended by `ai-switch.sh` setup).
Running the command:

1. Sources `profiles/<profile>/profile.env` (identity-level non-secret vars: `AI_PROFILE`, `ANTHROPIC_MODEL`)
2. Sources `backends/<backend>.env` (unsets all auth, then exports the backend's own auth vars)
3. Renders `framework/tools/<tool>/template` via allowlisted `envsubst`, appends profile body and preferences, writes atomically to `~/.{claude,copilot,codex}/`
4. Installs per-entry skill and agent symlinks under each tool home
5. Installs tool-agnostic reference symlinks (`spec-workflows`, `prompts`, `templates`, `boundaries.md`)
6. Cleans stale managed symlinks; preserves user-owned plain files
7. Writes `.active-manifest` per tool home (no auth values)
8. Prints: `✓ profile=... backend=... model=... skills=N agents=M`

---

## Profile / backend semantics

**Profiles** carry identity-level content only: `AI_PROFILE`, `ANTHROPIC_MODEL`,
optional tone/style preferences, optional skill overlays. They never carry
workspace or project rules (those belong in per-repo `.github/copilot-instructions.md`).
They never carry auth credentials (those belong in backends).

**Backends** carry the auth side: `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN` (local)
or `ANTHROPIC_API_KEY` (cloud). Every backend file begins with
`unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL` before
re-exporting only its own vars — this guarantees no stale auth leaks between switches.

---

## Keys — never committed

`keys/` is gitignored. Create `keys/anthropic.key` containing your Anthropic API key:

```bash
echo "sk-ant-..." > "$AI_DOTFILES/keys/anthropic.key"
chmod 600 "$AI_DOTFILES/keys/anthropic.key"
```

`backends/cloud-claude.env` reads the key via:
```bash
export ANTHROPIC_API_KEY="$(cat "$AI_DOTFILES/keys/anthropic.key")"
```

Never put a literal key in any tracked file.

---

## Makefile

```
make sync-agents        # regenerate profiles/personal/AGENTS.md
make sync-agents-check  # check for drift (CI use)
make help               # list targets
```
