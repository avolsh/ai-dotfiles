# scripts/test/lib/test-env.sh
#
# Sourced by every shell test suite, right after `set -euo pipefail` (IMP-20261025-cloud-sessions FR-20). A wired
# session exports the framework's variables through settings.json `env` — AI_DOTFILES, AI_PROFILE, and
# CLAUDE_CODE_REMOTE in the cloud — and a cloud container rewrites git origins through GIT_CONFIG_COUNT. A suite
# that inherits them tests the session it runs in, not its fixture; each case that needs one sets it itself.
unset AI_DOTFILES AI_PROFILE CLAUDE_CODE_REMOTE GIT_CONFIG_COUNT
