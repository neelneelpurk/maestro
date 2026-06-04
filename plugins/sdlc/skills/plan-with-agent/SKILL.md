---
name: plan-with-agent
description: Plan a feature with the user and publish a PRD — grill the idea against the domain model, sharpen terms into CONTEXT.md + ADRs, then synthesize and publish a PRD as a parent GitHub issue. Replaces separate align + prd steps. Use for /sdlc:plan-with-agent.
---

# Plan with agent

The planning gate: reach genuine shared understanding with the user, capture the language and decisions, then publish a PRD that `/sdlc:issues` will break down. Its output (`CONTEXT.md` + ADRs) is the shared brief every later worker inherits.

## 1. Grill — one question at a time
Interview the user about the feature until you reach shared understanding, walking each branch of the decision tree and giving your recommended answer for each question. Ask **one at a time** and wait. If a question can be answered by reading the code, read the code. If the aihero **`grill-with-docs`** skill is available, use it; otherwise follow the practice with the bundled formats: [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md), [ADR-FORMAT.md](ADR-FORMAT.md).

During the session:
- **Challenge the glossary** when a term conflicts with `CONTEXT.md`; **sharpen** fuzzy/overloaded terms into canonical ones; **probe with concrete scenarios**; **cross-check** claims against the code.
- Update **`CONTEXT.md`** immediately as terms resolve (glossary only — no implementation detail). Offer an **ADR** only when the decision is hard to reverse, surprising without context, and a real trade-off.

## 2. Publish the PRD
Synthesize a PRD (Problem Statement, Solution, User Stories, Implementation Decisions, Testing Decisions, Out of Scope). If the aihero **`to-prd`** skill is available, use it to publish; otherwise create the issue directly. Publish as a GitHub issue labelled **`prd`** (the parent epic), assigned `@me`. Do **not** label it `ready-for-agent` — a PRD is a parent, not an implementable slice.

## 3. Next
Recommend `/sdlc:issues <prd-issue>` to break the PRD into sub-issues with native dependencies.
