# ai-sdlc

> A downloadable, **multi-agent AI SDLC** for any GitHub repo.
>
> Post a PRD → align on the domain → break it into vertical-slice issues → fan out **one subagent per issue, in parallel** → each opens a PR. Built from skills, hooks, scripts, subagents, and loops.

This repo is a **Claude Code marketplace** (`ai-sdlc`) that ships a single **plugin** (`sdlc`). The plugin adds the autonomous *orchestration / AFK layer* on top of the [aihero.dev](https://www.aihero.dev/skills) engineering skills — it picks up where `to-prd` / `to-issues` stop and drives issues all the way to pull requests.

## The pipeline

```
/sdlc:prd      conversation  ─▶  PRD issue                 (wraps aihero `to-prd`)
/sdlc:align    PRD           ─▶  sharpened CONTEXT.md+ADRs  (wraps aihero `grill-with-docs`)
/sdlc:issues   PRD           ─▶  vertical-slice issues      (wraps aihero `to-issues`)
/sdlc:ship     ready issues  ─▶  N parallel subagents       ─▶  one PR per issue   ← the new part
/sdlc:drain    loop /sdlc:ship until the ready queue is empty
/sdlc:status   board: issues ↔ branches ↔ PRs ↔ state
```

Each `/sdlc:ship` worker runs in its **own git worktree**, implements the issue test-first (aihero `tdd`), passes a **quality gate**, and opens a PR with `Closes #<n>`. It then **stops for human review** — there is no auto-merge.

## Install

```bash
# Add this repo as a marketplace, then install the plugin
claude plugin marketplace add neelneelpurk/ai-sdlc      # or: add ./ (local checkout)
claude plugin install sdlc@ai-sdlc

# One-time setup in the repo you want to drive
/sdlc:init
```

> Note: the marketplace is named `ai-sdlc`; the plugin inside it is named `sdlc`, which is why commands are `/sdlc:*` and the install target is `sdlc@ai-sdlc`.

### Prerequisites

- [`gh`](https://cli.github.com/) authenticated with `repo` scope (`gh auth status`)
- `jq`
- The aihero.dev engineering skills installed (`to-prd`, `to-issues`, `grill-with-docs`, `triage`, `tdd`). `/sdlc:init` checks for these and tells you if any are missing. (v1 composes them; bundled fallbacks are a follow-up.)

## Quickstart

```bash
/sdlc:init                     # labels, docs/agents, PR template, .sdlc/ state
/sdlc:prd                      # turn the current conversation into a PRD issue
/sdlc:align <prd-issue>        # grill it against the domain model; write CONTEXT.md + ADRs
/sdlc:issues <prd-issue>       # break it into ready-for-agent vertical slices
/sdlc:ship                     # fan out: implement every ready issue → one PR each
# ...or run it unattended:
/sdlc:drain                    # keep shipping until the ready queue drains
```

## What's inside (the five building blocks)

| Block | Where | What |
|---|---|---|
| **Scripts** | `plugins/sdlc/scripts/` | deterministic bash + `gh` + `jq`: queue queries, worktrees, PRs, quality gate |
| **Subagents** | `plugins/sdlc/agents/` | `issue-implementer` — one spawned per issue, in parallel |
| **Skills** | `plugins/sdlc/skills/` | `align-agents`, `ship-ready-issues`, `implement-issue` |
| **Hooks** | `plugins/sdlc/hooks/` | drain-loop Stop hook + PR quality-gate / disclaimer PreToolUse hooks |
| **Loops** | `/sdlc:drain` + `schedules/` | ralph-style Stop-hook loop + cron routine for unattended draining |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design.

## Credits

The front half of the workflow is **inspired by and composes** Matt Pocock's [aihero.dev engineering skills](https://www.aihero.dev/skills). This plugin adds the autonomous multi-agent orchestration layer. See [NOTICE](NOTICE).

## License

MIT — see [LICENSE](LICENSE).
