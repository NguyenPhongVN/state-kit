# Quickstart: Verify the Defect Fixes

Feature: specs/001-fix-critical-defects · Date: 2026-09-24

## Prerequisites

- macOS host with Swift 6.2 toolchain (`swift --version`)
- Repo root: `/Users/computer/Desktop/state-kit`

## 1. Full regression pass

```bash
swift build && swift test
```

Expected: build succeeds; every existing suite passes (no regressions), including the new tests below.

## 2. Housekeeping-loop leak (Spec Story 3 / SC-01, SC-02)

Covered by tests in `Tests/StateKitCacheTests` and `Tests/StateKitAnalyticsTests`:

- create N instances of `TimeToLiveCache`, `SlidingWindowTTLCache`, `EventTracker` in a scope;
- keep only `weak` references, leave the scope, await a run-loop yield;
- assert all weak refs are nil (instances deallocated ⇒ their loops exited).

Expected: all weak references nil. Before the fix this test never terminates successfully — instances live forever.

## 3. Scoped keychain deletion (Story 1 / SC-03)

Covered by `Tests/StateKitPersistenceTests`:

- pure-selection test: `KeychainBatch` with keys `cache_a`, `cache_b`, `auth_token`; `keysToDelete(matching: "cache_")` returns exactly `[cache_a, cache_b]` (order-insensitive);
- round-trip test on macOS host: store two batch items + one directly-stored item → `deleteAll(matching: "cache_")` → batch cache items gone, directly-stored item still retrievable.

Expected: no foreign key ever deleted (the delete loop's key set is bounded by `items`).

## 4. Accessibility mapping (Story 2 / SC-04)

- exhaustive-mapping test: all 5 cases map to the intended official `kSecAttrAccessible*` constant;
- macOS round-trip: store → retrieve → delete with each level.

Expected: round-trip succeeds; stored attribute equals the chosen level's constant.

## 5. Rollout bucketing (Story 4 / SC-05)

Covered by `Tests/StateKitFeatureFlagsTests`:

- distribution: 10,000 synthetic non-ASCII IDs (e.g. Vietnamese) at 10% → enabled share within 9–11%;
- stability: evaluate twice → identical results;
- monotonicity: every ID enabled at 5% is enabled at 50%.

## 6. Docs count (Story 5 / SC-06)

```bash
grep -c '^public macro' Sources/StateKitMacros/*.swift   # actual
grep -o '[0-9]\+ public macros' README.md                # stated
```

Expected: both numbers identical.
