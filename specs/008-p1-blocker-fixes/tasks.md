# Tasks: P1 Blocker Fixes (Production Readiness)

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Branch**: `008-p1-blocker-fixes`

Tests are explicitly requested (spec FR-013, constitution Principle VII): every fix lands with a
regression test written first and observed to fail (red) before the fix (green). Leak fixes are
verified by deallocation (weak-reference) assertions.

## Phase 1: Setup

- [X] T001 Create regression test scaffolding: `Tests/StateKitTests/HookTeardownRegressionTests.swift` with a shared never-resolving async helper and a `weak`-box assertion helper used by US1 suites

## Phase 2: Foundational

- [X] T002 [P] Add `SKInterceptorToken` + `addInterceptorRemovable`/`removeInterceptor` (idempotent removal, snapshot-iteration-safe `notifyInterceptors`) in `Sources/StateKitAtoms/Core/SKAtomStore.swift`; deprecate append-only `addInterceptor` forwarding to the new path — blocking prerequisite for US3

## Phase 3: User Story 1 — Hook teardown releases in-flight work (P1)

**Goal**: releasing a hook slot cancels its task/subscription and deallocates the box.
**Independent test**: `swift test --filter HookTeardownRegressionTests` — weak box refs become nil after scope release; infinite sequence stops consuming.

- [X] T003 [US1] RED: write teardown/deallocation tests for `useAsync`, `useAsyncSequence`, `usePublisher` in `Tests/StateKitTests/HookTeardownRegressionTests.swift` (scope released while operation in flight → weak box nil; infinite sequence stops; subscription cancelled); run, observe failures
- [X] T004 [US1] Fix retain cycle via `[weak box]` in task/sink closures of `Sources/StateKit/Use/UseAsync/useAsync.swift` and `Sources/StateKit/Use/UseAsync/useAsyncSequence.swift`; run T003 to green
- [X] T005 [US1] Fix retain cycle in `Sources/StateKit/Use/UseAsync/useAsyncPerform.swift` and `Sources/StateKit/Use/UseAsync/useAsyncRefresh.swift`; extend T003 suites for both hooks to green
- [X] T006 [US1] Fix retain cycle in `Sources/StateKit/Use/usePublisher/usePublisherPerform.swift` and `Sources/StateKit/Use/usePublisher/usePublisherRefresh.swift` (weak box in sink closures); extend T003 suites to green
- [X] T007 [US1] RED→GREEN: `useLoadMore` — write deallocation/cancellation test in `Tests/StateKitSupportTests/`, then fix `[weak box]` in stored `reload`/`loadNext` closures in `Sources/StateKitSupport/Hooks/Functions/useLoadMore.swift`

## Phase 4: User Story 2 — Publisher hooks write state on the main actor (P1)

**Goal**: background-emitting publishers never write hook state off-main.
**Independent test**: `swift test --filter PublisherHookMainThreadTests` — phase writes observed only on main.

- [X] T008 [US2] RED: write main-thread assertion tests in `Tests/StateKitTests/PublisherHookMainThreadTests.swift` driving `usePublisher`/`usePublisherPerform`/`usePublisherRefresh` from a background-queue subject; run, observe failure
- [X] T009 [US2] Fix: route sinks through `.receive(on: DispatchQueue.main)` in `Sources/StateKit/Use/usePublisher/usePublisher.swift`, `usePublisherPerform.swift`, `usePublisherRefresh.swift`; run T008 to green (also re-run T006 suites — both touch the same closures)

## Phase 5: User Story 3 — Interceptor removal (P2)

**Goal**: provider→atom watch no longer leaks a permanent interceptor; count returns to baseline.
**Independent test**: `swift test --filter InterceptorRemovalTests` + `swift test --filter BridgeInterceptorCleanupTests`.

- [X] T010 [US3] RED: write store-level tests in `Tests/StateKitAtomsTests/InterceptorRemovalTests.swift` (register → notified; remove → not notified; double-remove no-op; closure released after removal); run, observe failure
- [X] T011 [US3] GREEN: wire T010 against the T002 API; fix any store semantics gaps (snapshot iteration in `notifyInterceptors`)
- [X] T012 [US3] RED→GREEN: bridge test in `Tests/RiverpodsTests/BridgeInterceptorCleanupTests.swift` (N create/dispose cycles → store interceptor count returns to baseline; surviving element still invalidates), then update `Sources/Riverpods/Core/EcosystemBridge.swift` `watch` to hold its token and remove it in `onDispose`

## Phase 6: User Story 4 — DevToolsObserver receives updates (P2)

**Goal**: the observer's update callback is the protocol witness and provably records.
**Independent test**: `swift test --filter DevToolsObserverRecordingTests`.

- [X] T013 [US4] RED: write container-level test in `Tests/StateKitDevToolsTests/DevToolsObserverRecordingTests.swift` (observer on real `ProviderContainer`, update provider → history entry recorded; add/dispose callbacks pinned); run, observe failure (zero entries)
- [X] T014 [US4] GREEN: rename `previousValue:` → `oldValue:` in `Sources/StateKitDevTools/Observers/DevToolsObserver.swift` `didUpdateProvider`; run T013 to green

## Phase 7: User Story 5 — Provider elements do not self-retain (P2)

**Goal**: abandoned Future/Stream/AsyncSequence elements deallocate.
**Independent test**: `swift test --filter ProviderElementDeallocationTests`.

