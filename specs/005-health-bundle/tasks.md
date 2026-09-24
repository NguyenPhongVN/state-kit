---
description: "Task list for Health Bundle"
---

# Tasks: Health Bundle (CI, Honest Replay, LRU O(1), Hardening, removeObserver)

**Input**: Design documents from `/specs/005-health-bundle/`

**Prerequisites**: plan.md ✅ · spec.md ✅ (Clarifications: lint non-blocking) · research.md ✅ · data-model.md ✅ · quickstart.md ✅

---

## Phase 1: CI (US1)

- [x] T001 Create .github/workflows/ci.yml — job `test` (checkout, swift build, swift test, Examples swift build) and job `lint` (brew install swiftlint, swiftlint lint --quiet with continue-on-error: true per Clarifications), triggered on push to main and pull_request

## Phase 2: Honest replay (US2)

- [x] T002 Add `ReplayReport` (executed/skipped/failure) and replace `InMemoryStateHistory.replay()` with `replay(using:)` handler-based semantics per data-model.md, in Sources/StateKitDevTools/History/StateHistory.swift
- [x] T003 [P] Add tests: handler executes applicable actions in order; unhandled actions land in skipped; throwing handler stops with failure; missing-handler legacy API is gone, in Tests/StateKitDevTools (new StateHistoryReplayTests.swift — create the module's first test target only if DevTools lacks one; otherwise extend the existing target)

## Phase 3: LRU O(1) (US3)

- [x] T004 Rewrite LeastRecentlyUsedCache internals — dictionary + doubly linked list, same public API and semantics (eviction order, callbacks, stats, keys order), in Sources/StateKitCache/LRUCache.swift
- [x] T005 [P] Add LRU stress test (≥10,000 mixed get/set on capacity-100, bounded time, stats consistency) in Tests/StateKitCacheTests/CacheTests.swift; verify existing LRU tests pass UNMODIFIED

## Phase 4: Hardening + removeObserver (US4, US5)

- [x] T006 Add polling helper (`waitUntil(timeout:pollInterval:_:)`) to Tests/StateKitAtomsTests and rewrite `restartThrowingTask launches a new request` plus sibling fixed-sleep assertions in SKAtomStoreTaskTests.swift to bounded polling
- [x] T007 Add `ProviderContainer.removeObserver(_:)` (identity removal, idempotent) in Sources/Riverpods/Container/ProviderContainer.swift and tests in Tests/RiverpodsTests (removed observer gets no callbacks; double-remove no-op)

## Phase 5: Verification

- [x] T008 Full gates: root build+test (assertions unchanged except hardened ones), Examples build; run the suite 5× (SC-04); execute specs/005-health-bundle/quickstart.md and record results
- [x] T009 Add CHANGELOG entries under Unreleased (part of V1): removeObserver API, replay signature change (breaking within V1), LRU O(1) internals, CI, test hardening

---

## Dependencies & Execution Order

T001 independent · T002→T003 · T004→T005 · T006, T007 independent · T008 last (all gates) → T009.
Modules are disjoint — T002–T007 can proceed in any order after their prerequisites.

## Implementation Strategy

Single-agent order: T001 → T003 → T002 → T005 → T004 → T006 → T007 → T008 → T009.
