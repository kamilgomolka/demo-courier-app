---
name: to-prd
description: Turn the current conversation and codebase understanding into a PRD saved as a local markdown file. Use after grill-with-docs, when the user wants a PRD.
---

# To PRD

Synthesize what is already known into a PRD. Do not interview; use `grill-with-docs` for that.

1. Read `CONTEXT.md`, `Docs/adr/` and the modules involved. Use glossary terms verbatim.
2. Sketch the modules to build or change. Prefer deep modules: a small, stable interface hiding substantial behavior, testable in isolation through `Domain` protocols and `DomainTestSupport` fakes. Confirm the module list with me.
3. Write the PRD to `Docs/prd/NNN-<slug>.md`, where `NNN` is the next unused three-digit number in `Docs/prd/`. Structure:

```
# <title>

Status: needs-triage

## Problem
## Solution
## User stories
1. As a courier, I want ..., so that ...
## Implementation decisions
Modules touched, interface changes in Domain, schema changes, sync and invariant impact. No file paths or code snippets.
## Testing decisions
What makes a good test here, which test targets, which fakes.
## Out of scope
```

4. Print the path of the file. Do not commit it.
