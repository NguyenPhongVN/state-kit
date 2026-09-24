# Implementation Plan: Health Bundle (CI, Honest Replay, LRU O(1), Test Hardening, removeObserver)

**Branch**: `005-health-bundle` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

## Summary

Close the five quality-debt items from the review: GitHub Actions CI (build + test + Examples
+ non-blocking lint per Clarifications); replace the dishonest `replay()` stub with a
handler-based replay that reports executed/skipped/failed; rewrite `LeastRecentlyUsedCache`
internals to O(1) dictionary + doubly linked list with identical behavior; harden the flaky
`restartThrowingTask` test with bounded polling; add `ProviderContainer.removeObserver(_:)`.
No other behavior changes.

## Technical Context

**Language/Version**: Swift 6.2; CI on GitHub Actions macOS runners
**Primary Dependencies**: none added (SwiftLint installed on the CI runner via brew)
**Testing**: existing suites unchanged except the hardened test; new tests for replay, LRU
stress, removeObserver
**Target Platform**: all supported (CI on macOS)
**Performance Goals**: LRU per-operation O(1) (stress test ≥10,000 mixed ops bounded)
**Constraints**: zero behavior change for LRU public surface; replay's stub signature is
replaced within V1 (changelog-documented); lint non-blocking (Clarifications)
**Scale/Scope**: 1 workflow file, 3 modules touched (DevTools, Cache, Riverpods), 2 test files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status |
|------|--------|
| V.4 honest APIs — replay fix | The point of the feature |
| VII flaky test = defect | Being fixed |
| Zero new package dependencies (CI tooling is runner-side) | PASS |
| Gates: build/test/Examples green | FR-07 |

## Project Structure

```text
.github/workflows/ci.yml                       # NEW — build/test/examples/lint jobs
Sources/StateKitDevTools/History/StateHistory.swift   # real replay + ReplayReport
Sources/StateKitCache/LRUCache.swift                  # O(1) internals (same API)
Sources/Riverpods/Container/ProviderContainer.swift   # removeObserver(_:)
Tests/StateKitAtomsTests/SKAtomStoreTaskTests.swift   # polling hardening
Tests/StateKitCacheTests/CacheTests.swift             # LRU stress test
Tests/RiverpodsTests/                                 # removeObserver tests
specs/005-health-bundle/{plan,research,data-model,quickstart}.md, contracts/
```

**Structure Decision**: five independent fixes; each is small and separately verifiable.

## Constitution Check (post-design): PASS — see table above.

## Complexity Tracking

No violations to justify.
