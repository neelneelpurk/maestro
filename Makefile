.PHONY: help test lint

help:
	@echo "maestro — developer tasks"
	@echo "  make test   run the pure-bash test suite (tests/run.sh)"
	@echo "  make lint   shellcheck the scripts (skipped if shellcheck is absent)"

# `quality-gate.sh` auto-detects this Makefile and runs `make lint` + `make test`,
# so the repo gates itself with no .maestro/config.sh needed.
test:
	@bash tests/run.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck plugins/maestro/scripts/*.sh plugins/maestro/hooks/*.sh tests/run.sh tests/lib/*.sh tests/unit/*_test.sh; \
	else \
		echo "shellcheck not installed — skipping (brew install shellcheck / apt-get install shellcheck)"; \
	fi
