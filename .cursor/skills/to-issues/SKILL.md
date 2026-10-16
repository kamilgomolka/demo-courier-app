---
name: to-issues
description: Break a PRD or plan into independently implementable local issue files as vertical tracer-bullet slices. Use when the user wants to convert a PRD into issues or split work for agents.
---

# To issues

Split the plan into vertical slices (tracer bullets), stored as markdown files in the repo.

## Slice rules

- Each slice cuts through every layer it needs (`Domain`, `LocalStorage`, `SyncEngine`, `Feature*`, `AppNavigation`) and is demoable or verifiable on its own. Never slice by layer.
- Prefer many thin slices over few thick ones. One slice fits one agent session.
- Mark each slice AFK (an agent can finish it unattended) or HITL (needs a human decision or visual review). Prefer AFK.
- List what each slice is blocked by.

## Process

1. Read the source PRD from `Docs/prd/` or the plan in the conversation, plus `CONTEXT.md`.
2. Present the numbered breakdown: title, AFK or HITL, blocked by, user stories covered. Ask me to confirm granularity, dependencies and AFK/HITL labels. Iterate until approved.
3. Create `Docs/issues/<prd-number>-<prd-slug>/NN-<slug>.md` for each slice, in dependency order, so `Blocked by` can reference earlier filenames. Copy the structure of `Docs/issues/TEMPLATE.md`.
4. Set `Status: ready-for-agent` for AFK and `Status: ready-for-human` for HITL. A finished slice becomes `Status: done`.
5. Do not paste source file paths that will go stale. Do not commit the files.
