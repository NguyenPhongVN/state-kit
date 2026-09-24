---
description: "Task list for Clean Public API Overhaul"
---

# Tasks: Clean Public API Overhaul

**Input**: Design documents from `/specs/002-clean-public-api/`

**Prerequisites**: plan.md ✅ · spec.md ✅ (with Clarifications) · research.md ✅ · audit.md ✅ · data-model.md ✅ · contracts/ ✅ · quickstart.md ✅

**Tests**: Included — FR-09 mandates red→green pairs for behavior changes (watch, override diagnostics); docs-only tasks have verification steps instead.

**Organization**: US1 = watch reactive + addListener deprecated (P1) · US2 = override diagnostics + justified casts (P1) · US3 = canonical-path docs (P2) · US4 = finalize audit (P2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup (Shared Infrastructure)

None required — no new targets or infrastructure; all work lands in existing modules/targets.

---

## Phase 2: Foundational (Blocking Prerequisites)

None.

---

## Phase 3: User Story 1 — watch is reactive, addListener deprecated (Priority: P1) 🎯 MVP

**Goal**: `ProviderContainer.watch(_:)` registers reactivity (refcount + returns state), `read(_:)` stays pure, `addListener(for:)` is a deprecated alias of `watch`.

**Independent Test**: `Tests/RiverpodsTests` — auto-dispose provider stays alive while watched; read-only element disposes after its window; addListener behaves identically to watch.

### Tests for User Story 1

- [x] T001 [P] [US1] Write red tests in Tests/RiverpodsTests/ProviderAccessTests.swift: (a) `watch` keeps an auto-dispose provider alive until `removeListener` + dispose window; (b) `read` registers nothing (element disposes with zero listeners); (c) deprecated `addListener` registers identically to `watch` — tests must FAIL before implementation

### Implementation for User Story 1

- [x] T002 [US1] Make `watch(_:)` register: increment element listeners (same path as `addListener`) and return state, in Sources/Riverpods/Container/ProviderContainer.swift; update read/watch/removeListener/refresh contract docs
- [x] T003 [US1] Deprecate `addListener(for:)` (availability annotation + replacement message), body delegates to `watch(_:)`, in Sources/Riverpods/Container/ProviderContainer.swift; migrate `@Watch` wrapper internals to `container.watch(_:)` in Sources/Riverpods/SwiftUI/Watch.swift

**Checkpoint**: watch/read contract verifiable independently; existing call sites compile (deprecation only)

---

## Phase 4: User Story 2 — Override mismatch diagnosed, casts justified (Priority: P1)

**Goal**: No unexplained crash from caller-supplied override input; every remaining force-conversion carries its invariant justification.

**Independent Test**: Validation helper unit tests + grep audit of remaining `as!` sites (each annotated).

> Same-file note: US2 edits `ProviderContainer.swift` after US1 — sequential.

### Tests for User Story 2

- [x] T004 [P] [US2] Write red tests for the internal validation helper (mismatched override value type → diagnostic message naming provider + both types; matched types → nil) in Tests/RiverpodsTests/OverrideDiagnosticsTests.swift — must FAIL before helper exists

### Implementation for User Story 2

- [x] T005 [US2] Add internal validation helper (returns diagnostic message or nil) and replace the three override-path casts (element cast, value cast, state cast) in Sources/Riverpods/Container/ProviderContainer.swift — mismatch aborts with the precise diagnostic instead of a bare cast failure
- [x] T006 [US2] Add invariant justification comments at remaining lookup cast sites: Sources/Riverpods/Container/ProviderContainer.swift (read/watch/refresh/listen/removeListener), Sources/Riverpods/Container/ProviderElement.swift, Sources/Riverpods/Providers/{StateProvider,NotifierProvider,FutureProvider,AsyncNotifierProvider}.swift; add the same justification notes to hook-slot casts in Sources/StateKit/Use/*.swift (audit F3)

**Checkpoint**: US1+US2 closed — no counterfeit names, no unjustified caller-input casts in Riverpods

---

## Phase 5: User Story 3 — Canonical-path documentation (Priority: P2)

**Goal**: Per-overload guidance for the preserved(by:) family; hooks-vs-macros selection guide; examples on canonical paths; clearAll doc fix.

**Independent Test**: greps in quickstart §4 — 8 documented non-deprecated overloads, single deprecation annotation in Riverpods, examples clean.

- [x] T007 [P] [US3] Write per-overload use-case docs for all 8 `preserved(by:)` variants (single Equatable / single Hashable / variadic / array / closure forms) in Sources/StateKit/Core/UpdateStrategy.swift — nothing deprecated (Clarified decision)
- [x] T008 [P] [US3] Write hooks-vs-`@Hook*` selection guide (when to use functions vs macros, with examples) under docs/core/ and link it from docs/DOCS.md
- [x] T009 [US3] Fix `KeychainStateProvider.clearAll()` doc (deletes exactly this provider's key — no "pattern") in Sources/StateKitPersistence/KeychainStateProvider.swift; sweep Examples/ and doc examples for deprecated `addListener(for:)` usage and migrate to `watch(_:)` if found

---

## Phase 6: User Story 4 — Audit finalized (Priority: P2)

**Goal**: audit.md reflects post-fix reality with complete dispositions and a verifiable tally.

**Independent Test**: every finding has a final disposition; deferred set == {F7, F8, F9} (all P3).

- [x] T010 [US4] Finalize specs/002-clean-public-api/audit.md: mark F1/F2/F3/F4/F5/F6/F10 dispositions with the shipped fix references, confirm deferred set, re-verify tally and coverage statement

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T011 [P] Add changelog entries in docs/release/CHANGELOG.md: ⚠️ watch behavior change (register + balance obligation), addListener deprecation, override diagnostics, docs fixes
- [x] T012 Run full `swift build && swift test` — zero failures, zero unexpected skips (SC-06)
- [x] T013 Execute specs/002-clean-public-api/quickstart.md steps 1–6 and record results

---

## Dependencies & Execution Order

### Phase Dependencies

- US1 → US2: sequential (same file, ProviderContainer.swift)
- US3 ∥ US4: fully parallel with US1/US2 chain (different files)
- Polish depends on all stories

### Parallel Opportunities

- T007 ∥ T008 (docs, different files) ∥ US1/US2 chain
- T001 (US1 tests) ∥ T004 (US2 tests) can be written together; T004's helper test compiles only after T005's helper exists — keep T004 run after T005 for red/green discipline per-story

## Implementation Strategy

### MVP First (User Story 1 only)

1. T001 → T002 → T003: the counterfeit API is gone; library reads like Riverpod (read vs watch)
2. Validate independently: quickstart §2

### Single-Developer Order (this repo, one agent)

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 → T013
