# Scheduled / unattended runs

`/sdlc:drain` and `/sdlc:auto` already self-pace within a session (background workers + `/loop`/`ScheduleWakeup`). To keep a repo moving **over time** — across human reviews of integration PRs, or to continuously generate and land work — run the pipeline on a schedule. It still never merges the integration PR; that stays your gate.

## Option A — Claude Code routine (`/schedule` or `/loop`)

- Continuous, self-paced, in your session: `/loop /sdlc:auto` (roadmap → drain, repeatedly) or `/loop /sdlc:drain` (just keep draining the ready queue).
- Recurring remote agent: use the `/schedule` skill with a prompt like:

```
In <repo path>, run the ai-sdlc pipeline unattended:
1. /sdlc:drain   — land every ready issue onto a fresh integration branch (per-issue PRs auto-merge; the integration PR is NOT merged).
2. Report the integration PR for human review.
Never merge the integration PR or the default branch.
```

For a fully autonomous build loop, use `/sdlc:auto` instead of `/sdlc:drain`.

## Option B — host cron + headless Claude Code

```cron
# Hourly: drain the ready queue onto an integration branch (no merge to default).
0 * * * * cd /path/to/repo && claude -p "/sdlc:drain" >> .sdlc/cron.log 2>&1
```

Requires the `sdlc` plugin installed and `gh` authenticated for the cron user.

## Notes
- Each run opens (or reuses) one integration PR — your single review gate. Merge it when you're happy, then `/sdlc:status close-integrated`.
- Keep `SDLC_MAX_PARALLEL` modest (2–3) on a schedule to stay within API/compute limits.
- `auto`-labelled issues skip the `ready-for-agent` gate, so scheduled `/sdlc:auto` runs need no human triage to proceed.
