---
name: zoom-out
description: Go up a layer of abstraction and map the relevant modules and callers for an unfamiliar area of the code. Use when the user does not know a part of the codebase.
---

# Zoom out

I am not familiar with this area. Go up a layer of abstraction. Give me a map of the relevant modules, their responsibilities and their callers, using the vocabulary in `CONTEXT.md`.

Include the owning module, the repository protocols that cross its boundary, the flow of one representative mutation (UI, `LocalStore`, outbox, `SyncActor`) when relevant, and the ADRs that govern it. Keep it to one screen.
