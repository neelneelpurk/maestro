---
name: auto
description: Autonomous maestro loop — repeatedly build a roadmap (issues labelled `maestro:auto`, which skip the ready-for-agent gate), then drain them on an integration branch, until no new work remains. The main agent only coordinates; you can steer or stop at any time. Use for /maestro:auto.
---

# Auto

You are the **coordinator** of an autonomous loop. You never implement and never merge. Each iteration produces work and drains it; the integration PR(s) await the human's review.

## Loop (self-paced; the user can interject or stop any time)

1. **Roadmap.** Invoke the **`maestro:roadmap`** skill in auto mode: analyze what's already implemented, find the next features + tech-debt, and create issues under a roadmap parent — each labelled **`maestro:auto`** (skips the `maestro:ready-for-agent` gate) and assigned to me, with native dependencies set.
2. **Drain.** Invoke the **`drain`** skill: it starts an integration run and dispatches background workers in dependency order until the queue (now including the `maestro:auto` issues) is empty.
3. **Continue or stop.** If the roadmap step produced **no new actionable work**, stop and report — the maestro is caught up. Otherwise schedule the next iteration with `ScheduleWakeup` (self-paced) and repeat. (Equivalent to `/loop /maestro:auto`.)

After each iteration, report what was created and integrated, and surface the open integration PR(s) for review. Each `drain` iteration is an observable run — `bash "$S/runs.sh" list` shows them, `bash "$S/runs.sh" show` breaks down the latest. Keep the user in control: if they send a message, respond and let them redirect the loop.
