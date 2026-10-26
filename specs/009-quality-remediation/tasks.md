# Tasks: Quality Remediation — Remaining Review Findings

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Behavior fixes ship regression tests (red→green where the old behavior was host-observable);
doc-only fixes are verified by grep parity. Clusters commit incrementally so the tree is always
green between them.

## Phase 1: US2 — Riverpods semantics (P2)

- [ ] T001 RED: notifier listen tests (`Tests/RiverpodsTests/NotifierListenTests.swift`) — `container.listen` + `ref.listen` fire on `notifier.state = x` for Notifier and AsyncNotifier; observers see `notifyProviderUpdated`; run, observe failure
- [ ] T002 GREEN: route notifier `onUpdate` through a shared publish helper (equality-checked external listeners + `notifyProviderUpdated`) in `Sources/Riverpods/Providers/NotifierProvider.swift` and `Sources/Riverpods/Providers/AsyncNotifierProvider.swift`
- [ ] T003 RED→GREEN: `removeListener` resolves parent-served elements in `Sources/Riverpods/Container/ProviderContainer.swift` (test in `Tests/RiverpodsTests/`)
- [ ] T004 RED→GREEN: dependency edges rebuild per recompute + `_dependentRefs` dedupes by identity in `Sources/Riverpods/Container/ProviderElement.swift` (conditional-watch test: A-change no recompute, B-change recompute, autoDispose B releasable)
- [ ] T005 RED→GREEN: `FutureProvider.future` throws after failed refresh (`Sources/Riverpods/Providers/FutureProvider.swift` — check `.error` before the `.value` fast path)
- [ ] T006 RED→GREEN: `AsyncNotifier` dispose cancels `task` + resumes `_futureContinuation` with `CancellationError` (`Sources/Riverpods/Providers/AsyncNotifierProvider.swift`; internal `_teardown()` called from element dispose)
- [ ] T007 GREEN: recompute cycle fallback fails loudly in Release (`Sources/Riverpods/Container/ProviderElement.swift:169-174` — fatalError instead of providerCreate retry)
- [ ] T008 GREEN: `disposeDelayTask` cancelled in `dispose()` and `incrementListeners()`; `flushChanges` uses `defer`; `@ObservationIgnored` on `elements`/`recomputePath`/`_recomputePathSet` (`Sources/Riverpods/Container/ProviderContainer.swift`, `ProviderElement.swift`)
- [ ] T009 GREEN: doc honesty in `StateProvider.swift` (partial mutation trap), `Read.swift` (reactive table), `EcosystemBridge.swift` RiverpodAtom claims (fixed or corrected)

## Phase 2: US1 — Weak element↔container link (P1)

- [ ] T010 RED: container-release deallocation test (`Tests/RiverpodsTests/ContainerReleaseDeallocationTests.swift`) — mixed listened/unlistened elements + in-flight work; container release deallocates container and elements; run, observe failure
- [ ] T011 GREEN: `ProviderElement.container` → `weak var container: ProviderContainer?` (`Sources/Riverpods/Container/ProviderElement.swift`); `guard let container` at all element call sites (recompute/watch/read/listen/notify/checkAutoDispose/dispose paths in `ProviderElement.swift` + the three async provider files); async work with nil container exits silently
- [ ] T012 GREEN: regression sweep — full Riverpods test target must stay green after the refactor; changelog migration note for `element.container` optionality

## Phase 3: US3 — Hook semantics (P2)

- [ ] T013 RED→GREEN: `useTransition` keeps `isPending` until the last overlapping start finishes (`Sources/StateKit/Use/useDeferred.swift` — in-flight counter via slot ref); test in `Tests/StateKitTests/`
- [ ] T014 RED→GREEN: un-caused `CancellationError` surfaces as `.failure` in `useAsyncPerform`/`useAsyncRefresh` (`Sources/StateKit/Use/UseAsync/*.swift` — `catch is CancellationError where Task.isCancelled` vs otherwise failure); tests
- [ ] T015 GREEN: render-time writes follow the deferred policy consistently — `useAsyncSequence` `.loading`, `useAsyncPerform`/`useAsyncRefresh` idle-on-strategy-change, publisher `.idle` reset routed through `_safeUpdate` (`Sources/StateKit/Use/**/*.swift`); Just() delivery lands before next observed read
- [ ] T016 GREEN: effect slot mismatch fails loudly via shared internal `slot<T>()` accessor (`Sources/StateKit/Use/useEffect.swift`, `useLayoutEffect.swift` + adoption where trivial)
- [ ] T017 GREEN: `StateContext.states`/`context` → `public private(set)`; `StateRuntime.context` outside a render fails loudly (`Sources/StateKitCore/ScopedState/StateContext.swift`, `StateRuntime.swift`); fix internal usages
- [ ] T018 GREEN: `useReducer` dispatch tolerates one re-entrant level (copy-mutate-assign) (`Sources/StateKit/Use/useReducer.swift`); test

## Phase 4: US4+US5 — Persistence & cache (P2)

