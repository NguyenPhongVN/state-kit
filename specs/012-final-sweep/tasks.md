# Tasks: Final Sweep

**Feature**: 012-final-sweep | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

## Phase 1: Pins (US2)

- [X] T001 Write TTL expiry pin test in `Tests/StateKitCacheTests/`: expired entry → onExpire only; manual remove → onEvict(.manual); capacity → onEvict(.capacityExceeded)
- [X] T002 Write geolocation pins in `Tests/StateKitFeatureFlagsTests/`: allowed region true, disallowed false, nil resolver false

## Phase 2: Logging (US1)

- [X] T003 Switch `CompositionDebugger` diagnostics to the unified system logger (subsystem "app.statekit.riverpods"), signatures and gates unchanged (Sources/Riverpods/Composition/NotifierComposition.swift)
- [X] T004 Switch DevToolsObserver + DebugProviderObserver prints to the system logger (subsystem "app.statekit.devtools"), existing log flags gate emission (Sources/StateKitDevTools/Observers/)

## Phase 3: Docs sweep (US3)

- [X] T005 Fix SKStatus MARK/doc referencing non-existent AsyncSequenceStatus/PublisherStatus types (Sources/StateKit/Core/StatePhases/SKStatus.swift:16-21)
- [X] T006 Rename PerformerActor → SKGlobalActor in SCGlobalActor doc examples (Sources/StateConcurrency/SKTask/Objects/SCGlobalActor.swift)
- [X] T007 Fix ThrottledAction doc example to match the sync callAsFunction signature (Sources/StateConcurrency/Actions/ThrottledAction.swift:13-17)

## Phase 4: Repo hygiene (US4)

- [X] T008 Remove bare `Package.resolved` from `.gitignore` (tracking resolved pins is deliberate); untrack the 3 xcuserdata/IDE plists (`git rm --cached`)

## Phase 5: Coverage (US5)

- [X] T009 Add `StateKitTestingTests` target to Package.swift (library product unchanged); write tests for DeterministicTestEnvironment (freeze/advance/now, random determinism, async drain) + IntegrationTestHelpers core contract
- [X] T010 Add `Tests/StateKitSupportTests/StateKitSupportCoverageTests.swift`: happy-path + teardown pins for useCountdown, useLastValue, useSeen, useLoadMore

## Phase 6: CI + lint (US6)

- [X] T011 Add `build-ios` job to `.github/workflows/ci.yml` (xcodebuild generic iOS destination, library only)
- [X] T012 Install SwiftLint, run with repo config; fix bounded violations until zero errors; record result in tasks log

## Phase 7: Gate & ship

- [X] T013 Full suite green (`swift test` unpiped) + changelog entry + production-review row + commit/push straight to main

## Dependencies

- T001/T002 parallel (different targets) → T013
- T003/T004 parallel → T013
- T005/T006/T007 parallel → T013
- T008 independent → T013
- T009 → T013 (manifest change → full rebuild)
- T011/T012 independent → T013

## Implementation Strategy

- Pins first (cheap insurance), then logging, docs, hygiene — each independently
  verifiable; manifest change (T009) triggers the full rebuild so it lands before the
  final gate; lint verification (T012) before the gate to guarantee FR-008.