- [X] T015 [US5] RED: write deallocation tests in `Tests/RiverpodsTests/ProviderElementDeallocationTests.swift` (container released without explicit dispose → weak element refs nil for all three element types; explicit dispose still cancels work); run, observe failure
- [X] T016 [US5] GREEN: change `onDispose { self… }` → `onDispose { [weak self] … }` in `Sources/Riverpods/Providers/FutureProvider.swift`, `Sources/Riverpods/Providers/StreamProvider.swift`, `Sources/Riverpods/Providers/AsyncSequenceProvider.swift`; run T015 to green

## Phase 8: User Story 6 — ABTest empty-variants guard (P3)

**Goal**: `assignUser` on a zero-variant test returns nil, never traps.
**Independent test**: `swift test --filter ABTestEmptyVariantsTests`.

- [X] T017 [US6] RED→GREEN: test in `Tests/StateKitFeatureFlagsTests/ABTestEmptyVariantsTests.swift` (empty variants × trafficPercentage 0/100 → nil, no crash), then add `guard !variants.isEmpty else { return nil }` in `Sources/StateKitFeatureFlags/ABTestFramework.swift` `assignUser`

## Phase 9: User Story 7 — StateDevScope render counting DEBUG-only (P3)

**Goal**: no self-sustaining re-render loop in Release; Debug counting no longer invalidates itself.
**Independent test**: `swift test --filter StateDevScopeRenderCountTests`.

- [X] T018 [US7] RED→GREEN: extract the counting mechanism into a DEBUG-gated helper testable via `Tests/StateKitDevToolsTests/StateDevScopeRenderCountTests.swift` (quiescent body passes stop enqueueing), wrap the enqueue/increment in `Sources/StateKitDevTools/StateDevTools.swift` `StateDevScope` with `#if DEBUG` mirroring the overlay strip. Verification split (constitution VII): the automated part is the Debug quiescence test; Release removal is a build-time condition verified greppably (`#if DEBUG` encloses the enqueue/increment) — stated as assumption, not a host-test criterion.

## Phase 10: User Story 8 — EventTracker bounded retention (P3)

**Goal**: no unbounded retained event history; opt-in capped retention with drop-oldest.
**Independent test**: `swift test --filter EventTrackerRetentionTests`.

- [X] T019 [US8] RED: write tests in `Tests/StateKitAnalyticsTests/EventTrackerRetentionTests.swift` (default: retained history bounded after thousands of tracked+flushed events; opt-in cap N: drop-oldest; track/flush contract unchanged); run, observe failure
- [X] T020 [US8] GREEN: rework `Sources/StateKitAnalytics/EventTracker.swift` retention (`events` mirror becomes capped opt-in debug tooling, ring-buffer drop-oldest, documented); run T019 to green

## Phase 11: User Story 9 — Keychain write ordering (P3)

**Goal**: failed store never destroys the previous secret nor commits state prematurely.
**Independent test**: `swift test --filter KeychainWriteOrderingTests`.

- [X] T021 [US9] RED: write tests in `Tests/StateKitPersistenceTests/KeychainWriteOrderingTests.swift` using existing error-injection patterns (failing provider: `updateValue` throws and state unchanged; failing batch item: previous value readable, error surfaced); run, observe failure
- [X] T022 [US9] GREEN: `Sources/StateKitPersistence/KeychainStateProvider.swift` — `KeychainNotifier.updateValue` stores before committing `state`; `KeychainBatch.store` switches to update-then-insert (`errSecItemNotFound` → add), fail-fast with thrown error; run T021 to green

## Phase 12: User Story 10 — DeterministicTimeProvider.advance (P3)

**Goal**: advance mutates time by the interval.
**Independent test**: `swift test --filter DeterministicTimeAdvanceTests`.

- [X] T023 [US10] RED→GREEN: test in `Tests/StateKitTests/DeterministicTimeAdvanceTests.swift` (advance 60s from T → T+60; negative interval moves backwards), fix `Sources/StateKitTesting/Deterministic/DeterministicTesting.swift` `advance(by:)` to assign `currentTime = currentTime.addTimeInterval(interval)`

## Phase 13: Polish & Cross-Cutting

- [X] T024 [P] Add `docs/release/CHANGELOG.md` entry for the behavior changes (DevToolsObserver recording live, ABTest nil on empty variants, EventTracker retention opt-in, Keychain ordering, interceptor deprecation note) — constitution VIII
- [X] T025 Run full quality gates: `swift build` + `swift test` (zero failures, zero unexpected skips); verify no package-internal deprecation warnings from the `addInterceptor` migration; mark tasks and update tasks.md checkboxes as each completes

## Dependencies

- T002 (interceptor API) blocks T010–T012.
- T001 scaffolding blocks T003–T007.
- T006 and T009 both edit publisher hook sinks: implement T006 (weak box) before T009 (receive-on-main).
- All other stories are independent of each other (different files/targets) and can proceed in parallel.

## Parallel Execution Examples

- After T001+T002: US1 (T003–T007), US2 (T008–T009), US4 (T013–T014), US5 (T015–T016), US6–US10 each
  touch disjoint targets and can run concurrently.
- T024 can run any time after US3/US4/US6/US8/US9 land.

## Implementation Strategy

- MVP: Phases 1–4 (T001–T009) — the two P1 stories (largest production risk: leaks + data race).
- Then P2 lifecycle stories (US3–US5), then the P3 one-liners (US6–US10), then gates.
- Red→green is mandatory per story; record the red observation in the task checkbox completion note.
