---
name: handoff
description: Compact the current conversation into a handoff document so a fresh session can continue the work. Use when the context is long or the user starts a new chat for the next slice.
---

# Handoff

Write a handoff document for a fresh agent with no memory of this conversation.

1. Create the file with `mktemp -t handoff` and write Markdown to it. Print the path.
2. Contents, as short as possible:
   - Goal and the slice being worked on.
   - Decisions made and why, only those not already in `CONTEXT.md` or `Docs/adr/`.
   - Current state: what is done, what is in progress, uncommitted changes.
   - Next steps in order.
   - Verification status: what ran and passed, what was not run, known red checks.
3. Reference existing artifacts (`Docs/prd` and `Docs/issues` files, PRs, ADRs, source files) by link or path instead of duplicating them.
4. If I pass arguments, tailor the document to what the next session will focus on.
