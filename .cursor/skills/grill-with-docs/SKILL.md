---
name: grill-with-docs
description: Interview the user about a plan or design until shared understanding, challenging it against CONTEXT.md and Docs/adr, and updating them as decisions land. Use before writing a PRD or when the user wants to stress-test a plan.
---

# Grill with docs

Interview me about every aspect of this plan until we share one understanding. Walk the decision tree branch by branch, resolving dependencies between decisions in order.

## Rules

- Ask one question at a time. Give your recommended answer with each question.
- If the codebase can answer a question, read it instead of asking.
- Read `CONTEXT.md` and `Docs/adr/` first. Use the glossary terms exactly; when I use a vague or conflicting term, propose the precise one.
- When a term is resolved, add or fix it in `CONTEXT.md` immediately. Keep entries to one or two lines.
- Cross-check my claims against the code. When code contradicts what I say, surface the contradiction.
- Test boundaries with concrete scenarios: offline relaunch mid undo window, a failed job blocking the same task, shift ended during an in-flight sync.
- Offer an ADR in `Docs/adr/` only when the decision is hard to reverse, surprising without context, and the result of a real trade-off. Number it next in sequence, 10 to 20 lines.

## Done when

Every branch is resolved, `CONTEXT.md` and any ADRs are updated, and you have restated the agreed design in a short list I can approve before `to-prd`.
