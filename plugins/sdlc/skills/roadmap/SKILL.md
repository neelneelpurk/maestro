---
name: roadmap
description: Build an autonomous product roadmap from what's already implemented — analyze merged PRs, closed issues, the code, and the architecture map; propose next features and tech-debt; create issues under a roadmap parent + milestone. Use for /sdlc:roadmap (and inside /sdlc:auto).
---

# Roadmap

Decide what to build next from the current state of the repo, and turn it into issues the pipeline can pick up.

## Steps

1. Locate scripts: `cd "$(git rev-parse --show-toplevel)"; source .sdlc/config.sh 2>/dev/null || true; S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"`.
2. **Assess what's done:** `bash "$S/implemented-summary.sh"` (merged PRs, closed issues, open PRs, milestones). Read `CONTEXT.md`, `docs/adr/`, and `docs/architecture-map.md` if present. For a larger codebase, fan out `Explore` subagents to map subsystems and surface gaps and tech-debt hotspots.
3. **Propose the next slice:** a short, prioritized list of features + tech-debt items that build on what already exists (do not duplicate merged/closed work). Each item is a thin vertical slice with clear acceptance criteria.
4. **Confirm** with the user — UNLESS invoked by `/sdlc:auto`, which proceeds autonomously.
5. **Create the issues:**
   - A roadmap parent issue (label `roadmap`) and a milestone (`gh api --method POST repos/<repo>/milestones -f title=...`). Assign the parent to `@me`.
   - One child issue per item, assigned `@me`, labelled `ready-for-agent` (add **`auto`** when invoked by `/sdlc:auto`; add `tech-debt` for debt; `enhancement`/`bug` as apt).
   - Link each child as a sub-issue: `bash "$S/subissue.sh" add <parent> <child>`.
   - Set dependencies between children: `bash "$S/dependency.sh" add <issue> <blocker>`.
6. **Report** the roadmap parent + children. Recommend `/sdlc:drain` (or it is chained automatically by `/sdlc:auto`).
