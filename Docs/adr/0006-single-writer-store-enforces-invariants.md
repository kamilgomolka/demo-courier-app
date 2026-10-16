# 0006. A single-writer store enforces business invariants

Status: accepted

## Context

Cross-entity rules (one `inTransit` task, active shift, shift membership) must hold regardless of what the UI allows.

## Decision

`LocalStore` is the only reader and writer of one `ModelContext`. It validates invariants inside the transaction and throws typed `RepositoryError`s (`anotherTaskInTransit`, `shiftNotActive`, `taskNotInActiveShift`, `invalidTransition`, ...). `TaskStateMachine.apply` is a pure function over single-task transitions. `syncState` is derived from the outbox when mapping to domain structs, never persisted. Remote snapshot merges on initial load are insert-only; existing records are never overwritten.

## Consequences

- UI disabling (inactive shift rows, disabled End Shift) is presentation only.
- New mutations add their invariant checks and outbox effects to `LocalStore` in the same transaction.
- SwiftData uses `VersionedSchema` v1 without a migration plan; a schema change needs a new ADR.
