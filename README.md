# ai-sdlc

> A downloadable, **multi-agent AI SDLC** for any GitHub repo.
>
> Post a PRD → align on the domain → break it into vertical-slice issues → fan out **one subagent per issue, in parallel** → each opens a PR. Built from skills, hooks, scripts, subagents, and loops.

This repo is a Claude Code **marketplace** (`ai-sdlc`) shipping one **plugin** (`sdlc`). The plugin adds the autonomous *orchestration / AFK layer* on top of the [aihero.dev](https://www.aihero.dev/skills) engineering skills — it picks up where `to-prd` / `to-issues` stop and drives issues all the way to pull requests.

## Pipeline

```
/sdlc:prd      conversation  ─▶  PRD issue                  (wraps aihero to-prd)
/sdlc:align    PRD           ─▶  sharpened CONTEXT.md+ADRs   (wraps aihero grill-with-docs)
/sdlc:issues   PRD           ─▶  vertical-slice issues       (wraps aihero to-issues)
/sdlc:ship     ready issues  ─▶  N parallel subagents        ─▶  one PR per issue   ← the new layer
/sdlc:drain    loop /sdlc:ship until the ready queue is empty
/sdlc:status   the board: issues ↔ branches ↔ PRs ↔ drain state
```

Each `/sdlc:ship` worker runs in its **own git worktree**, implements the issue test-first (aihero `tdd`), passes a **quality gate**, and opens a PR with `Closes #n`. It then **stops for human review** — there is no auto-merge.

## Install

```bash
# 1. Add this repo as a marketplace, then install the plugin
claude plugin marketplace add neelneelpurk/ai-sdlc      # or: add ./  (from a local checkout)
claude plugin install sdlc@ai-sdlc

# 2. RESTART Claude Code (or /reload-plugins) — required so the issue-implementer
#    agent type and /sdlc:* commands load (the agent registry is fixed at session start)

# 3. One-time setup in the repo you want to drive
/sdlc:init
```

> The marketplace is named `ai-sdlc`; the plugin inside it is named `sdlc` — which is why the commands are `/sdlc:*` and the install target is `sdlc@ai-sdlc`.

### Prerequisites

- [`gh`](https://cli.github.com/) authenticated with `repo` scope (`gh auth status`)
- `jq`
- The aihero.dev engineering skills (`to-prd`, `to-issues`, `grill-with-docs`, `triage`, `tdd`). `/sdlc:init` checks for these and tells you which, if any, are missing. (v1 composes them; bundled fallbacks are a follow-up.)

## Quickstart

```bash
/sdlc:init                     # labels, .sdlc/ runtime, PR template, prereq check
/sdlc:prd                      # turn the current conversation into a PRD issue
/sdlc:align <prd-issue>        # grill it against the domain model; write CONTEXT.md + ADRs
/sdlc:issues <prd-issue>       # break it into ready-for-agent vertical slices
/sdlc:ship                     # fan out: implement every ready issue → one PR each
# ...or run it unattended:
/sdlc:drain                    # keep shipping until the ready queue drains
/sdlc:status                   # see where everything sits
```

## Commands

| Command | What it does |
|---|---|
| `/sdlc:init` | One-time repo setup: triage + pipeline labels, `.sdlc/` runtime (scripts + config), `.gitignore`, PR template, prerequisite check. |
| `/sdlc:prd` | Synthesize a PRD from the conversation and publish it as a GitHub issue (labelled `prd`). |
| `/sdlc:align [prd#]` | HITL alignment gate — grill the PRD against the domain model; update `CONTEXT.md` + ADRs (the shared brief for all agents). |
| `/sdlc:issues <prd#>` | Break the PRD into `ready-for-agent` vertical-slice issues (`afk`/`hitl`, with `Blocked by`). |
| `/sdlc:ship [#…] [--max N]` | Implement every ready issue in parallel — one `issue-implementer` subagent + one PR per issue. |
| `/sdlc:drain [--max N \| stop \| status]` | Loop `/sdlc:ship` until the ready queue is empty. |
| `/sdlc:status` | The pipeline board: ready / blocked / in-progress / in-review / hitl, open PRs, drain status. |

## What's inside (the five building blocks)

| Block | Where | What |
|---|---|---|
| **Scripts** | `plugins/sdlc/scripts/` | bash + `gh` + `jq`: queue queries, worktrees, PRs, quality gate, init, status |
| **Subagents** | `plugins/sdlc/agents/` | `issue-implementer` — one spawned per issue, in parallel |
| **Skills** | `plugins/sdlc/skills/` | `align-agents`, `ship-ready-issues`, `implement-issue` |
| **Hooks** | `plugins/sdlc/hooks/` | drain-loop Stop hook + PR quality-gate / disclaimer PreToolUse hooks |
| **Loops** | `/sdlc:drain` + `schedules/` | ralph-style Stop-hook loop + a `/schedule`/cron routine for unattended draining |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design and rationale, and [CONTRIBUTING.md](CONTRIBUTING.md) to work on the plugin itself.

## Safety

- **Human is the merge gate** — the pipeline opens PRs and stops; it never auto-merges.
- **No red PRs** — `open-pr.sh` runs the quality gate and refuses to open a PR if it fails (a PreToolUse hook backstops manual `gh pr create`).
- **AI disclaimer** on every pipeline-posted issue/PR comment.
- **Isolation** — one git worktree + branch per issue; concurrency capped by `SDLC_MAX_PARALLEL`.

## Configuration

`/sdlc:init` writes `.sdlc/config.sh` (machine-local, gitignored). Override there:

```bash
SDLC_MAX_PARALLEL=3          # parallel implementers
SDLC_TEST_CMD="npm test"     # quality-gate steps (empty string skips a step)
SDLC_LINT_CMD=""             # also: SDLC_INSTALL_CMD, SDLC_TYPECHECK_CMD
# SDLC_LABEL_READY_AGENT=... # map triage roles to your existing label strings
```

## Credits

The front half of the workflow **composes** Matt Pocock's [aihero.dev engineering skills](https://www.aihero.dev/skills); the drain loop adapts Anthropic's `ralph-loop`. This plugin adds the autonomous multi-agent orchestration layer. See [NOTICE](NOTICE).

## License

MIT — see [LICENSE](LICENSE).
