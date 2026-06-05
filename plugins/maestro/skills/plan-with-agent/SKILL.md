---
name: plan-with-agent
description: Plan a feature with the user and publish a PRD — grill the idea against the domain model, sharpen terms into CONTEXT.md + ADRs, then synthesize and publish a PRD as a parent GitHub issue. Use for /maestro:plan-with-agent.
---

# Plan with agent

The planning gate: reach genuine shared understanding with the user, capture the language and decisions, then publish a PRD that `/maestro:issues` breaks down. Its output (`CONTEXT.md` + ADRs) is the shared brief every later worker inherits.

## 1. Grill — one question at a time
Interview the user about the feature until you reach shared understanding. Walk each branch of the decision tree, resolving dependencies one at a time, and give your recommended answer for each question. **Ask one question at a time and wait.** If a question can be answered by reading the code, read the code instead of asking.

During the session:
- **Challenge the glossary.** If a term conflicts with `CONTEXT.md`, call it out: "the glossary defines X as A, but you seem to mean B — which is it?"
- **Sharpen fuzzy language.** For an overloaded word, propose a precise canonical term ("'account' — Customer or User? They're different things").
- **Probe with concrete scenarios** that force precise boundaries between concepts.
- **Cross-check with code.** If a stated behaviour contradicts the code, surface it.

Capture as you go (don't batch): when a term resolves, update **`CONTEXT.md`** immediately — glossary only, no implementation detail ([CONTEXT-FORMAT.md](CONTEXT-FORMAT.md)). Offer an **ADR** only when the decision is hard to reverse, surprising without context, and a real trade-off ([ADR-FORMAT.md](ADR-FORMAT.md)). Create files lazily.

## 2. Publish the PRD
Synthesize a PRD from the conversation and codebase understanding (do not re-interview — use what you now know) with these sections:
- **Problem Statement** — the user's problem, from their perspective.
- **Solution** — the solution, from the user's perspective.
- **User Stories** — an extensive numbered list ("As an <actor>, I want <feature>, so that <benefit>").
- **Implementation Decisions** — modules/interfaces to build or change, schema/API contracts, architectural choices. No file paths or code (they go stale).
- **Testing Decisions** — what to test (external behaviour), at which seams, and prior art in the codebase.
- **Out of Scope** — what this PRD deliberately excludes.

Use the PRD template structure (also seeded at `.github/ISSUE_TEMPLATE/prd.md`). Publish it as a GitHub issue labelled **`maestro:prd`** (the parent epic), assigned `@me`. Do **not** label it `maestro:ready-for-agent` — a PRD is a parent, not an implementable slice.

## 3. Next
Recommend `/maestro:issues <prd-issue>` to break the PRD into sub-issues with native dependencies.
