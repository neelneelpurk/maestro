# Scheduled draining (unattended)

`/sdlc:drain` loops within a single session. To keep a repo's ready queue draining **over time** — as humans merge PRs and dependent issues unblock, or as new issues get triaged — run the pipeline on a schedule. The pipeline still awaits human review (it never auto-merges), so a scheduled run just opens PRs for whatever is currently ready.

## Option A — Claude Code routine (`/schedule`)

Use the `/schedule` skill to create a recurring remote agent. Suggested cadence: hourly or daily.

Paste this as the routine's prompt (edit `<repo path>`):

```
In <repo path>, run the ai-sdlc pipeline unattended:
1. cd into the repo.
2. Run /sdlc:ship — implement every ready-for-agent issue by fanning out one
   issue-implementer subagent per issue (each opens a PR). Do NOT merge anything.
3. Post the summary table of issues → PRs.
A human reviews and merges; you never merge.
```

## Option B — host cron + headless Claude Code

```cron
# Every hour, ship whatever is ready (PRs only; no merge).
0 * * * * cd /path/to/repo && claude -p "/sdlc:ship" >> .sdlc/cron.log 2>&1
```

Requires the `sdlc` plugin installed and `gh` authenticated for the cron user.

## Notes

- Because the pipeline awaits human review, each run ships only what's **currently** ready. An issue blocked on an unmerged PR is picked up on a later run, after the blocker merges.
- Keep `SDLC_MAX_PARALLEL` modest (2–3) on a schedule to stay within API/compute limits.
- Same safety on a schedule as interactively: a red quality gate ⇒ no PR, and nothing is ever auto-merged.
- To also auto-triage incoming issues first, prepend a `/triage` step (aihero) before `/sdlc:ship`.
