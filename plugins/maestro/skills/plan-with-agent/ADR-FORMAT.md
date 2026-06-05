# ADR format (Michael Nygard)

An Architecture Decision Record captures one significant decision and why it was made. Record one only when **all three** hold: hard to reverse, surprising without context, and the result of a real trade-off. If any is missing, skip the ADR.

## Location & naming
`docs/adr/NNNN-short-title.md`, zero-padded and sequential (`0001`, `0002`, …). In a multi-context repo, context-specific ADRs live under that context; system-wide ones at the root `docs/adr/`.

## Shape
```markdown
# 1. Record architecture decisions

Date: YYYY-MM-DD

## Status
Accepted   <!-- Proposed | Accepted | Superseded by ADR-000N -->

## Context
The forces at play — what's true, what's constrained, what's in tension. No solution yet.

## Decision
The decision, in active voice: "We will …".

## Consequences
What becomes easier and what becomes harder as a result — including the downsides we knowingly accept.
```
