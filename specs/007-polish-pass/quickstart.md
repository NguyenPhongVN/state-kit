# Quickstart: Verify Polish Pass

Feature: specs/007-polish-pass · Date: 2026-09-25

## 1. Gates

```bash
swift build && swift test && (cd Examples && swift build)
```

## 2. Hooks (US1)

`Tests/StateKitTests/DeferredHooksTests.swift`:
- `useDeferred` catch-up: rapid source updates land; deferred equals latest (race-safe via generation guard).
- `useTransition`: `isPending` true while `start`'s async work awaits; false after.

## 3. Async cache (US2)

`Tests/StateKitCacheTests/AsyncCacheTests.swift`:
- concurrent multi-task writes stay ≤ capacity; LRU eviction order holds;
- TTL entries expire after the interval (short TTLs); race-free under TaskGroup load.

## 4. Remote flags (US3)

`Tests/StateKitFeatureFlagsTests/RemoteFlagTests.swift`:
- adapter override wins over local; missing entry falls back to local;
- in-memory adapter returns its dictionary.

## 5. Fixes (US4)

- TTL expiry: entry with both callbacks set expires → `onExpire` fired exactly once, `onEvict` not fired.
- `GeolocationRollout(allowedRegions: ["VN"], regionResolver: { "VN" })` → true; resolver returning "US" → false; default (nil resolver) → false.
