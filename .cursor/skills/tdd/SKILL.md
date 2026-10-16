---
name: tdd
description: Test-driven development with Swift Testing in red-green-refactor loops, one behavior at a time. Use when building a feature or fixing a bug test-first.
---

# TDD

## Principles

- Test behavior through public interfaces, not implementation. A good test survives a refactor unchanged.
- Vertical slices only: one test, one implementation, repeat. Never write all tests first and all code after.
- Use the real `LocalStore` or the fakes in `DomainTestSupport` at module seams; do not mock internals.
- Time is `ManualTimeSource`, asynchronous outcomes are `Eventually`. No sleeps.

## Process

1. Confirm with me the interface changes and which behaviors matter most. List the behaviors to test. You cannot test everything.
2. Tracer bullet: write one failing test for the first behavior. Run it and see it fail for the right reason:
   `make test-module MODULE=<TestTarget>`
3. Write the minimum code to pass. Run the same command.
4. Repeat for each remaining behavior, one at a time.
5. Refactor only while green. Run the test target after each step.
6. Finish with `make check`. Report what passed and anything not run.

## Per-cycle checklist

- The test describes behavior, not structure.
- It uses a public interface only.
- It would fail if the behavior were removed.
- The code added is the minimum for this test.
- No speculative features.
