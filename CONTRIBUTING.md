# Contributing to ai-sdlc

Thanks for helping improve **ai-sdlc** — a downloadable, multi-agent AI SDLC
that drives a GitHub repo from PRD to pull request. This guide explains how the
plugin is laid out, how to run the quality gate locally, and the pull-request
conventions the pipeline relies on.

If you are new to the project, start with the [README](README.md) for the
big-picture pipeline, and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the
full design.

## Project layout

This repository is a **Claude Code marketplace** (`ai-sdlc`) that ships a single
**plugin** (`sdlc`). Everything that makes up the plugin lives under
`plugins/sdlc/`:

```
plugins/sdlc/
├── .claude-plugin/
│   └── plugin.json     # plugin manifest: name, version, description, metadata
├── commands/           # slash commands — the /sdlc:* entry points (e.g. ship.md)
├── skills/             # multi-step skills, one directory per skill with a SKILL.md
│   ├── implement-issue/        # take ONE issue → worktree → quality gate → PR
│   └── ship-ready-issues/      # fan out: one subagent + one PR per ready issue
├── agents/             # subagent definitions (e.g. issue-implementer.md)
├── hooks/              # lifecycle hooks (drain-loop Stop hook, PR quality-gate /
│                       #   disclaimer PreToolUse hooks)
├── scripts/            # deterministic bash + gh + jq helpers (the canonical source)
└── schedules/          # cron routines for unattended draining
```

A few conventions worth knowing:

- **`commands/`** — each `*.md` file is one `/sdlc:<name>` slash command. The
  front-matter `description` and `argument-hint` drive how it surfaces in Claude
  Code; the body delegates to a skill.
- **`skills/`** — each skill is its own directory containing a `SKILL.md` with
  YAML front-matter (`name`, `description`). The description is the trigger, so
  keep it sharp. Bundle any helper files the skill needs alongside its
  `SKILL.md`.
- **`agents/`** — subagents are single `*.md` files with front-matter (`name`,
  `description`, `tools`, `model`, `color`). `issue-implementer` is spawned
  one-per-issue for parallel fan-out.
- **`hooks/`** — automation that the harness (not the model) runs at lifecycle
  points: the drain loop and the PR guards live here.
- **`scripts/`** — the deterministic pipeline: queue queries, worktree
  management, PR creation, and the quality gate. **This is the source of
  truth.** `/sdlc:init` copies these into the target repo's machine-local
  `.sdlc/scripts/` (gitignored) and records their absolute path in
  `.sdlc/config.sh`. When you change pipeline behavior, edit the files under
  `plugins/sdlc/scripts/` — never the installed `.sdlc/` copy.
- **`schedules/`** — cron routine definitions for running the drain loop
  unattended.

> Note on naming: the marketplace is `ai-sdlc`; the plugin inside it is `sdlc`.
> That is why commands are `/sdlc:*` and the install target is `sdlc@ai-sdlc`.

## Local setup

You need:

- [`gh`](https://cli.github.com/) authenticated with `repo` scope
  (`gh auth status`)
- `jq`
- `bash`

The pipeline scripts are plain bash; there is no build step or dependency
install for the plugin itself.

## Running the quality gate

Before you open a pull request, run the quality gate and make sure it exits
**0**. This is the same gate the pipeline runs for every agent-authored PR, so
running it locally keeps you in sync with CI/agent behavior:

```bash
.sdlc/scripts/quality-gate.sh
```

(If you are working in this repo directly without having run `/sdlc:init`, the
equivalent canonical script is `plugins/sdlc/scripts/quality-gate.sh` — they are
the same file.)

What the gate does:

- It **auto-detects the toolchain** in the current directory and runs
  `install → lint → typecheck → test`, running only the steps that apply.
- For **this** repo (bash + Markdown), the gate syntax-checks every committed
  script — effectively `bash -n plugins/sdlc/scripts/*.sh`. So at minimum, make
  sure every script you touch parses cleanly.
- Steps are overridable per-repo via `.sdlc/config.sh` (or environment
  variables): `SDLC_INSTALL_CMD`, `SDLC_LINT_CMD`, `SDLC_TYPECHECK_CMD`,
  `SDLC_TEST_CMD`. Setting an override to the empty string **skips** that step.

A present tool that exits non-zero **fails** the gate; a missing tool is simply
skipped. **Never open a PR on a red gate** — fix the failure and re-run until it
is green.

## Pull-request conventions

The pipeline (`open-pr.sh`) generates PR bodies in a consistent shape, and we
ask human contributors to match it so every PR reads the same way:

1. **Link the issue with `Closes #<n>`.** Put `Closes #<issue-number>` in the PR
   body so merging the PR automatically closes the issue. One PR closes one
   issue.
2. **Include the AI disclaimer.** Every PR body carries a short disclaimer noting
   that the change was produced (or assisted) by an AI agent. Agent-opened PRs
   add this automatically; if you open a PR by hand for work that involved an
   agent, keep the disclaimer in place.
3. **Summarize against the acceptance criteria.** Briefly map what you did to
   each acceptance criterion from the issue, and list the commits. `open-pr.sh`
   does this for you; mirror it for manual PRs.
4. **Reference the issue in your commits.** Commit messages should mention the
   issue number (e.g. `... (#<n>)`) so history stays traceable.
5. **One issue per branch, in its own worktree.** Pipeline work happens on a
   `sdlc/issue-<n>-<slug>` branch in a dedicated git worktree. Never commit to or
   push the default branch.
6. **No self-merge.** A human is always the merge gate — open the PR and stop.
   PRs are not auto-merged.

The fastest way to satisfy all of the above is to let the pipeline open the PR
for you from inside the issue's worktree:

```bash
.sdlc/scripts/open-pr.sh <issue-number>
```

This pushes your branch, opens a PR with the disclaimer, `Closes #<n>`, the
acceptance criteria, and a commit summary, then relabels the issue to
`in-review` and comments the PR link back on the issue.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
