---
name: roadmap
description: Think like a product manager to decide what to build next — find the missing features and tech-debt from user value and gaps vs. what's already implemented, prioritize them, and create issues under a roadmap parent + milestone. Optionally steered by a goal + context. Use for /maestro:roadmap (and inside /maestro:auto).
---

# Roadmap

Act as the **product manager** for this project: figure out what's most worth building next, then turn it into issues the pipeline can pick up.

## 0. Goal & context (optional)
The caller may pass a freeform **goal** — the objective this iteration should serve — and **context**: supporting notes, file paths, or links, separated from the goal by ` -- ` (e.g. `payments retries -- docs/adr/0007-payments.md, ask ops about the timeout budget`). If given:
- The goal **replaces open-ended gap-hunting as the driver** for step 2 — propose only items that materially advance it (still grounded in what already exists, so you don't re-propose shipped work or contradict it).
- Read the context inputs (files verbatim, notes as-is) as authoritative, alongside `CONTEXT.md`/ADRs — they outrank your own inference when they conflict.
- In step 5, report explicitly whether the goal is now **fully covered** by open + already-shipped work, or what's still missing — the caller (e.g. `/maestro:auto`) uses this to decide whether to keep looping.

If no goal is given, fall back to the general PM analysis below.

## 1. Understand what exists
Locate scripts (`source .maestro/config.sh; S="${MAESTRO_SCRIPTS:-$(pwd)/.maestro/scripts}"`). Run `bash "$S/implemented-summary.sh"` (merged PRs, closed issues, open PRs, milestones). Read `CONTEXT.md`, `docs/adr/`, `README`, and `docs/architecture-map.md` if present. For a larger codebase, fan out `Explore` subagents to learn the current capabilities and surface gaps.

## 2. Think like a PM
- **Who is the user and what are their jobs-to-be-done?** What outcome are they trying to achieve?
- **Where are the gaps?** Compare the jobs-to-be-done (or the given goal) against what's already implemented (don't re-propose shipped/closed work). Look for: missing steps in a core flow, rough edges/usability gaps, table-stakes/parity features that are absent, reliability/observability gaps, and **tech-debt** that's slowing delivery.
- **Prioritize** by rough **impact vs. effort** (reach × value ÷ effort) and dependencies — what unlocks the most, soonest. Be explicit about why each item matters and what you're deliberately *not* doing yet.

## 3. Propose & confirm
Present a short, prioritized roadmap: each item as a thin vertical slice with a one-line rationale (user value, or how it serves the given goal) and clear acceptance criteria. **Confirm with the user** before creating issues — UNLESS invoked by `/maestro:auto`, which proceeds autonomously.

## 4. Create the issues
- A roadmap parent issue (label `agent:roadmap`) and a milestone (`gh api --method POST repos/<repo>/milestones -f title=...`), assigned `@me`. If a goal was given, put it in the parent issue's body verbatim so it's the audit trail for why these issues exist.
- One child per item, assigned `@me`, labelled `agent:ready-for-agent` (add **`agent:auto`** when invoked by `/maestro:auto`; add `agent:tech-debt` for debt; `agent:enhancement`/`agent:bug` as apt).
- Link each child as a sub-issue: `bash "$S/subissue.sh" add <parent> <child>`; set dependencies: `bash "$S/dependency.sh" add <issue> <blocker>`.

## 5. Report
Show the roadmap parent + children with their rationale. If a goal was given, state plainly whether it's now fully covered or what remains. Recommend `/maestro:drain` (chained automatically by `/maestro:auto`).
