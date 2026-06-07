---
name: share-implementation-plan
description: Draft a test-first implementation plan for a specific GitHub issue and post it as a comment on the issue (AI-disclaimer-led). A read-and-plan step only — it does NOT write code, create a branch, or open a PR. Use for /maestro:share_implementation_plan <issue>.
---

# Share an implementation plan

Draft a concrete, **test-first** implementation plan for ONE issue and post it as a
comment, so the approach is reviewable before any code is written. You do **not**
implement, branch, change labels, or open a PR.

## Input
An issue number (required). If none is given, ask which issue.

## Steps
1. **Locate scripts:** `cd "$(git rev-parse --show-toplevel)"; source .maestro/config.sh 2>/dev/null || true; S="${MAESTRO_SCRIPTS:-$(pwd)/.maestro/scripts}"`. If missing, ask the user to run `/maestro:init`.
2. **Read the issue and its context:** `gh issue view <n> --json title,body,labels,comments`. Read `CONTEXT.md` for the domain vocabulary and any relevant `docs/adr/` so the plan respects settled decisions. Skim the code the issue touches so the plan is grounded in the real structure (the seam you'll change, neighbouring patterns to match).
3. **Draft the plan.** Keep it a thin vertical slice — exactly what the issue asks; honor its "Out of scope". Include:
   - **Approach** — 2–5 sentences on the strategy and the seam you'll change.
   - **Decomposition checklist** — ordered `- [ ]` steps, each a small red→green→refactor increment (strict TDD: a failing test first, then the code that makes it pass).
   - **Tests** — the behaviours you'll test (external behaviour, not implementation details) and where they live.
   - **Files** — the main files you expect to add or change.
   - **Risks / open questions** — anything hard-to-reverse (note if it needs an ADR) or any decision you need the user to make.
4. **Post it as a comment** (the disclaimer is added for you): write the plan to a temp file and `bash "$S/issue-note.sh" <n> --body-file <file>`.
5. **Report:** link the issue, summarize the plan in 1–2 lines, and suggest `/maestro:ship <n>` (or `/maestro:drain`) to implement it — or `/maestro:plan-with-agent` if the issue still needs sharpening.

Do not change labels, create branches, run the quality gate, or open a PR — this skill only shares a plan.
