#!/usr/bin/env bash
# scripts/ai-install.sh
#
# Idempotent installer for the ai-dotfiles `~/.zshrc` managed block.
# Adds `AI_DOTFILES` export and `ai`, `ai-profile-init`, `ai-workspace`,
# `ai-project` aliases. Re-running with no input change is a no-op.
#
# Usage:
#   ai-install.sh                  # write to ~/.zshrc
#   ai-install.sh --check          # exit non-zero on drift; no writes
#   ai-install.sh --rc-file <path> # override default ~/.zshrc (testing)

set -euo pipefail

_err() { printf 'ai-install: %s\n' "$*" >&2; }

# --- Parse args ---
CHECK=0
RC_FILE="$HOME/.zshrc"

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --rc-file)
      if [ -z "${2:-}" ]; then
        _err "--rc-file requires a path argument"
        exit 2
      fi
      RC_FILE="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# *//'
      exit 0
      ;;
    *)
      _err "unknown argument: $1"
      _err "usage: ai-install.sh [--check] [--rc-file <path>]"
      exit 2
      ;;
  esac
done

# --- Compute AI_DOTFILES from this script's own location ---
AI_DOTFILES_PATH="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$AI_DOTFILES_PATH" == "$HOME"* ]]; then
  display_path='$HOME'"${AI_DOTFILES_PATH#$HOME}"
else
  display_path="$AI_DOTFILES_PATH"
fi

# --- Canonical managed block content ---
MARKER_START='# >>> ai-dotfiles aliases >>>'
MARKER_END='# <<< ai-dotfiles aliases <<<'

block_content=$(cat <<EOF
$MARKER_START
# Managed by env/ai-dotfiles. Edit by re-running scripts/ai-install.sh.
export AI_DOTFILES="$display_path"
alias ai="source \$AI_DOTFILES/scripts/ai-switch.sh"
alias ai-profile-init="\$AI_DOTFILES/scripts/ai-profile-init.sh"
alias ai-workspace="\$AI_DOTFILES/scripts/ai-workspace.sh"
alias ai-project="\$AI_DOTFILES/scripts/ai-project.sh"
$MARKER_END
EOF
)

# --- Build expected file content into a tmp file ---
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if [ -f "$RC_FILE" ] && grep -qF "$MARKER_START" "$RC_FILE"; then
  # Replace existing block in place using line-number slicing.
  start_line="$(grep -nF "$MARKER_START" "$RC_FILE" | head -1 | cut -d: -f1)"
  end_line="$(grep -nF "$MARKER_END" "$RC_FILE" | head -1 | cut -d: -f1)"
  if [ -z "$end_line" ] || [ "$end_line" -lt "$start_line" ]; then
    _err "$RC_FILE has start marker without matching end marker; refusing to edit"
    rm -f "$tmp"
    trap - EXIT
    exit 3
  fi
  : > "$tmp"
  if [ "$start_line" -gt 1 ]; then
    head -n "$((start_line - 1))" "$RC_FILE" >> "$tmp"
  fi
  printf '%s\n' "$block_content" >> "$tmp"
  tail -n "+$((end_line + 1))" "$RC_FILE" >> "$tmp"
else
  # Append (or create from empty)
  if [ -s "$RC_FILE" ]; then
    cat "$RC_FILE" > "$tmp"
    printf '\n' >> "$tmp"
  fi
  printf '%s\n' "$block_content" >> "$tmp"
fi

# --- Compare and write ---
if [ -f "$RC_FILE" ] && cmp -s "$tmp" "$RC_FILE"; then
  rm -f "$tmp"
  trap - EXIT
  if [ "$CHECK" -eq 1 ]; then
    echo "✓ $RC_FILE: ai-dotfiles block is up to date"
  else
    echo "✓ $RC_FILE: ai-dotfiles block already up to date (no changes)"
  fi
  exit 0
fi

if [ "$CHECK" -eq 1 ]; then
  rm -f "$tmp"
  trap - EXIT
  _err "drift detected in $RC_FILE — run scripts/ai-install.sh to update"
  exit 1
fi

mv "$tmp" "$RC_FILE"
trap - EXIT
echo "✓ $RC_FILE: ai-dotfiles block updated"
echo ""
echo "Run \`source $RC_FILE\` or open a new terminal for changes to take effect."
