# CONTEXT.md format

`CONTEXT.md` is the project's **glossary** — the canonical name and a precise one-line definition for each domain concept. It exists so that humans and (especially) parallel agents use the same word for the same thing.

## Rules
- **Glossary only.** No implementation details, no architecture, no task lists, no spec. Those belong in ADRs, issues, or the code.
- **One entry per concept.** Canonical term as the heading; a precise one- or two-sentence definition.
- Note important distinctions and synonyms ("not to be confused with …", "aka …").
- Keep entries short. If one grows into prose, it's probably a *decision* → move it to an ADR.
- Create it lazily — write the first entry the moment a term is resolved.

## Shape
```markdown
# Glossary

## Customer
A person who holds one or more Accounts. Distinct from **User** (a login identity);
one Customer may map to several Users.

## Cancellation
Voiding an entire Order before fulfilment. A partial void is a **Return**, not a Cancellation.
```
