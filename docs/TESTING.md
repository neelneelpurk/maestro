# Testing

This repo's checks run through a single **quality gate** that the maestro pipeline
also enforces automatically before any pull request is opened. To validate your
changes locally, run the same gate yourself.

## Running the quality gate

From the repo root:

```bash
.maestro/scripts/quality-gate.sh
```

The gate runs, in order:

1. **install**
2. **lint**
3. **typecheck**
4. **test**

It exits `0` when every step passes (or when there is genuinely nothing to run),
and exits `1` as soon as a step fails. A PR should only be opened on a green
(exit `0`) gate.

To skip the install step on a repeat run (for example when dependencies are
already installed), pass `--no-install`:

```bash
.maestro/scripts/quality-gate.sh --no-install
```

### How steps are chosen

By default the gate **auto-detects** the toolchain in the current directory and
picks sensible commands for it — for example:

- `package.json` → the matching package manager's `install`, plus `lint`,
  `typecheck`, and `test` scripts when they exist
- `go.mod` → `go mod download`, `go vet ./...`, `go test ./...`
- `Cargo.toml` → `cargo fetch`, `cargo clippy`, `cargo test`
- `pyproject.toml` / `requirements.txt` → install via uv/poetry/pip, then
  `ruff`, `mypy`, `pytest`
- `Makefile` → `make lint` / `make test` when those targets exist

A tool that is simply missing is skipped (and noted); a tool that is present but
exits non-zero fails the gate. If nothing is detected and no overrides are set,
the gate runs nothing and warns you to configure it.

## Overriding the commands (`.maestro/config.sh`)

Auto-detection can be overridden per repo in `.maestro/config.sh` (this file is
machine-local and gitignored — it is created by `/maestro:init`). Each step has its
own variable:

- `MAESTRO_INSTALL_CMD`
- `MAESTRO_LINT_CMD`
- `MAESTRO_TYPECHECK_CMD`
- `MAESTRO_TEST_CMD`

Setting a variable replaces the auto-detected command for that step. Setting it
to the **empty string** explicitly **skips** that step. (The same variables can
also be supplied as environment variables.)

For example, this repo is a Bash + Markdown project with no conventional test
runner, so `.maestro/config.sh` skips install/lint/typecheck and defines a test
step that syntax-checks the shipped scripts:

```bash
MAESTRO_INSTALL_CMD=""
MAESTRO_LINT_CMD=""
MAESTRO_TYPECHECK_CMD=""
MAESTRO_TEST_CMD='ok=1; for f in plugins/maestro/scripts/*.sh; do bash -n "$f" || ok=0; done; [ "$ok" = 1 ] && echo "all scripts parse"'
```

After editing `.maestro/config.sh`, re-run `.maestro/scripts/quality-gate.sh` to
confirm the gate is green.
