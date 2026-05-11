# upstream/ — pending placeholder

This directory is reserved for the upstream skill catalog submodule (previously
hosted under tobevisit's old workspace framework root, now deleted by FR-29 of
the bootstrap IMP).

**Status:** Not yet populated. Re-pointing or re-adding the submodule is deferred to a
future spec (see `IMP-20260504-ai-dotfiles-bootstrap` OS-6 / followup `IMP-20260505-ai-dotfiles-followups` FR-9).

References inside `framework/` files use `<system>/upstream/...` which resolves to this
directory via the symlinks created by `ai-switch.sh` step 4a. Those links are intentionally
broken until this directory is populated — the broken state is visible and deliberate.

## When this becomes actionable

Once `IMP-20260505-ai-dotfiles-followups` FR-9 advances to `in-progress`:
1. Add the upstream submodule here (or copy it from its current location).
2. Remove this placeholder notice.
3. Verify `<system>/upstream/claude-skills/` resolves correctly from each tool home.
