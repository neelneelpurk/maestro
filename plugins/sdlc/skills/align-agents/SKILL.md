---
name: align-agents
description: Alignment gate before parallel fan-out — grill the PRD/plan against the domain model, sharpen terminology into CONTEXT.md, and capture hard-to-reverse decisions as ADRs. Use after /sdlc:prd and before /sdlc:issues so every issue-implementer subagent shares the same language and decisions.
---

# Align Agents

The human-in-the-loop alignment gate. Stress-test the plan/PRD against the project's domain model and **leave behind a shared brief — `CONTEXT.md` (glossary) + ADRs (decisions) — that every parallel `issue-implementer` reads before coding.** This is what keeps a multi-agent fan-out coherent: no two subagents inventing different words for the same concept, and no subagent re-deciding something already settled.

If the aihero **`grill-with-docs`** skill is installed, prefer invoking it — this skill is a thin, pipeline-framed wrapper around the same practice. Otherwise follow the procedure below using the bundled formats: [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md) and [ADR-FORMAT.md](ADR-FORMAT.md).

## Input
A PRD issue number/URL (read it with `gh issue view <n> --json title,body,comments`), or the current conversation if none is given.

## Optionally gather material in parallel (multi-agent)
Before grilling, you may fan out **read-only** subagents to assemble what you'll grill against — they explore concurrently while you stay single-threaded with the user:
- one maps the existing `CONTEXT.md` glossary terms,
- one greps the codebase for terms that conflict with how the PRD uses them,
- one surveys `docs/adr/` for decisions the PRD might contradict.

Use their findings to ask sharper questions. Skip this for small or greenfield work.

## Grill — one question at a time
Interview the user relentlessly about the plan until you reach shared understanding. Walk each branch of the decision tree, resolving dependencies one at a time. For each question, give your recommended answer. **Ask one question at a time and wait** for the answer. If a question can be answered by reading the code, read the code instead of asking.

During the session:
- **Challenge the glossary.** If a term conflicts with `CONTEXT.md`, call it out: "the glossary defines X as A, but you seem to mean B — which is it?"
- **Sharpen fuzzy language.** For an overloaded word, propose a precise canonical term ("'account' — do you mean Customer or User? They're different things").
- **Probe with scenarios.** Invent concrete edge cases that force precise boundaries between concepts.
- **Cross-check with code.** If a stated behavior contradicts the code, surface the contradiction.

## Capture as you go (don't batch)
- When a term resolves, update **`CONTEXT.md`** immediately ([CONTEXT-FORMAT.md](CONTEXT-FORMAT.md)). `CONTEXT.md` is a **glossary only** — no implementation details, no spec, no scratch notes.
- Offer an **ADR** only when all three hold: hard to reverse, surprising without context, and the result of a real trade-off. Otherwise skip it ([ADR-FORMAT.md](ADR-FORMAT.md)).
- Create files lazily — only when you actually have a term or decision to record. Respect a `CONTEXT-MAP.md` (multi-context repo) if one exists.

## Done
You're aligned when the PRD's language matches `CONTEXT.md` and no open decision blocks breaking it into slices. Recommend `/sdlc:issues <prd>` next — the slices, and the agents that implement them, inherit this shared brief.
