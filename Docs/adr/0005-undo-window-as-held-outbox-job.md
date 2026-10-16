# 0005. Undo is a held outbox job anchored to `completedAt`

Status: accepted

## Context

"Mark Delivered" must be undoable for a short time without the sync engine knowing about UI, and the window must survive a relaunch.

## Decision

`markDelivered` stores `completedAt` and enqueues a job with `notBefore = completedAt + SyncPolicy.undoWindow`. `undoDelivery` is allowed only while the job exists and `notBefore > now`, and requires an active shift. `commitDelivery` fast-forwards `notBefore` to now and is idempotent. `SyncActor`'s wake task flushes the job on expiry regardless of UI.

When `FeatureDelivery` observes the task become `delivered` it reports `onDeliveryMarked` and finishes, popping the screen. `AppNavigation` (`AppRouter.pendingDeliveryUndo`, `DeliveryUndoToast` in `MainTabView`) owns the app-wide Undo toast and its countdown, and calls `undoDelivery` or `commitDelivery`. `exception` bypasses the window.

## Consequences

- No `inFlight` flag is needed to avoid racing the sync engine.
- Ending a shift rejects Undo even inside the window.
- Feature modules own no sync timers. The only timer that ends in `commitDelivery` lives in `AppNavigation`, and the call is idempotent, so the toast, `Done` and the wake task can race safely.
- Reorder debouncing uses the same `notBefore` mechanism.
