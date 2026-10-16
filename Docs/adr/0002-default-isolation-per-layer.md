# 0002. Default isolation differs per layer

Status: accepted

## Context

Defaulting data modules to `MainActor` would tie domain models and `@Model` definitions to the main thread and defeat the background writer actor.

## Decision

`MainActor` is the default isolation for `DesignSystem`, `Feature*` and `AppNavigation`. `Domain`, `LocalStorage` and `SyncEngine` are `nonisolated`. All targets, tests included, share `strictSettings` from `CourierModules/Package.swift`.

`LocalStore` owns its `ModelContext` on the standard Swift actor executor. `CourierStorage.makeStore` is `@concurrent`, so container and context creation also leave the caller's actor. A regression test creates the store from `MainActor` and verifies that mutations execute off the main thread. Creating `DefaultSerialModelExecutor` off the main thread did not provide that guarantee on the supported SDK.

## Consequences

- Warnings-as-errors is applied through `xcodebuild` flags in the `Makefile`, not `.treatAllWarnings`, which conflicts with `-suppress-warnings` when package targets build as host dependencies.
- New UI modules use `isolatedToMainActor: true`; new data modules do not.
