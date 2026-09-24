---
description: "Task list for Polish Pass"
---

# Tasks: Polish Pass (Deferred Hooks, Async Cache, Remote Flags, Fixes)

**Input**: Design documents from `/specs/007-polish-pass/`

**Prerequisites**: plan.md ✅ · spec.md ✅ · research.md ✅ · data-model.md ✅ · quickstart.md ✅

---

## Phase 1: Deferred & transition hooks (US1)

- [x] T001 [P] Write red tests in Tests/StateKitTests/DeferredHooksTests.swift: deferred catches up to latest source after rapid changes; useTransition isPending true during awaited work, false after
- [x] T002 Implement useDeferred(_:) and useTransition() per research D1 in Sources/StateKit/Use/useDeferred.swift

## Phase 2: Async cache (US2)

- [x] T003 [P] Write red tests in Tests/StateKitCacheTests/AsyncCacheTests.swift: concurrent writes bounded by capacity with LRU eviction; TTL expiry; get/set/remove/removeAll round-trip
- [x] T004 Implement `actor SKAsyncCache` per research D2 in Sources/StateKitCache/SKAsyncCache.swift

## Phase 3: Remote flags (US3)

- [x] T005 [P] Write red tests in Tests/StateKitFeatureFlagsTests/RemoteFlagTests.swift: remote override wins; missing entry falls back to local; in-memory adapter returns its dictionary
- [x] T006 Implement RemoteFlagSource + InMemoryRemoteFlagSource + FeatureFlagRegistry.applyRemoteOverrides(from:) per research D3, in Sources/StateKitFeatureFlags/RemoteFlags.swift

## Phase 4: Behavior fixes (US4)

- [x] T007 [P] Write red test: TTL expiry fires onExpire exactly once and NOT onEvict, in Tests/StateKitCacheTests/CacheTests.swift; then fix Sources/StateKitCache/TTLCache.swift expiry paths (get-on-expired + background cleanup) to call onExpire only; update TTL docs
- [x] T008 [P] Write red tests for GeolocationRollout region resolver (allowed → true; disallowed → false; nil resolver → false) in Tests/StateKitFeatureFlagsTests/FeatureFlagsTests.swift; then add `regionResolver` parameter per research D5 in Sources/StateKitFeatureFlags/Rollout.swift

## Phase 5: Verification

- [x] T009 Full gates: root build+test, Examples build; quickstart checklist recorded
- [x] T010 CHANGELOG entries under Unreleased (part of V1) for the four additions/fixes

---

## Dependencies & Execution Order

T001→T002 · T003→T004 · T005→T006 · T007 (test+fix) · T008 (test+fix) — all five streams independent. T009 after all. T010 last.

## Implementation Strategy

Single-agent order: T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010.
