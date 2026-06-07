# Testing

This repo's checks run through a single **quality gate** that the maestro pipeline
also enforces automatically before any pull request is opened. To validate your
changes locally, run the same gate yourself.

## The plugin's own test suite

maestro's bash scripts are tested with a tiny **dependency-free, pure-bash test
harness** under `tests/` — no `bats`, no extra installs (keeping the project's
"bash + jq + gh", bash-3.2-compatible promise). Run it directly or via `make`:

```bash
bash tests/run.sh      # run every tests/unit/*_test.sh, aggregate, exit non-zero on failure
make test              # same thing
make lint              # shellcheck the scripts (skipped if shellcheck is absent)
```

Each test file under `tests/unit/` sources `tests/lib/assert.sh` (which provides
`assert_eq`, `assert_contains`, `assert_matches`, `assert_status`, …), makes
assertions, and ends with `t_end`. To add coverage, drop a new
`tests/unit/<name>_test.sh` in place — the runner discovers it automatically.

Because this repo ships a `Makefile` with `test`/`lint` targets, the quality gate
below **auto-detects** it and runs `make lint` + `make test` with no
`.maestro/config.sh` needed.

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

It exits `0` when every step passes, and `1` as soon as a step fails. If
**nothing runs** (no toolchain detected and nothing configured), the gate also
exits `1` rather than reporting a false green — see [How steps are
chosen](#how-steps-are-chosen). A PR should only be opened on a green (exit `0`)
gate.

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
the gate **fails** (exit `1`) rather than reporting a false green. To allow a
deliberately empty gate (e.g. a docs-only repo), set `MAESTRO_ALLOW_EMPTY_GATE=1`
in `.maestro/config.sh` or the environment.

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

For example, this repo is a Bash + Markdown project: it ships a `Makefile`, so the
gate auto-detects `make lint` + `make test` and runs the pure-bash suite with no
overrides needed. If you'd rather be explicit, pin the test step directly:

```bash
MAESTRO_TEST_CMD='bash tests/run.sh'
```

After editing `.maestro/config.sh`, re-run `.maestro/scripts/quality-gate.sh` to
confirm the gate is green.
