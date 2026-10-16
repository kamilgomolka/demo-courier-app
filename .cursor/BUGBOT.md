# Review rules

Flag a change when it:

- Imports `LocalStorage` or `SyncEngine` outside `AppNavigation`, makes a `Feature*` module depend on another feature, or exposes an `@Model` type outside `LocalStorage`.
- Gives a data module (`Domain`, `LocalStorage`, `SyncEngine`) `MainActor` default isolation, or a UI module `nonisolated` default isolation.
- Writes a task mutation without its `SyncJob` in the same transaction (shift mutations are local only), or moves a business invariant (active shift, single `inTransit` task, undo window) from `LocalStore` into UI code.
- Makes a sync path non-idempotent: replay of the same `SyncJob.id` must be safe; `commitDelivery` must remain a no-op outside an open undo window.
- Retries failed jobs from queue updates or wake timers instead of external triggers, or puts `attemptCount` or `lastFailure` into the scheduler fingerprint.
- Reads `Date()` or sleeps directly in sync, storage or scheduling logic instead of going through `TimeSource` (purely cosmetic UI countdowns are fine), or sleeps in a test instead of using `ManualTimeSource` or `Eventually`.
- Uses force unwrap, `try!`, `as!`, a swallowed error, or untyped `throws` where a domain error enum applies.
- Ignores cancellation in a loop or sleep, or captures `self` strongly in an escaping closure that outlives the caller.
- Adds a third-party dependency, a raw UI string literal, or a narrative comment that restates the code.
- Changes behavior without a test that fails without the change.
