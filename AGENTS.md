# AGENTS.md

CourierApp: offline-first iPhone app (iOS 26, Swift 6.3, Xcode 26.6) with an outbox-based sync engine. Architecture playground; features are the minimum needed to exercise the mechanisms.

Vocabulary lives in [CONTEXT.md](CONTEXT.md). Decisions live in [Docs/adr/](Docs/adr/). Use the vocabulary verbatim in code, tests and commits.

## Modules (`CourierModules/Sources`)

- `Core/Domain`: models, `TaskStateMachine`, repository protocols. `nonisolated`, depends on nothing.
- `Core/DomainTestSupport`: fakes, fixtures, `ManualTimeSource`. Its source compiles only in Debug; linked by test targets and Feature targets to support Debug-only previews.
- `Core/LocalStorage`: SwiftData schema and the `LocalStore` actor. `@Model` types never leave the module.
- `Core/SyncEngine`: `SyncActor` (sole outbox consumer) and `MockCourierAPI`. Depends on `Domain` only.
- `Core/DesignSystem`: tokens, typography, shared views.
- `Features/Feature{Dashboard,Delivery,History,Settings}`: `@MainActor` by default; depend on `Domain` and `DesignSystem`, plus `DomainTestSupport` to support Debug-only previews; never on each other.
- `App/AppNavigation`: composition root, router, tabs. The only module that sees `LocalStorage` and `SyncEngine`.

## Commands

- `make check`: lint, build, package tests. Run before declaring any task done.
- `make test-module MODULE=<TestTarget>`: one package test target, for the TDD loop.
- `make test`: package tests plus host UI tests.
- `make format`: apply `swift-format`. `make lint` is the CI gate.

## Swift block spacing

- Separate adjacent statements with one blank line whenever either contains a multiline brace-delimited block, including closures.
- Do not insert a blank line before the first statement in a body.
- Single-line blocks do not require additional spacing.
- Keep `else`, `catch`, `repeat`/`while` and expression chains attached.
- For closures with an explicit `in` and a non-empty body, start the body on the next line after `in`, even if it contains only one statement.
- Run `make format` and `make check` before reporting completion.

## Invariants the compiler does not enforce

- Business invariants (active shift, single `inTransit` task, undo window) are enforced in `LocalStore`, not in the UI.
- Every task mutation and its `SyncJob` are written in one transaction. Shift mutations are local only.
- `commitDelivery` is idempotent; `SyncJob.id` is the `Idempotency-Key`.
- Time comes from `TimeSource`; tests never sleep, they drive `ManualTimeSource` or use `Eventually`.
- No third-party dependencies. UI strings go through each module's `Localizable.xcstrings`.

## Working agreement

- One session, one vertical slice. Start a new chat after each slice instead of extending a long thread.
- Reproduce before fixing: a failing test first, then the change.
- Report what was verified and what was not. `make check` output is the evidence.
- PRDs live in `Docs/prd/`, slices in `Docs/issues/` (template: `Docs/issues/TEMPLATE.md`). `Status` is `needs-triage`, `ready-for-agent` (AFK), `ready-for-human` or `done`. One slice, one session, one branch and PR.
- Skills in `.cursor/skills` cover the workflow: `grill-with-docs`, `to-prd`, `to-issues`, `tdd`, `diagnose`, `improve-codebase-architecture`, `zoom-out`, `handoff`.
