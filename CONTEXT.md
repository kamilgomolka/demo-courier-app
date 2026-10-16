# Context

Ubiquitous language of CourierApp. Names here are the names in code.

## Work

- **Shift**: a courier's working period. `scheduled`, then `active`, then `finished` (terminal). Reset only through Settings. Local only; never produces a `SyncJob`.
- **DeliveryTask**: one package to deliver, belonging to a Shift. Status `new`, `inTransit`, `delivered` or `exception`.
- **Queue**: the `new` tasks plus the single `inTransit` task, ordered by `sortOrder`. The courier reorders the `new` part.
- **Exception**: a task the courier could not deliver, with an `ExceptionReason` (`customerNoShow`, `addressNotFound`, `packageDamaged`, `other(details:)`). Bypasses the Undo window.
- **ShiftSummary**: derived progress and earnings. Earnings count `delivered` payouts only.

## Sync

- **Outbox**: the persisted queue of `SyncJob`s. Written in the same transaction as the mutation that caused it.
- **SyncJob**: a pending remote write, `updateStatus` or `reorder`. Its `id` is the **Idempotency-Key**.
- **notBefore**: the earliest instant a `SyncJob` is eligible. Holds are expressed through it.
- **Undo window**: `SyncPolicy.undoWindow` (5 s) during which a delivered task's job is held. Anchored to the stored `completedAt`; the courier undoes through an app-wide toast.
- **Reorder debounce**: `SyncPolicy.reorderDebounce` (5 s); consecutive moves replace one `reorder` job and slide its `notBefore`.
- **Drain**: one pass over eligible jobs, FIFO, each job sent at most once.
- **Trigger**: an external reason to drain (`launch`, `foreground`, `screenAppeared`, `connectivityRestored`, `manual`). Failed jobs retry only on a trigger.
- **Wake task**: the single cancellable task in `SyncActor` sleeping until the earliest `notBefore`.
- **Head-of-line blocking**: a failed job blocking later jobs for the same `taskID` within a cycle. Other tasks proceed.
- **SyncState**: `pending` or `synced`, computed from the presence of an `updateStatus` job. Never stored.
- **Last write wins**: HTTP 409 resolution comparing the server's `serverUpdatedAt` with the job's `createdAt`.
- **Session refresh**: HTTP 401 handling through `SessionRefreshing`, followed by one immediate retry.

## Architecture

- **Composition root**: `AppNavigation`; builds `AppEnvironment` and injects dependencies into features.
- **Repository protocols**: the contracts in `Domain` that features consume (`TaskRepository`, `ShiftRepository`, ...). Streams, not `@Query`.
- **LocalStore**: the single-writer actor over one SwiftData `ModelContext`.
- **Network conditions**: Settings-driven simulation (offline, latency range, simulated failure) honored by `MockCourierAPI`.
