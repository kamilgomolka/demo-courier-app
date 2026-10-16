# 0003. `AppNavigation` is the only composition root

Status: accepted

## Context

Features and the sync engine must stay independently testable and replaceable.

## Decision

`AppNavigation` is the sole module that depends on both `LocalStorage` and `SyncEngine`. `SyncEngine` depends on `Domain` only (`LocalStorage` is linked into `SyncEngineTests` for integration tests). Features depend on `Domain` and `DesignSystem` and never on each other; navigation between them goes through callbacks (`onSelectTask(id)`, `onFinish`) wired by the router. Dependencies are injected through initializers and closures; no DI container.

## Consequences

- Package target dependencies are the architecture fence; a violation fails to compile.
- The SwiftData container is created by `AppEnvironment` in `AppNavigation`, lazily from `RootView`'s `.task`.
