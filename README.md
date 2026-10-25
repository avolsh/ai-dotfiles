# ai-dotfiles

*Last updated: 2026-10-25*

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
│   │   ├── claude/         ← Pre-built Claude Code config (CLAUDE_CONFIG_DIR target)
│   │   ├── copilot/        ← Pre-built Copilot config (COPILOT_HOME target)
│   │   └── codex/          ← Pre-built Codex config (CODEX_HOME target)
│   └── work/               ← Same shape as personal/
├── scripts/
│   ├── ai-switch.sh        ← Switches active profile, persists env, links shared state
│   ├── ai-cloud-setup.sh   ← Wires a profile into a cloud session's ~/.claude (§ Cloud sessions)
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
| Think an idea through | `explore`, `think through`, `compare options` | AI reads and asks, writes nothing → hands off settled answers to create-spec |
| Build a feature | `create CR`, `new feature`, `specify` | AI asks questions → writes spec → waits for approval |
| Improve / refactor | `create IMP`, `improve`, `refactor` | AI writes improvement spec → waits for approval |
| Fix a bug | `bug`, `triage`, `investigate issue` | AI investigates → writes bug spec → waits for approval |
| Visualize architecture | `visualize`, `architecture` | AI adds Mermaid diagrams to current spec |
| Plan an approved spec | `plan`, `break into tasks` | AI breaks the spec into vertical-slice tasks |
| Approve & advance | `continue` | Approves the current task; AI starts the next single task |
| Resume after a break | `resume`, `where were we` | AI finds the spec's next task; re-asks approval for a task still `◐`, else posts preflight |

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
2. Links `framework/templates/system/{claude/CLAUDE.md, copilot/copilot-instructions.md, codex/AGENTS.md}` into `profiles/<profile>/{claude,copilot,codex}/`
3. Creates per-tool symlinks for `boundaries.md`, `docs/`, `skills/`, `prompts/`, `spec-workflows/`, `templates/` inside each tool subdir, and renders the hook configs (Claude's merged into `settings.json`)

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

## Cloud sessions

A Claude Code cloud session (a claude.ai project thread, or claude.ai/code) clones the repos fresh into
a container whose `~/.claude` belongs to the harness: its own hooks, skills and sign-in live there.
`scripts/ai-cloud-setup.sh` wires the framework into that directory in place of `ai <profile>`, so
`<system>/` is `~/.claude` in the cloud. Never set `CLAUDE_CONFIG_DIR` there: the CLI would
no longer find the harness's files, so the script links and merges beside them instead.

### One environment per profile

The setup script cannot read the environment's variables, so the profile is its argument and each
profile gets a cloud environment of its own. Open the project's settings, open the **Cloud environment**
menu and choose **Add cloud environment**, which also selects it for the project; sessions started
after that run on it. The project's repositories must include `ai-dotfiles`: the script treats the
directory holding it as the workspace.

| Field | Value |
|---|---|
| Setup script | `bash ai-dotfiles/scripts/ai-cloud-setup.sh personal` (or `work`) |
| Network access | Limited, with **Allow package managers** ticked and `mirror.gcr.io` under Allowed domains |
| Environment variables | Development keys only. No production key, no kubeconfig, nothing that reaches a cluster |

The script, idempotent:

1. runs `ai-profile-init.sh <profile>`;
2. links `CLAUDE.md`, `boundaries.md`, `docs/` and every framework skill into `~/.claude`, keeping each
   entry the harness owns;
3. merges the framework hooks and `AI_DOTFILES` / `AI_PROFILE` into `~/.claude/settings.json`, beside
   the harness's own hooks;
4. points `core.hooksPath` of every cloned repo at the pre-commit backstop;
5. starts `dockerd` with `mirror.gcr.io` as its registry mirror, because anonymous Docker Hub pulls from
   the shared egress address are refused. `--no-docker` skips this step.

The SessionStart hook runs `ai-doctor.sh --fast`, which adds the cloud checks whenever
`CLAUDE_CODE_REMOTE=true`; `scripts/ai-doctor.sh --cloud` prints the whole report. A session uses the
framework as it is on the default branch of `ai-dotfiles` when the session starts, so a framework change
reaches the cloud once it is merged there, in the next new session.

### Git in a cloud session

You own the task branch of each repo and name it. In the cloud the agent asks you which branch to start
from in each repo, records the answers under the spec's `branches:`, works on its own `claude/*` branch
cut from it, and opens the draft PR into that branch itself after its first push. It never merges,
never force-pushes and never opens a PR into `master` or `develop`
([`boundaries.md` § Never do #10, cloud exception](framework/boundaries.md#cloud-git-exception));
`bash-write-guard.sh` and `pr-base-guard.sh` enforce it. Leave the UI's **Create draft PR** button
alone: it opens the PR into the default branch.

### Cloud and local on one branch

Work that needs an integration (the cluster, real keys) runs on your machine; the rest can stay in the
cloud. Both sides share the one `claude/*` branch and its one PR:

1. The cloud session does its tasks and pushes.
2. Locally: `git fetch origin <claude-branch>`, `git switch <claude-branch>`, `git pull --ff-only`, do
   the local task, push.
3. Back in the cloud the agent runs `git pull --ff-only` and carries on.

One side works at a time and nobody force-pushes. When `git pull --ff-only` refuses, the branch has
diverged: the agent stops and asks, and you decide how to bring the two together.

---

## Profile semantics

Profiles carry identity-level content: `AI_PROFILE` (in `profile.env`). They do
not carry workspace or project rules (those belong in per-repo
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