- [ ] T019 RED→GREEN: `KeychainNotifier.build` surfaces retrieval failure (error state instead of silent initial); `decodingFailed` thrown on decode error (`Sources/StateKitPersistence/KeychainStateProvider.swift`)
- [ ] T020 RED→GREEN: `PersistentAtomStorage.save` throws on encode failure (no observer notify on failure); `observeChanges()` replaced by `AsyncStream` API (`Sources/StateKitPersistence/UserDefaultsAtom.swift`)
- [ ] T021 GREEN: `FileAtomStorage` optional `onCorruption` hook + `fileAtom` caches loaded value; `PersistenceMigration` persists schema version (`Sources/StateKitPersistence/FileAtom.swift`, `UserDefaultsAtom.swift`); tests
- [ ] T022 GREEN: keychain service namespace (`init(service:)` → `kSecAttrService`) + `.always` removed from `KeychainAccessibility` (changelog); tests updated
- [ ] T023 RED→GREEN: `SlidingWindowTTLCache.get` eager expiry check without refreshing expired entries (`Sources/StateKitCache/TTLCache.swift`); test
- [ ] T024 GREEN: sweep interval floor `max(ttl/2, 1.0)` (`TTLCache.swift`); test with tiny TTL counts wakeups indirectly (interval property exposed internally)
- [ ] T025 RED→GREEN: single-flight `cacheAside` (per-key in-flight task map) in `Sources/StateKitCache/CachePolicy.swift` (+ `SKAsyncCache` load-through helper); concurrent-miss test (fetcher runs once)
- [ ] T026 RED→GREEN: `clear()` fires `onEvict(.cleared)` (`Sources/StateKitCache/LRUCache.swift` both classes); test
- [ ] T027 GREEN: `SKAsyncCache.sweepExpired` collects keys first; remove `.batch` case (`Sources/StateKitCache/SKAsyncCache.swift`, `CachePolicy.swift`); `MemoryPressureHandler.wireToSystemNotifications()` helper; tests updated

## Phase 5: US6 — Flags & analytics (P2)

- [ ] T028 RED→GREEN: remote overrides win over local; `applyRemoteOverrides` replaces stale bool entries; `clearAllOverrides` clears both stores (`Sources/StateKitFeatureFlags/StateKitFeatureFlags.swift`, `RemoteFlags.swift`); tests
- [ ] T029 RED→GREEN: salted bucketing `"\(id):\(userKey)"` in `ABTest.assignUser` and `PercentageRollout` (`Sources/StateKitFeatureFlags/*.swift`); stability + independence tests (two known ids across two experiment ids)
- [ ] T030 RED→GREEN: `FunnelAnalyzer` ordered progression + `totalCompletions` counts users (`Sources/StateKitAnalytics/UserJourney.swift`); tests for `[purchase, view]` (no completion) and `[view, cart, purchase]` (completion)
- [ ] T031 RED→GREEN: `UserJourneyTracker` bounds sessions/journeys (max N, default 20) and buffers inter-session events onto the next session (`Sources/StateKitAnalytics/UserJourney.swift`); tests
- [ ] T032 RED→GREEN: `EventTracker.flush` re-queues batch when callback returns `false` (new `onFlushResult` accepting `-> Bool`; old void callback treated as success) (`Sources/StateKitAnalytics/EventTracker.swift`); test
- [ ] T033 GREEN: `includeValues` serializes values; `persistLocal` writes flushed batches as JSON lines (1 MB truncate rotation) (`Sources/StateKitAnalytics/StateKitAnalytics.swift`, `EventTracker.swift`); tests

## Phase 6: US7+US8 — DevTools & testing honesty (P2)

- [ ] T034 GREEN: `DevToolsObserver` republishes a `revision` on record; `ObservedDevToolsObserver` observes it so views update (`Sources/StateKitDevTools/Observers/DevToolsObserver.swift`, `UI/DevToolsView.swift`, `DevToolsHandle.swift` badge)
- [ ] T035 GREEN: `InMemoryPerformanceMetrics` caches aggregates per provider, drops records for disposed providers (`Sources/StateKitDevTools/Performance/PerformanceMetrics.swift`); test
- [ ] T036 RED→GREEN: `storeSnapshots = false` records entries with null snapshots (`Sources/StateKitDevTools/Observers/DevToolsObserver.swift`); test
- [ ] T037 RED→GREEN: `replay` clamps negative/NaN computeTime (`Sources/StateKitDevTools/History/StateHistory.swift`); test with imported hostile JSON
- [ ] T038 GREEN: `DeterministicTestEnvironment` wires seed → `DeterministicRandom`, exposed `env.random`; doc claims corrected (`Sources/StateKitTesting/Deterministic/DeterministicTesting.swift`); reproducibility test
- [ ] T039 GREEN: `IntegrationTestHelpers`: implement `override(_:with:)` storage + `build()` application and honest `verifyTransition`; DELETE `verifyWithinTimeout`, `measureMemory`, `FeatureTestHarness.observe`, `FixtureBuilder`, `CommonFixtures` nil stubs, `weightedRandom` trap (`Sources/StateKitTesting/**`); tests for the implemented ones; changelog removals
- [ ] T040 GREEN: test-facing assertion helpers record failures (`Issue.record`) instead of `fatalError` (`Sources/StateKitTesting/**`)

