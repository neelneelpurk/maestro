---
description: Align on domain language and decisions before breaking down work — grill the PRD, update CONTEXT.md + ADRs.
argument-hint: "[prd-issue# | URL]"
---

Use the **align-agents** skill to stress-test the plan/PRD against this project's domain model: challenge fuzzy or conflicting terms, sharpen them into a canonical glossary in `CONTEXT.md`, and capture genuinely hard-to-reverse decisions as ADRs under `docs/adr/`.

Target: `$ARGUMENTS` — a PRD issue number/URL to grill, or the current conversation if omitted.

This is the human-in-the-loop alignment gate that runs **after `/sdlc:prd` and before `/sdlc:issues`**. Its output (`CONTEXT.md` + ADRs) becomes the shared brief that every parallel `issue-implementer` reads, which is what keeps the fan-out from drifting on terminology or re-deciding settled questions.
