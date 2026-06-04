# ai-sdlc architecture

## What it is

`ai-sdlc` is a Claude Code **plugin** (`sdlc`) distributed from a single-repo **marketplace** (`ai-sdlc`). It adds the autonomous *orchestration / AFK layer* on top of the [aihero.dev](https://www.aihero.dev/skills) engineering skills: it picks up where `to-prd` / `to-issues` stop and drives `ready-for-agent` issues all the way to pull requests — **one subagent per issue, in parallel**.

```
/sdlc:prd     conversation ─▶ PRD issue (label: prd)            [wraps aihero to-prd]
/sdlc:align   PRD          ─▶ sharpened CONTEXT.md + ADRs        [wraps aihero grill-with-docs]
/sdlc:issues  PRD          ─▶ vertical-slice issues (afk|hitl, Blocked by)  [wraps aihero to-issues]
/sdlc:ship    ready issues ─▶ N parallel issue-implementer subagents ─▶ one PR each   ← the new layer
/sdlc:drain   loop /sdlc:ship until the ready queue is empty
/sdlc:status  the board: issues ↔ branches ↔ PRs ↔ drain state
```

Each worker runs in its **own git worktree**, implements test-first (aihero `tdd`), passes a **quality gate**, opens a PR with `Closes #n`, relabels the issue `in-review`, and **stops for human review** — there is no auto-merge.

## The five building blocks

| Block | Where | Role |
|---|---|---|
| **Scripts** | `plugins/sdlc/scripts/` | deterministic bash + `gh` + `jq`: `lib.sh`, `ensure-labels.sh`, `ready-issues.sh`, `blocked-by.sh`, `make-worktree.sh`, `quality-gate.sh`, `open-pr.sh`, `init.sh`, `status.sh`, `drain-control.sh` |
| **Subagents** | `plugins/sdlc/agents/issue-implementer.md` | the parallel unit — one spawned per issue by the orchestrator |
| **Skills** | `plugins/sdlc/skills/` | `align-agents` (gate), `ship-ready-issues` (fan-out), `implement-issue` (worker) |
| **Hooks** | `plugins/sdlc/hooks/` | `drain-stop-hook.sh` (Stop), `pr-quality-gate.sh` + `ai-disclaimer-guard.sh` (PreToolUse) |
| **Loops** | `/sdlc:drain` + `schedules/` | ralph-style Stop-hook loop + a cron/`/schedule` routine for unattended draining |

## Key design decisions

- **Plugin in a subdir, `/sdlc` namespace.** Marketplace `ai-sdlc` lists plugin `sdlc` at `./plugins/sdlc` (a marketplace `source` of `"."` is not supported). The slash-command namespace is the *plugin name*, so the plugin is named `sdlc` → `/sdlc:*`, installed as `sdlc@ai-sdlc`.
- **`.sdlc/` is machine-local runtime, referenced by absolute path.** `/sdlc:init` installs the scripts to `.sdlc/scripts/` and writes `.sdlc/config.sh` with an **absolute** `SDLC_SCRIPTS`. Workers run inside a worktree (a fresh checkout of the default branch that does *not* contain the gitignored `.sdlc/`), so they call scripts by absolute path. `lib.sh` resolves `config.sh` relative to its own location, so config loads correctly regardless of cwd. The whole `.sdlc/` dir is gitignored.
- **Worktree per issue.** `make-worktree.sh` puts each issue on its own `sdlc/issue-<n>-<slug>` branch in a sibling worktree dir, so parallel workers never collide and each produces an independent PR.
- **Await review, never auto-merge.** Workers and the orchestrator are instructed never to merge; the human is the merge gate. (A blanket merge-blocking hook is intentionally avoided, since the user legitimately asks Claude to merge reviewed PRs.)
- **The quality gate is enforced in `open-pr.sh`** (authoritative: red gate ⇒ no PR), with a PreToolUse backstop (`pr-quality-gate.sh`) for *manual* `gh pr create`. The gate auto-detects the toolchain and is overridable per repo via `SDLC_*_CMD` in `.sdlc/config.sh`.
- **Drain loop is queue-based and session-claimed.** The Stop hook re-feeds the ship prompt while `.sdlc/drain.local.md` exists, stopping when `ready-issues.sh --count` is 0 or `max_iterations` is hit. The first session whose Stop fires claims the loop (by `session_id`), so it won't hijack other sessions in the same repo. (Adapted from the official ralph-loop hook.)
- **Workers re-assert live state.** GitHub's label search is eventually consistent, so the orchestrator's snapshot can be stale. Every worker re-checks (open ∧ `ready-for-agent`+`afk` ∧ no open blockers) before doing anything, and stops harmlessly if the issue is no longer workable.
- **Compose, don't vendor.** The front half *uses* the installed aihero skills; `/sdlc:init` checks for them and points to install if missing. Bundled fallbacks (e.g. `align-agents` can run grilling without `grill-with-docs`) keep the core usable, but full standalone vendoring is a follow-up.

## Important operational caveat

The **agent registry is fixed at session start.** After installing the plugin, you must **restart Claude Code (or `/reload-plugins`)** before `/sdlc:ship` can spawn `issue-implementer` subagents (and before `/sdlc:*` commands appear).

## Dependency waves

`to-issues` records dependencies in each issue's `## Blocked by` section as `#n` references. `ready-issues.sh` only returns issues whose blockers are all closed, so `/sdlc:ship` works the current runnable wave. As humans merge PRs (closing issues), dependents unblock and are picked up by the next `/sdlc:ship`, `/sdlc:drain`, or scheduled run.

## Extension points

- **Quality gate** — `SDLC_INSTALL_CMD` / `SDLC_LINT_CMD` / `SDLC_TYPECHECK_CMD` / `SDLC_TEST_CMD` in `.sdlc/config.sh` (empty string skips a step).
- **Concurrency** — `SDLC_MAX_PARALLEL`.
- **Label vocabulary** — the `SDLC_LABEL_*` vars in `lib.sh` / `.sdlc/config.sh` (map to existing repo labels).
- **Issue tracker** — v1 targets GitHub via `gh`; `lib.sh` centralizes repo/label access as the seam for other trackers.
