#!/usr/bin/env bash
# generate-system-templates.sh — emit the three tool-flavored system
# templates (claude/CLAUDE.md, copilot/copilot-instructions.md,
# codex/AGENTS.md) from the single canonical source
# `framework/templates/system/_canonical.md`.
#
# The only inter-template difference is the rendered-file path noted
# in the header comment; this script substitutes `__RENDERED_PATH__`
# accordingly. Output is byte-stable across runs (idempotent) given
# unchanged canonical input.
#
# Per IMP-20260514-dedup-rule-statements FR-3 / FR-4.

set -euo pipefail

# Resolve repo root from script location (env/ai-dotfiles/scripts/* → repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL="$REPO_ROOT/framework/templates/system/_canonical.md"

if [ ! -f "$CANONICAL" ]; then
  echo "generate-system-templates: canonical source missing at $CANONICAL" >&2
  exit 2
fi

# Tool → (rel_path of rendered file). The path becomes the value of
# __RENDERED_PATH__ in the rendered file's header.
render_tool() {
  local tool="$1"
  local filename="$2"
  local rendered_path="\$AI_DOTFILES/framework/templates/system/$tool/$filename"
  local out="$REPO_ROOT/framework/templates/system/$tool/$filename"

  mkdir -p "$(dirname "$out")"

  # Substitute __RENDERED_PATH__; preserve every other byte.
  # sed -e with literal-replacement (no regex semantics on RHS thanks
  # to no special chars in the substitution string).
  sed "s|__RENDERED_PATH__|$rendered_path|g" "$CANONICAL" > "$out"

  echo "rendered: framework/templates/system/$tool/$filename"
}

render_tool claude   CLAUDE.md
render_tool copilot  copilot-instructions.md
render_tool codex    AGENTS.md

echo "generate-system-templates: OK (3 file(s) rendered from _canonical.md)"
