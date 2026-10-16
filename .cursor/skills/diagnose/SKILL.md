---
name: diagnose
description: Disciplined diagnosis loop for hard bugs and regressions: reproduce, minimise, hypothesise, instrument, fix, regression-test. Use when something is broken, flaky or slow.
---

# Diagnose

## 1. Build a feedback loop

This is the skill. Get a fast, deterministic, agent-runnable pass/fail signal before anything else. In order of preference:

- A failing Swift Testing test at the lowest seam that reproduces it, driven by `ManualTimeSource` and fakes.
- A failing UI test with `--ui-testing`.
- `os.Logger` evidence: `xcrun simctl spawn booted log stream --predicate 'subsystem == "com.kamilgomolka.CourierApp"'`.

For flaky failures, loop the test until the failure rate is high enough to debug. Do not continue without a loop; ask me for the missing artifact (log, repro steps, crash report) instead.

## 2. Reproduce and minimise

Confirm the loop shows the bug I described, not a neighbouring one. Strip inputs until the smallest repro remains.

## 3. Hypothesise

Write three to five ranked, falsifiable hypotheses before testing any. Show them to me; I may have domain knowledge that re-ranks them.

## 4. Instrument

Change one variable at a time. Add targeted `Logger` output at the boundary that separates hypotheses. Tag temporary logging so it can be removed.

## 5. Fix and prove

Turn the repro into a regression test that fails before the fix and passes after. Apply the minimum fix. Re-run the original loop, then `make check`.

## 6. Clean up

Remove temporary instrumentation. State the root cause in one or two sentences and what was verified.
