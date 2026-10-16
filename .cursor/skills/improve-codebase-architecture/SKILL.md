---
name: improve-codebase-architecture
description: Find shallow modules and deepening opportunities in the Swift package, informed by CONTEXT.md and Docs/adr. Use to review architecture, consolidate coupled modules or make the code more testable for agents.
---

# Improve codebase architecture

A deep module has a small interface hiding substantial behavior. A shallow module's interface is nearly as complex as its implementation. Deep modules are easier for humans and agents to navigate, test and change.

## Process

1. Read `CONTEXT.md` and `Docs/adr/`. Do not re-litigate a decision recorded there unless the friction is real; if so, say the ADR needs reopening.
2. Explore the package organically and note where understanding one concept requires bouncing between many files or targets.
3. Look for:
   - modules or types whose interface is as large as their body (apply the deletion test: if removed, does complexity vanish or reappear across callers?)
   - pure logic extracted only for testability while real bugs hide in how it is called
   - tightly coupled units leaking across seams (`Domain` protocols that mirror one implementation)
   - behavior that is hard to test through the public interface
4. Present a numbered list of candidates: files and targets involved, the problem, the proposed deeper interface, and the benefit in testability and agent navigability. Use `CONTEXT.md` vocabulary. Do not propose interfaces yet.
5. Ask which candidate to pursue. Then grill that design with `grill-with-docs`; update `CONTEXT.md` or add an ADR as decisions land.

## Constraints

- Package target dependencies are the architecture fence; propose changes to them explicitly.
- No third-party dependencies.
