---
name: auto
description: Autonomous maestro loop harness — repeatedly build a roadmap (issues labelled `agent:auto`, which skip the ready-for-agent gate), then drain them on an integration branch, until no new work remains or a given goal is met. Optionally steered by a freeform goal + context, passed straight through each iteration. The main agent only coordinates; you can steer or stop at any time. Use for /maestro:auto.
---

# Auto

You are the **coordinator** of an autonomous loop. You never implement and never merge. Each iteration produces work and drains it; the integration PR(s) await the human's review.

## 0. Goal & context (optional)
The caller may pass `$ARGUMENTS` as `<goal> [-- context]` — a freeform objective for this loop (e.g. "harden auth against session fixation") plus optional supporting notes/paths/links after ` -- `. If present, hold them **verbatim** and forward the whole `$ARGUMENTS` string unchanged to the `roadmap` skill on **every** iteration (step 1) — the goal is the loop's steering input, not a one-shot hint, since later iterations still need it to judge what's left. If `$ARGUMENTS` is empty, the loop runs in its original default mode: infer gaps from the codebase each iteration, with no fixed objective.

## Loop (self-paced; the user can interject or stop any time)

1. **Roadmap.** Invoke the **`maestro:roadmap`** skill in auto mode, passing the goal/context from step 0 if given: analyze what's already implemented, find the next work items (scoped to the goal when one was given), and create issues under a roadmap parent — each labelled **`agent:auto`** (skips the `agent:ready-for-agent` gate) and assigned to me, with native dependencies set.
2. **Drain.** Invoke the **`drain`** skill, telling it the same goal so it titles the integration PR accordingly (`integration.sh start <goal>`): it starts an integration run and dispatches background workers in dependency order until the queue (now including the `agent:auto` issues) is empty.
3. **Continue or stop.** Stop and report when either applies: (a) no goal was given and the roadmap step produced **no new actionable work** — the maestro is caught up; or (b) a goal was given and the roadmap step reports it's **fully covered** by shipped + open work. Otherwise schedule the next iteration with `ScheduleWakeup` (self-paced), passing the same goal/context again, and repeat. (Equivalent to `/loop /maestro:auto <goal> -- <context>`.)

After each iteration, report what was created and integrated, and surface the open integration PR(s) for review. Each `drain` iteration is an observable run — `bash "$S/runs.sh" list` shows them, `bash "$S/runs.sh" show` breaks down the latest. Keep the user in control: if they send a message, respond and let them redirect the loop (including changing the goal for the next iteration).
