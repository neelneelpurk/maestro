---
name: roadmap
description: Think like a product manager to decide what to build next — find the missing features and tech-debt from user value and gaps vs. what's already implemented, prioritize them, and create issues under a roadmap parent + milestone. Use for /sdlc:roadmap (and inside /sdlc:auto).
---

# Roadmap

Act as the **product manager** for this project: figure out what's missing and what's most worth building next, then turn it into issues the pipeline can pick up.

## 1. Understand what exists
Locate scripts (`source .sdlc/config.sh; S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"`). Run `bash "$S/implemented-summary.sh"` (merged PRs, closed issues, open PRs, milestones). Read `CONTEXT.md`, `docs/adr/`, `README`, and `docs/architecture-map.md` if present. For a larger codebase, fan out `Explore` subagents to learn the current capabilities and surface gaps.

## 2. Think like a PM
- **Who is the user and what are their jobs-to-be-done?** What outcome are they trying to achieve?
- **Where are the gaps?** Compare the jobs-to-be-done against what's already implemented (don't re-propose shipped/closed work). Look for: missing steps in a core flow, rough edges/usability gaps, table-stakes/parity features that are absent, reliability/observability gaps, and **tech-debt** that's slowing delivery.
- **Prioritize** by rough **impact vs. effort** (reach × value ÷ effort) and dependencies — what unlocks the most, soonest. Be explicit about why each item matters and what you're deliberately *not* doing yet.

## 3. Propose & confirm
Present a short, prioritized roadmap: each item as a thin vertical slice with a one-line rationale (user value) and clear acceptance criteria. **Confirm with the user** before creating issues — UNLESS invoked by `/sdlc:auto`, which proceeds autonomously.

## 4. Create the issues
- A roadmap parent issue (label `roadmap`) and a milestone (`gh api --method POST repos/<repo>/milestones -f title=...`), assigned `@me`.
- One child per item, assigned `@me`, labelled `ready-for-agent` (add **`auto`** when invoked by `/sdlc:auto`; add `tech-debt` for debt; `enhancement`/`bug` as apt).
- Link each child as a sub-issue: `bash "$S/subissue.sh" add <parent> <child>`; set dependencies: `bash "$S/dependency.sh" add <issue> <blocker>`.

## 5. Report
Show the roadmap parent + children with their rationale. Recommend `/sdlc:drain` (chained automatically by `/sdlc:auto`).
