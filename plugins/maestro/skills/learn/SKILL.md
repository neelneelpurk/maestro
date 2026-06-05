---
name: learn
description: Capture a correction as a durable, persisted learning so the agent does not repeat the mistake. Use when the user corrects the agent or teaches a rule — "don't do X", "always Y", "that's wrong, do Z", "stop doing…", "next time…".
---

# Learn (persist a correction as memory)

When the user corrects you or teaches a rule, turn it into a **durable learning** persisted to `.claude/rules/learnings.md`. That file is committed and **inherited by every agent — including the parallel workers, inside their worktrees** — so the correction sticks across sessions and the mistake isn't repeated.

## Steps
1. **Identify the lesson** from the recent conversation: what went wrong (or the rule the user stated) and the correct behaviour. Generalize it just enough to apply next time — not the one-off specifics.
2. **Confirm the phrasing** with the user in one line (the rule you're about to persist), unless it's obvious from an explicit instruction.
3. **Persist it:**
   ```
   source .maestro/config.sh 2>/dev/null || true; S="${MAESTRO_SCRIPTS:-$(pwd)/.maestro/scripts}"
   bash "$S/learn-note.sh" "<the rule>"
   ```
   Phrase each learning as one or two imperative sentences ("Always …", "Never …", "When X, do Y").
4. **Confirm** it's persisted and that future agents (and workers) will follow it.

## Notes
- Keep learnings **durable and behavioural** — skip ephemeral ones ("not right now") and never store secrets.
- If the correction is about **domain language**, also update `CONTEXT.md`; if it's a **hard-to-reverse decision**, offer an ADR.
- Periodically prune/merge duplicates in `learnings.md` so it stays high-signal.
