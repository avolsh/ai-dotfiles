.PHONY: sync-agents sync-agents-check help

help:
	@echo "Targets:"
	@echo "  sync-agents        Regenerate profiles/personal/AGENTS.md"
	@echo "  sync-agents-check  Check for drift (exits non-zero if AGENTS.md needs regeneration)"

sync-agents:
	./scripts/sync-agents.sh

sync-agents-check:
	./scripts/sync-agents.sh --check
