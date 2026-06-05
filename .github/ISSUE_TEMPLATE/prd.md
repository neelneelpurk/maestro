---
name: PRD
about: Product requirements (parent epic); usually created by /sdlc:plan-with-agent
labels: prd
---

<!-- PRD (parent epic). Authored by /sdlc:plan-with-agent. Keep it behavioural —
     no file paths or code snippets (they go stale). -->

## Problem Statement
The problem the user faces, from the user's perspective.

## Solution
The solution, from the user's perspective.

## User Stories
An extensive, numbered list:
1. As a `<actor>`, I want `<feature>`, so that `<benefit>`.

## Implementation Decisions
Modules/interfaces to build or change, schema and API contracts, and
architectural choices. Use the canonical `CONTEXT.md` vocabulary.

## Testing Decisions
What to test (external behaviour, not implementation details), at which seams,
and prior art for the tests in this codebase.

## Out of Scope
What this PRD deliberately excludes.
