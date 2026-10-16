# 0001. Features observe repository streams, not `@Query`

Status: accepted

## Context

Feature modules must not see SwiftData `@Model` types, and UI models must be testable without SwiftData.

## Decision

Features consume `AsyncStream` snapshots exposed by repository protocols in `Domain`. `LocalStore` yields a snapshot after each successful save, only when the value changed (`Equatable`), buffered with `bufferingNewest(1)`. UI models cancel their consuming task on dismissal and only assign when a snapshot differs.

## Consequences

- `@Model` records stay `internal` to `LocalStorage`.
- Model tests use fakes from `DomainTestSupport`.
- Every new observable query needs a stream on a repository protocol and a teardown path that unregisters its continuation.
