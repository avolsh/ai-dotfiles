# ai-dotfiles

*Last updated: 2026-06-14*

Personal AI Agent Framework dotfiles — skills, spec-workflows, prompts, and
identity profiles for GitHub Copilot, Claude Code, and OpenAI Codex CLI.

> **Auth credentials are the user's responsibility.** ai-dotfiles does not
> set `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, or `ANTHROPIC_BASE_URL`.
> Export them in your shell (`~/.zshrc` etc.). `keys/` is gitignored if you
> prefer to keep local key files inside the dotfiles tree.

---

## Directory layout

```
ai-dotfiles/
├── framework/              ← Tool-agnostic, identity-agnostic
│   ├── skills/             ← Reusable knowledge modules (catalog: skills/README.md)
│   ├── spec-workflows/     ← Spec lifecycle, types, templates, questions
│   ├── prompts/            ← Workflow trigger prompts ("create CR", "plan", …)
│   ├── templates/          ← Bootstrap templates
│   │   ├── system/         ← Per-tool system templates (rendered by ai-profile-init)
│   │   ├── workspace/      ← Workspace scaffold templates (used by ai-workspace)
│   │   └── project/        ← Project scaffold templates (used by ai-project)
│   ├── upstream/           ← Upstream skill catalog placeholder
│   └── boundaries.md       ← Rules: always do / ask first / never do
├── profiles/               ← Per-identity overlays
│   ├── personal/
│   │   ├── profile.env     ← AI_PROFILE
│   │   ├── preferences.md  ← Identity content appended on render
│   │   ├── claude/         ← Pre-built Claude Code config (CLAUDE_CONFIG_DIR target)
│   │   ├── copilot/        ← Pre-built Copilot config (COPILOT_HOME target)
│   │   └── codex/          ← Pre-built Codex config (CODEX_HOME target)
│   └── work/               ← Same shape as personal/
├── scripts/
│   ├── ai-switch.sh        ← Switches active profile, persists env, links shared state
│   └── ai-profile-init.sh  ← Renders profile tool subdirs (one-time per profile)
├── Makefile                ← Entry-point wrapper; run `make help`
├── docs/
│   ├── ai-agent-framework.md
│   └── spec-workflow-guide.md
└── keys/                   ← Gitignored
```

---

## Getting Started

### 1. Read these two docs

| Doc | What you'll learn | Time |
|---|---|---|
| [AI Agent Framework Overview](docs/ai-agent-framework.md) | What the framework is, how it's organized | 5 min |
| [Spec Workflow Guide](docs/spec-workflow-guide.md) | The four-status lifecycle every change follows | 5 min |

### 2. Know the key files

The framework loads into two layers — **system** (your active profile's tool
subdirs) and **project** (each repo). Project rules extend the system layer
and win on conflict.

| File | Where | Read by | Purpose |
|---|---|---|---|
| `profiles/<profile>/claude/CLAUDE.md` | Active profile | Claude Code (via `CLAUDE_CONFIG_DIR`) | System-scope agent instructions |
| `profiles/<profile>/copilot/copilot-instructions.md` | Active profile | Copilot (via `COPILOT_HOME`) | System-scope agent instructions |
| `profiles/<profile>/codex/AGENTS.md` | Active profile | Codex CLI (via `CODEX_HOME`) | System-scope agent instructions |
| `.github/copilot-instructions.md` | Each project | GitHub Copilot | Project rules — references `<system>/...` for framework |
| `AGENTS.md` | Each project | OpenAI Codex CLI | Mechanical copy of `copilot-instructions.md`, no `@`-imports |
| `CLAUDE.md` | Each project | Claude Code | Thin `@`-import file |
| `docs/specs/active/` | Each project | humans / agents | Specs currently being worked on |

### 3. Start working

Trigger phrases below map 1:1 to `<system>/prompts/*.prompt.md`.

| What you want | What to say | What happens |
|---|---|---|
| Build a feature | `create CR`, `new feature`, `specify` | AI asks questions → writes spec → waits for approval |
| Improve / refactor | `create IMP`, `improve`, `refactor` | AI writes improvement spec → waits for approval |
| Fix a bug | `bug`, `triage`, `investigate issue` | AI investigates → writes bug spec → waits for approval |
| Visualize architecture | `visualize`, `architecture` | AI adds Mermaid diagrams to current spec |
| Plan an approved spec | `plan`, `break into tasks` | AI breaks the spec into vertical-slice tasks |
| Approve & advance | `continue` | Approves the current task; AI starts the next single task |

### 4. Remember three things

1. **You approve everything.** The AI stops at every gate and waits.
2. **"Continue" = one task.** Not "do everything." Just the next task.
3. **Specs before code.** The AI won't write code until you've approved
   the spec and plan.

---

## Shell setup (run once)

Install the managed alias block in `~/.zshrc`:

```bash
$AI_DOTFILES/scripts/ai-install.sh
```

The script writes (or refreshes) the block between markers
`# >>> ai-dotfiles aliases >>>` / `# <<< ai-dotfiles aliases <<<`,
exporting `AI_DOTFILES` and defining the four aliases (`ai`,
`ai-profile-init`, `ai-workspace`, `ai-project`). It is idempotent —
re-running with no input change is a no-op. Pass `--check` to verify
the block is current without writing, or `--rc-file <path>` to target
a non-default file (testing).

After installing, run `source ~/.zshrc` (or open a new terminal) for
the aliases to take effect.

For Makefile wrappers around the scripts, run:

```bash
make help
```

---

## ai-switch.sh

Report, switch, or reset the active profile:

```bash
ai            # report current profile, env vars, profiles, and usage
ai personal   # personal identity
ai work       # work identity
ai --reset    # remove the active-profile block and unset tool env vars
```

Running `ai <profile>`:

1. Validates `profiles/<profile>/` exists with initialized `claude/`, `copilot/`, `codex/` subdirs
2. Links user-level shared state from `$HOME/.{claude,copilot,codex}/` into the profile's tool subdirs, excluding profile-managed framework files and temp/backup names
3. Sources `profiles/<profile>/profile.env` (sets `$AI_PROFILE`)
4. Exports `CLAUDE_CONFIG_DIR`, `COPILOT_HOME`, `CODEX_HOME` pointing at the profile's tool subdirs
5. Writes an idempotent `~/.zshrc` block between `# >>> ai-dotfiles active profile >>>` / `# <<< ai-dotfiles active profile <<<`
6. Calls `launchctl setenv` for the three tool env vars when available, so newly-launched GUI apps can see the active profile

The `~/.zshrc` active-profile block is separate from the alias block written
by `ai-install.sh`. `ai --reset` removes only the active-profile block,
calls `launchctl unsetenv` for the three tool vars when available, and
unsets the vars in the current shell.

---

## ai-profile-init.sh

Initialize (or re-initialize) a profile's tool subdirs by rendering the
system templates with the profile's identity and creating framework
symlinks. Run once per profile before the first `ai <profile>` switch:

```bash
ai-profile-init personal
```

The script:

1. Sources `profiles/<profile>/profile.env` to set `$AI_PROFILE`
2. Renders `framework/templates/system/{claude/CLAUDE.md, copilot/copilot-instructions.md, codex/AGENTS.md}` via allowlisted `envsubst` (only `$AI_PROFILE`), appends `profiles/<profile>/preferences.md`, and writes to `profiles/<profile>/{claude,copilot,codex}/`
3. Creates per-tool symlinks for `boundaries.md`, `skills/`, `prompts/`, `spec-workflows/`, `templates/` inside each tool subdir

Shared user-level state such as auth, history, projects, and plugins is
linked by `ai-switch.sh` on each successful switch, not by
`ai-profile-init.sh`.

---

## ai-workspace.sh

Scaffold the current directory as a new workspace root by copying every
template from `framework/templates/workspace/` into the cwd, preserving
directory structure. Existing files are skipped (never overwritten).
Does NOT run `make sync-agents` — fill in placeholders first, then run
it manually.

```bash
cd /path/to/new-workspace
ai-workspace
```

The script copies all 6 workspace artifacts (`CLAUDE.md`, `AGENTS.md`,
`Makefile`, `.github/copilot-instructions.md`,
`.github/scripts/sync-agents.sh`, `docs/improvements-log.md`) and ensures
`docs/` exists. Re-running on an already-scaffolded workspace is a no-op.

---

## ai-project.sh

Scaffold the current directory as a new project repo by copying every
template from `framework/templates/project/` into the cwd, preserving
directory structure. Existing files are skipped (never overwritten).
Does NOT run `make sync-agents` — fill in placeholders first, then run
it manually.

```bash
cd /path/to/new-project
ai-project
```

The script copies all 10 required artifacts (`CLAUDE.md`, `AGENTS.md`,
`Makefile`, `.github/copilot-instructions.md`, `.github/scripts/sync-agents.sh`,
`docs/README.md`, `docs/specs/{active,archived}/README.md`,
`docs/architecture/module-map.md`, `docs/improvements-log.md`) and
ensures `docs/` exists. Re-running on an already-scaffolded project is
a no-op.

---

## Profile semantics

Profiles carry identity-level content: `AI_PROFILE` (in `profile.env`) and
optional tone/style preferences (in `preferences.md`). They do not carry
workspace or project rules (those belong in per-repo
`.github/copilot-instructions.md`) and they do not carry auth credentials
(those belong in your shell env).

---

## Auth credentials — user-managed

ai-dotfiles does not set authentication env vars. Configure them in
`~/.zshrc` (or your shell config):

```bash
export ANTHROPIC_API_KEY="$(cat "$AI_DOTFILES/keys/anthropic.key")"
```

`keys/` is gitignored. Never put a literal key in any tracked file.
