---
description: "Task list for Fix Critical Defects Found in Code Review"
---

# Tasks: Fix Critical Defects Found in Code Review

**Input**: Design documents from `/specs/001-fix-critical-defects/`

**Prerequisites**: plan.md ✅ · spec.md ✅ · research.md ✅ · data-model.md ✅ · contracts/ ✅ · quickstart.md ✅

**Tests**: Included — the spec's Success Criteria (SC-01…SC-06) mandate automated verification; each story's tests are written first and must FAIL before implementation.

**Organization**: Grouped by user story (US1 = keychain scoped delete P1, US2 = keychain accessibility P1, US3 = housekeeping-loop leak P1, US4 = rollout bucketing P2, US5 = docs count P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Path Conventions

Multi-module Swift package — modules under `Sources/<Module>/`, tests under `Tests/<Module>Tests/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Test infrastructure required by the persistence stories

- [x] T001 Add `StateKitPersistenceTests` test target to Package.swift (dependencies: `StateKitPersistence`), mirroring the existing one-target-per-module convention
- [x] T002 Run `swift build` to confirm the package still builds with the new (empty) test target

**Checkpoint**: Test infrastructure ready — user stories can begin

---

## Phase 2: Foundational (Blocking Prerequisites)

None — no shared blocking work beyond Setup. All five stories touch disjoint concerns.

---

## Phase 3: User Story 1 — Scoped keychain deletion (Priority: P1) 🎯 MVP

**Goal**: `KeychainBatch.deleteAll(matching:)` deletes only batch items (prefix-filtered); foreign keychain items are unreachable by construction.

**Independent Test**: `Tests/StateKitPersistenceTests` — selection helper unit tests + macOS round-trip: foreign item survives a pattern-scoped delete.

### Tests for User Story 1

> **NOTE: Write first, ensure they FAIL before implementation**

- [x] T003 [P] [US1] Write selection tests (nil pattern → all batch keys; empty pattern → all; `"cache_"` prefix → only prefixed keys; no match → empty; keys not in `items` never appear) for `KeychainBatch.keysToDelete(matching:)` in Tests/StateKitPersistenceTests/KeychainBatchTests.swift
- [x] T004 [P] [US1] Write macOS round-trip test: store 2 batch items (`cache_a`, `cache_b`) + 1 foreign item via `KeychainStateProvider.store`; run `deleteAll(matching: "cache_")`; assert batch cache items gone and foreign item still retrievable, in Tests/StateKitPersistenceTests/KeychainBatchTests.swift

### Implementation for User Story 1

- [x] T005 [US1] Implement internal pure helper `keysToDelete(matching:) -> [String]` on `KeychainBatch` in Sources/StateKitPersistence/KeychainStateProvider.swift per data-model.md (nil/empty → all `items` keys; otherwise `hasPrefix` filter)
- [x] T006 [US1] Rewrite `KeychainBatch.deleteAll(matching:)` in Sources/StateKitPersistence/KeychainStateProvider.swift to delete exactly `keysToDelete(matching:)` output (keep per-item `KeychainError.storeFailed` semantics); docs updated to state prefix semantics

**Checkpoint**: Story 1 testable independently — `swift test --filter KeychainBatchTests` green; no key outside `items` can ever be deleted

---

## Phase 4: User Story 2 — Valid keychain protection attribute (Priority: P1)

**Goal**: Every `KeychainAccessibility` case applies the official `kSecAttrAccessible*` constant on all write paths.

**Independent Test**: Exhaustive mapping test + macOS store→retrieve round-trip per level.

> **Same-file note**: US2 edits `Sources/StateKitPersistence/KeychainStateProvider.swift`, already touched by US1 — implement sequentially after US1 to avoid merge friction (no semantic dependency).

### Tests for User Story 2

- [x] T007 [P] [US2] Write exhaustive mapping test: all 5 cases map to the intended official Security constant; raw values equal the platform canonical short codes, in Tests/StateKitPersistenceTests/KeychainAccessibilityTests.swift
- [x] T008 [P] [US2] Write macOS round-trip test storing/retrieving/deleting one item per accessibility level, in Tests/StateKitPersistenceTests/KeychainAccessibilityTests.swift

### Implementation for User Story 2

- [x] T009 [US2] Add internal `var secAttr: CFString` (compiler-exhaustive switch) mapping each case to `kSecAttrAccessible*` constants; change raw values from invented `com.apple.keychain.*` strings to canonical platform codes, in Sources/StateKitPersistence/KeychainStateProvider.swift
- [x] T010 [US2] Use `secAttr` in `KeychainStateProvider.store` (update attributes + insert query) and `KeychainBatch.store` in Sources/StateKitPersistence/KeychainStateProvider.swift — no write path may use the raw value

**Checkpoint**: Stories 1+2 green — keychain module trustworthy; `swift test --filter StateKitPersistenceTests` passes

---

## Phase 5: User Story 3 — Housekeeping-loop leak (Priority: P1)

**Goal**: Releasing the last reference to `TimeToLiveCache`, `SlidingWindowTTLCache`, or `EventTracker` deallocates it and stops its periodic loop; live instances behave unchanged.

**Independent Test**: Weak-reference deinit assertions in cache/analytics test targets.

> Fully parallel with US1/US2 (disjoint modules).

### Tests for User Story 3

- [x] T011 [P] [US3] Write deinit tests: create N=100 instances of each cache type in a scope holding only weak refs; after scope + run-loop yield, all weak refs are nil; plus a live-instance test asserting cleanup callbacks still fire, in Tests/StateKitCacheTests/CacheTests.swift
- [x] T012 [P] [US3] Write deinit test: `EventTracker` released after tracking events → weak ref nil and no further `onFlush` callbacks fire, in Tests/StateKitAnalyticsTests/AnalyticsTests.swift

### Implementation for User Story 3

- [x] T013 [US3] Fix `TimeToLiveCache.startBackgroundCleanup` — capture `[weak self]`, exit the loop when self is gone (re-check per iteration), in Sources/StateKitCache/TTLCache.swift
- [x] T014 [US3] Fix `SlidingWindowTTLCache.startBackgroundCleanup` identically, in Sources/StateKitCache/TTLCache.swift
- [x] T015 [US3] Fix `EventTracker.startAutoFlush` identically, in Sources/StateKitAnalytics/EventTracker.swift (leak only — no cap, per Clarifications)

**Checkpoint**: Stories 1–3 green — SC-01/SC-02 verifiable via the new deinit tests

---

## Phase 6: User Story 4 — Fair rollout bucketing (Priority: P2)

**Goal**: Bucket derivation covers all scripts (UTF-8), deterministic, monotone in percentage.

**Independent Test**: Distribution/stability/monotonicity tests in the feature-flags target.

### Tests for User Story 4

- [x] T016 [P] [US4] Write tests: (a) 10,000 distinct non-ASCII IDs at 10% → 9–11% enabled; (b) repeated evaluation stable per ID; (c) every ID enabled at 5% enabled at 50%, in Tests/StateKitFeatureFlagsTests/FeatureFlagsTests.swift

### Implementation for User Story 4

- [x] T017 [US4] Rewrite `djb2Hash` to iterate `utf8` bytes with `UInt32` wrapping arithmetic (drop `abs()`), returning a non-negative `Int`, in Sources/StateKitFeatureFlags/Internal/HashUtils.swift per research.md D4

**Checkpoint**: SC-05 tests green; existing flag tests unaffected (custom hashers untouched)

---

## Phase 7: User Story 5 — Docs count matches reality (Priority: P3)

**Goal**: README's stated public-macro count equals the actual count.

**Independent Test**: grep comparison (quickstart.md §6).

- [x] T018 [US5] Count `^public macro` declarations in Sources/StateKitMacros/ and update both occurrences in README.md (currently "47", expected 48 — use the verified number)

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T019 [P] Document the two accepted behavior breaks (KeychainAccessibility raw-value change; one-time rollout re-bucketing) in the release notes under docs/release/
- [x] T020 Run full `swift build && swift test` — zero regressions (SC-07)
- [x] T021 Execute specs/001-fix-critical-defects/quickstart.md validation steps 2–6 and record results

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001–T002)** → blocks US1/US2 test tasks (need the new target)
- **US1 → US2**: recommended sequential (same source file); no semantic dependency
- **US3, US4, US5**: fully independent — can start any time, in parallel with each other and with the persistence work

### User Story Dependencies

- US1: none (after Setup)
- US2: same-file sequencing with US1 only
- US3: none (Cache/Analytics targets already exist)
- US4: none
- US5: none

### Parallel Opportunities

- T011+T012 (US3 tests), T016 (US4 tests), T003+T004 (US1 tests), T007+T008 (US2 tests) — test pairs within a story
- Entire stories: US3 ∥ US4 ∥ US5 ∥ (US1→US2 chain)

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. T001–T002 (Setup)
2. T003–T006 (US1) → validate: pattern-scoped delete can no longer wipe foreign keychain items
3. Highest data-loss risk eliminated — ship-worthy on its own

### Incremental Delivery

US1 (data loss) → US2 (broken persistence) → US3 (leaks) → US4 (bucketing) → US5 (docs) → polish. Each story independently green before the next.

### Single-Developer Order (this repo, one agent)

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 → T013 → T014 → T015 → T016 → T017 → T018 → T019 → T020 → T021
