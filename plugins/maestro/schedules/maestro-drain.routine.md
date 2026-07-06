# Scheduled / unattended runs

`/maestro:drain` and `/maestro:auto` already self-pace within a session (background workers + `/loop`/`ScheduleWakeup`). To keep a repo moving **over time** — across human reviews of integration PRs, or to continuously generate and land work — run the pipeline on a schedule. It still never merges the integration PR; that stays your gate.

## Option A — Claude Code routine (`/schedule` or `/loop`)

- Continuous, self-paced, in your session: `/loop /maestro:auto [goal] -- [context]` (roadmap → drain, repeatedly, optionally steered by a goal) or `/loop /maestro:drain` (just keep draining the ready queue).
- Recurring remote agent: use the `/schedule` skill with a prompt like:

```
In <repo path>, run the maestro pipeline unattended:
1. /maestro:drain   — land every ready issue onto a fresh integration branch (per-issue PRs auto-merge; the integration PR is NOT merged).
2. Report the integration PR for human review.
Never merge the integration PR or the default branch.
```

For a fully autonomous build loop, use `/maestro:auto` instead of `/maestro:drain`.

## Option B — host cron + headless Claude Code

```cron
# Hourly: drain the ready queue onto an integration branch (no merge to default).
0 * * * * cd /path/to/repo && claude -p "/maestro:drain" >> .maestro/cron.log 2>&1
```

Requires the `maestro` plugin installed and `gh` authenticated for the cron user.

## Notes
- Each run opens (or reuses) one integration PR — your single review gate. Merge it when you're happy, then `/maestro:status close-integrated`.
- Keep `MAESTRO_MAX_PARALLEL` modest (2–3) on a schedule to stay within API/compute limits.
- `agent:auto`-labelled issues skip the `agent:ready-for-agent` gate, so scheduled `/maestro:auto` runs need no human triage to proceed.