## Phase 7: US9 — Concurrency hardening (P2)

- [ ] T041 RED→GREEN: `Task.throwingTimeout` returns computed success (task-group race; no spurious timeout) (`Sources/StateConcurrency/SKTask/Task+Timeout.swift`); test racing completion+timeout edge; doc notes non-cancellable ops
- [ ] T042 RED→GREEN: `SKConcurrencyLimiter` handles cancelled-before-registration waiters (`Sources/StateConcurrency/SKTask/Objects/SCConcurrencyLimiter.swift` — isCancelled check before/after continuation registration); test
- [ ] T043 GREEN: `SKTaskDuration` clamps negative input; retry policy validates `multiplier > 0` (`Sources/StateConcurrency/SKTask/Objects/SCTaskDuration.swift`, `SCRetryPolicy.swift`); tests
- [ ] T044 GREEN: `AsyncSequence.publisher` honest docs + pump held for deinit-cancel (`Sources/StateConcurrency/SCAsyncSequence/AsyncSequence+Extensions.swift`); `MainActor.runImmediately` deadlock doc (`MainActor+Extensions.swift`); untyped NSError → typed error (`Task+Race.swift`)

## Phase 8: US10 — Macros (P2)

- [ ] T045 GREEN: `@Debounce` forwards parameters with last-call storage (`Sources/StateKitMacrosPlugin/UtilityMacros/DebounceMacro.swift`); expansion test with parameterized function
- [ ] T046 GREEN: `@HookForm` type-derived hook name + access propagation + diagnostic for non-defaulted non-optionals (`Sources/StateKitMacrosPlugin/Hooks/HookFormMacro.swift`); two-forms expansion test
- [ ] T047 GREEN: `@HookContext` per-type unique global name (`Sources/StateKitMacrosPlugin/Hooks/HookContextMacro.swift`); doc/declaration sync
- [ ] T048 GREEN: `@HookState` required-first ordering; `@HookEffect`/`@HookLayoutEffect`/`@HookAsync` preserve defaults + `await cleanup()` (`Sources/StateKitMacrosPlugin/Hooks/*.swift`); expansion tests for defaulted-before-required and `useLogger()`
- [ ] T049 GREEN: `@Atom` throws `onlyApplicableToStructs`; `@TaskAtom`/`@ThrowingTaskAtom` validate async/throws signature (qualified-name safe) (`Sources/StateKitMacrosPlugin/Atoms/*.swift`); diagnostic tests
- [ ] T050 GREEN: `@Provider` overload-safe names (arity suffix) + preserved defaults (`Sources/StateKitMacrosPlugin/Providers/ProviderMacro.swift`); `@HRef` defers initializer (`Sources/StateKitSupport/Hooks/@HookPropertyWrapper/HRef.swift`); tests

## Phase 9: US11 — P3 sweep (P3)

- [ ] T051 GREEN: delete dead code — `AnyEquatable`, `SKStatus` dead enums, duplicated `topologicallySortedDescendants`, duplicated `removeListener` doc block; grep-verified zero references first
- [ ] T052 GREEN: doc corrections — `useEnvironment` scanning claim, `SKAtomEffect` "not yet wired", `withLatestFrom` note, `HCount` naming, `SKTask` doc `context`, `StateKitCache` thread-safety claim, `UserDefaultsAtom`/`SwiftDataIntegration` pasted docs; `SwiftDataIntegration.updateAndPersist` persists state into a model or loses the claim (implement minimal keyed persistence)
- [ ] T053 GREEN: small traps — `djb2Hash` overflow-safe (`HashUtils.swift`), chi-square zero-denominator guard + control-arm comparison (`ABTestFramework.swift`), `useNow` interval guard (`useNow.swift`), `ObservableTask` deinit cancel (`ObservableTask.swift`), `ReplayReport` Sendable failure storage, `JSONValue.from` degradation surfaced, `EventLogger` join-based JSON, `toDictionary` reserved-key guard, `AsyncNotifier`/`Notifier` `_state!` → lazy materialization, `watch()` no-op warning in task-atom context docs

## Phase 10: Gates & release (must pass)

- [ ] T054 Full `swift build` + `swift test` green; Examples build green
- [ ] T055 `docs/release/CHANGELOG.md` entry (fixes + removals + optionality change + migration notes); grep-parity check over the review's doc claims; mark tasks; update review report statuses

## Dependencies

- T010–T012 (weak container) AFTER T001–T009 (semantics) — refactor touches the same files.
- T019–T022 independent of Riverpods clusters; T028–T033 independent; T034–T040 independent; T041–T044 independent; T045–T050 independent (macros last — needs compiler-plugin rebuild cycles).
- T054/T055 last.

## Implementation Strategy

Commit per phase (tree green between commits). Red→green observed per behavior fix; pins documented
where pre-fix behavior was not host-observable.
