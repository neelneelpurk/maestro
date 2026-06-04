---
name: code-architecture-map
description: Map the codebase architecture — modules, seams, and dependencies — as docs/architecture-map.md plus an optional HTML report. Composes the improve-codebase-architecture skill and parallel Explore agents. Use for /sdlc:code-architecture-map.
---

# Code architecture map

Produce a navigable map of the codebase's structure — useful on its own and as input to `/sdlc:roadmap` and `/sdlc:code-feedback`.

## Steps
1. If the aihero **`improve-codebase-architecture`** skill is available, use it — it surveys modules, interfaces/seams, and depth, and writes a rich HTML report using `CONTEXT.md` vocabulary. 
2. Otherwise, fan out `Explore` subagents across the codebase to identify, per subsystem: its **modules** (interface + implementation), the **seams** where behaviour can be altered, and the key **dependencies** between them.
3. Synthesize:
   - **`docs/architecture-map.md`** — a concise map: each module's responsibility, its seam, notable dependencies, and a Mermaid diagram of the module graph.
   - Optionally a self-contained HTML report written to the temp dir and opened for the user.
4. Use `CONTEXT.md` domain vocabulary and respect `docs/adr/`. Flag friction and tech-debt hotspots (these feed `/sdlc:roadmap`).
5. Report where the map was written.
