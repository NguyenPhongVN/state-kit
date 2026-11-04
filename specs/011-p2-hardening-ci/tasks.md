# Tasks: P2 Hardening + CI/Docs Batch

**Feature**: 011-p2-hardening-ci | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

**Tests requested**: yes (FR-015 — regression test per code fix)

## Phase 1: Setup

- [X] T001 Create `Tests/RiverpodsTests/P2HardeningRegressionTests.swift` (identity, flush bound, stream order suites) and note test files for reducer/debounce/persistence additions
- [X] T002 Baseline: confirm suite green at tip (`swift test` unpiped; 396 at 904b1d0)

## Phase 2: User Story 1 — Named provider identity (P1) 🎯 MVP

- [X] T003 [US1] Write failing tests: two same-named same-type instances share one element (compute count 1); distinct names distinct; same name different value types distinct
- [X] T004 [US1] Derive `_id` from `name` in the 7 public provider inits: `name.map { AnyHashable("\($0)#\(String(describing: T.self))") } ?? UUID()` (Provider, FutureProvider, StreamProvider, NotifierProvider, StateProvider, AsyncSequenceProvider, AsyncNotifierProvider); family internal inits untouched
- [X] T005 [US1] Document the named-identity contract on each affected init doc line (one sentence: same name + type = one element)

## Phase 3: User Story 2 — Concurrency contracts (P1)

- [X] T006 [US2] Write failing test: dispatch from inside a queued reduce lands in final state (useReducer)
- [X] T007 [US2] Fix `useReducer` drain: keep `isDispatching` raised through the drain loop; queue re-entrancy during drain (Sources/StateKit/Use/useReducer.swift:113-135)
- [X] T008 [US2] Write failing test: two same-tick debounce invocations schedule exactly one operation with latest input
- [X] T009 [US2] Fix `DebouncedAction.callAsFunction`: serialize cancel+create+store under one NSLock critical section (Sources/StateConcurrency/Actions/DebouncedAction.swift)
- [X] T010 [US2] Add bounded propagation to `flushChanges`: round counter (constant 100), DEBUG diagnostic on bound hit (ProviderContainer.swift) — **verification note:** no public-surface regression test is feasible: a recompute-based listener ping-pong is already stopped by the existing cycle detector (loud fatal at ProviderElement.swift:186), and notifier-write ping-pong recurses the stack before the flush loop matters. The cap ships as depth-defence; the planned ping-pong test was removed after it reproduced the pre-existing cycle fatal, not a hang (TDD exception recorded in research R4).

## Phase 4: User Story 3 — Persistence correctness (P1)

- [X] T011 [US3] Write tests: multi-thread save/load stress on FileAtomStorage completes validly; re-created SwiftDataNotifier loads persisted value
- [X] T012 [US3] Guard `cachedValue` in `load`/`save`/`delete` with the existing NSLock (Sources/StateKitPersistence/FileAtom.swift)
- [X] T013 [US3] SwiftDataNotifier: hold `key`; `build()` fetches + decodes `SwiftDataStateRecord`, falls back to `initialState` (Sources/StateKitPersistence/SwiftDataIntegration.swift)

## Phase 5: User Story 4 — Stream ordering (P2)

- [X] T014 [US4] Write failing test: burst 1→2→3 records state transitions in emission order
- [X] T015 [US4] Serialize StreamProviderElement state writes through a per-element write chain (await previous task before publishing; failure enqueued on same chain) (Sources/Riverpods/Providers/StreamProvider.swift)

## Phase 6: User Stories 5+7 — Docs truth & dependency hygiene (P3/P2)

- [X] T016 [P] [US5] Rewrite Notifier doc block: drop the Observable claim, document actual propagation path (NotifierProvider.swift:62-119)
- [X] T017 [P] [US7] Remove ComposableArchitecture from Package.swift (top-level + StateConcurrency target); resolve to regenerate Package.resolved; commit lockfile

## Phase 7: User Story 6 — CI hardening (P2)

- [X] T018 [US6] ci.yml: drop `continue-on-error` from lint job (keep `--quiet`; note `--strict` deferred until warning-clean)
- [X] T019 [US6] ci.yml: explicit Xcode selection step resolving the declared tools version from installed Xcodes, failing loudly with candidates when absent
- [X] T020 [US6] ci.yml: add `actions/cache@v4` for `.build` keyed on `Package.resolved`
- [X] T021 [US6] ci.yml: add experimental thread-sanitizer job (`swift test --sanitize=thread`, `continue-on-error: true` + promotion comment)

## Phase 8: User Story 8 — Reference docs sync (P3)

- [X] T022 [P] [US8] PUBLIC_API_INVENTORY.md: add date-stamped "Added since 2026-09-22" section (SKInterceptorToken, removeInterceptor, AnalyticsConfig(historyCap:), 010 fixes note); update header date note
- [X] T023 [P] [US8] UNIT_TEST_PLAN.md: correct target list to the 13 actual targets, remove phantom StateKitMacroIntegrationTests, mark unmet exit criteria explicitly

## Phase 9: Polish & Release

- [X] T024 CHANGELOG.md entry for 011 (Fixed/Changed sections; named-identity contract callout)
- [X] T025 Full-suite gate: `swift test` unpiped green + Examples build; commit straight to main
- [X] T026 Push origin main; after CI trigger, cut annotated tag `1.0.0` on the release commit and push it (SC-009)

## Dependencies

- T001→T002 → all stories
- US1 (T003-T005) independent; do first (MVP)
- US2 (T006-T010) independent (reducer/debounce/flush in different modules)
- US3 (T011-T013) independent; US4 (T014-T015) independent
- T016/T017 parallel (docs + manifest)
- T018-T021 same file (ci.yml) — sequential
- T022/T023 parallel docs
- T024-T026 last

## Parallel Execution Examples

- T004 (Riverpods providers) ∥ T007 (StateKit) ∥ T009 (StateConcurrency) ∥ T012-T013 (Persistence)
- T016 ∥ T017 ∥ T022 ∥ T023 (disjoint files)

## Implementation Strategy

- MVP = US1 (named identity — kills the inline-provider leak)
- Then US2/US3/US4 (engine + persistence correctness), US5+US7, US6 (CI), US8 (docs), release last
