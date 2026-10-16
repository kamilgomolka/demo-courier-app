# 0004. Outbox with at-least-once delivery and idempotency keys

Status: accepted

## Context

The app must work offline and survive a crash between a successful remote call and the local acknowledgement.

## Decision

Every mutation enqueues a `SyncJob` in the same SwiftData transaction. `SyncActor` is the only consumer. Each job is sent at most once per drain and carries its `id` as `Idempotency-Key`. Server PATCH operations are absolute (target status, complete order), so replays are safe. A `reorder` job gets a fresh `id` when replaced. Retrying failed jobs happens only on external triggers; queue updates and wake timers never retry them. The scheduler fingerprint is `(id, kind, notBefore)`, excluding `attemptCount` and `lastFailure`, so diagnostics cannot cause retry loops.

## Consequences

- `markSynced` on a deleted job is a no-op.
- A failed job blocks later jobs for the same `taskID` within a cycle (head-of-line blocking); other tasks proceed.
- 401 triggers a session refresh and one retry; 409 is resolved last-write-wins using `serverUpdatedAt`.
- Corrupt job payloads are skipped and logged, never blocking the drain.
