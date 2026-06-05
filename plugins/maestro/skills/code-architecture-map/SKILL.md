---
name: code-architecture-map
description: Map the codebase architecture — modules, seams, and dependencies — to docs/architecture-map.md plus an optional HTML report. Use for /maestro:code-architecture-map.
---

# Code architecture map

Produce a navigable map of the codebase's structure — useful on its own and as input to `/maestro:roadmap` and `/maestro:review`.

## Vocabulary (use consistently)
- **Module** — anything with an interface and an implementation (function, class, package).
- **Interface** — everything a caller must know to use it: types, invariants, error modes, ordering, config.
- **Seam** — where an interface lives; a place behaviour can be changed without editing in place.
- **Depth** — a lot of behaviour behind a small interface (deep = high leverage; shallow = interface nearly as complex as the implementation).
- **Deletion test** — if you imagine deleting a module and the complexity vanishes, it was a pass-through; if it reappears across callers, it was earning its keep.

## Steps
1. Fan out **`Explore`** subagents across the codebase (one per subsystem/top-level area). Each identifies, for its area: the modules and their interfaces/seams, the key dependencies in and out, and where it feels shallow or tightly coupled.
2. Synthesize **`docs/architecture-map.md`**: per module — responsibility, its seam, notable dependencies; plus a Mermaid diagram of the module graph and a short "friction & tech-debt hotspots" section (apply the deletion test).
3. Optionally also write a self-contained HTML report (Tailwind + Mermaid via CDN) to the OS temp dir and open it; tell the user the path.
4. Use `CONTEXT.md` domain vocabulary and respect `docs/adr/`.
5. Report where the map was written. Flag hotspots so they can feed `/maestro:roadmap`.
