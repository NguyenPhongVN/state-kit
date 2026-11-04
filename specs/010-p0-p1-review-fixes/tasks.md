# Tasks: P0/P1 Review Fixes (Riverpods Engine + CI Docs)

**Feature**: 010-p0-p1-review-fixes | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)
**Input**: FR-001 … FR-010 from spec.md; decisions R1–R9 from research.md

**Tests requested**: yes (FR-009 — regression test per fix; test-first per constitution VI)

## Phase 1: Setup

- [X] T001 Create regression test skeleton `Tests/RiverpodsTests/P0P1ReviewFixRegressionTests.swift` with suite header, event-recorder helpers and a container factory mirroring existing RiverpodsTests conventions
- [X] T002 Read current `KeepAliveLink` definition (`Sources/Riverpods/Core/ProviderRef.swift:328-362`) and `ProviderContainer.init` signature (`Sources/Riverpods/Container/ProviderContainer.swift:131`) to confirm parent parameter and closure shape before edits

## Phase 2: Foundational (blocking)

- [X] T003 Verify baseline: run `swift test` unpiped at tip `4694ea5` state; record pass count so post-fix deltas are attributable (memory lesson: never pipe test output in zsh)

## Phase 3: User Story 1 — Override-by-provider works (Priority: P1) 🎯 MVP

**Goal**: `overrideWithProvider` stops crashing and serves the replacement value for all provider kinds.
**Independent Test**: container + provider + override-by-provider → read returns mock value, no crash.

- [X] T004 [US1] Write failing regression tests in `Tests/RiverpodsTests/P0P1ReviewFixRegressionTests.swift`: override-by-provider on standard provider and on FutureProvider serves replacement value without crash (fails at tip per R1)
- [X] T005 [US1] Fix `ensureElement` override validation in `Sources/Riverpods/Container/ProviderContainer.swift:220-229`: replace metatype-equality diagnostic with cast-based check (`element is ProviderElement<P>`), keep `fatalError` for genuinely wrong override kinds; value-override path (line 244-258) untouched
- [X] T006 [US1] Confirm value-override regression tests still pass (no behavior change, FR-002); run RiverpodsTests target

## Phase 4: User Story 2 — Listener event correctness (Priority: P1)

**Goal**: resume fires exactly once per subscription; container listeners receive async completion events.
**Independent Test**: event recorder on fresh provider → exactly one resume; future listener → success + failure events received.

- [X] T007 [US2] Write failing regression tests: (a) listen fire-immediately on never-computed provider records exactly one resume; (b) container.listen on FutureProvider receives success event with value; (c) receives failure event on error; (d) synchronous providers keep existing event behavior
- [X] T008 [US2] Fix double-resume in `Sources/Riverpods/Container/ProviderElement.swift:152-158`: remove `.resume` fire from `getState()` (0→1 transition in `incrementListeners` owns the signal per R3)
- [X] T009 [US2] Publish async completion to external listeners: add publish helper on `ProviderElement` and call it from `Sources/Riverpods/Providers/FutureProvider.swift:59-88` success + failure paths and `Sources/Riverpods/Providers/StreamProvider.swift:47-79` event paths (per R6)
- [X] T010 [US2] Sweep suites pinning resume/completion event counts (`Tests/RiverpodsTests/`, `Tests/StateKitTests/`): update any test asserting the duplicated resume or missing completion event to the documented contract; list each adjusted test in the task log

## Phase 5: User Story 3 — Hierarchy dispose correctness (Priority: P1)

**Goal**: cross-container listener removal disposes in the owning container; dependency edges resolve across the parent chain; override scopes fall back to parent.
**Independent Test**: parent/child containers + auto-dispose provider → weak ref released after child removal; scope read matches shared state.

- [X] T011 [US3] Write failing regression tests: (a) child removeListener disposes parent-owned auto-dispose element (weak ref released via bounded polling); (b) parent back-edge cleared after child edge rebuild; (c) `ProviderScope(overrides:)` resolves unoverridden provider from shared parent (per R4/R5)
- [X] T012 [US3] Fix owner resolution in `checkAutoDispose` (`Sources/Riverpods/Container/ProviderContainer.swift:438-448`): resolve owner via `element.container ?? self`; mutate owner's `elements` and notify owner's observers (per R4)
- [X] T013 [US3] Fix parent-chain lookup in `clearDependencyEdges` (`Sources/Riverpods/Container/ProviderElement.swift:405-417`): replace `container.element(for:)` with parent-traversing `existingElement(for:)` (per R4)
- [X] T014 [US3] Wire parent in `ProviderScope.init(overrides:)` (`Sources/Riverpods/SwiftUI/ProviderScope.swift:171-178`): pass `parent: .shared` when building the overrides container (per R5)

## Phase 6: User Story 4 — Keep-alive idempotency (Priority: P2)

**Goal**: `KeepAliveLink.close()` is a no-op after first close; counter never negative.
**Independent Test**: two links, close one twice → provider alive; close both → disposed.

- [X] T015 [US4] Write failing regression test: double-close keeps provider alive while second link open; all-closed disposes; counter never negative (per R2)
- [X] T016 [US4] Fix `keepAlive()` in `Sources/Riverpods/Container/ProviderElement.swift:459-466`: capture `closed` flag in the `@MainActor` close closure; skip subsequent closes (per R2)

## Phase 7: User Story 5 — Docs pipeline works (Priority: P2)

**Goal**: docs publish finds the archive deterministically.
**Independent Test**: next real pipeline run locates + uploads non-empty artifact.

- [X] T017 [US5] Fix `.github/workflows/docs.yml:26-37`: add `-derivedDataPath .build` to `xcodebuild docbuild`; make "Find documentation archive" exit 1 with a clear message when no archive is found (per R7)

## Phase 8: User Story 6 — Meaningful test assertions (Priority: P3)

**Goal**: the two vacuous assertions pin real behavior.
**Independent Test**: rewritten assertions fail if observed behavior regresses.

- [X] T018 [US6] Rewrite `#expect(true)` in `Tests/StateKitCacheTests/CacheCorrectnessTests.swift:88` to assert recorded didAddProvider/didDisposeProvider callbacks actually fired (per R8)
- [X] T019 [US6] Rewrite `#expect(true)` in `Tests/StateKitDevToolsTests/DevToolsObserverRecordingTests.swift:50` to assert the returned unsubscribe token works — a post-unsubscribe event must not be recorded (per R8)

## Phase 9: Polish & Cross-Cutting

- [X] T020 Update `docs/release/CHANGELOG.md` Fixed section with migration-safe entries for the six behavior fixes (no signature changes; reference contracts/public-api.md)
- [X] T021 Mark spec 010 as implemented: update `docs/production-review-2026-10-27.md` status table with a 010 row per repo convention
- [X] T022 Full-suite gate: run `swift test` unpiped; all suites green including new regression tests; commit fixes straight to `main` per repo convention (test file + source fixes + CI + docs in one remediation commit series)

## Dependencies

- T001→T003 block everything (baseline + harness)
- US1 (T004-T006) → independent, do first (MVP)
- US2 (T007-T010) → independent of US1; T008 before T010 (contract change ripples)
- US3 (T011-T014) → independent; T012/T013 same-day pair (dispose + edges)
- US4 (T015-T016) → independent
- US5 (T017), US6 (T018-T019) → fully independent
- Polish (T020-T022) → after all stories

## Parallel Execution Examples

- US1+US4 files are disjoint → T005 and T016 can proceed in parallel
- US5 + US6 (CI + test files) parallel with any Riverpods story
- US2 and US3 both touch `ProviderElement.swift` — serialize to avoid edit conflicts

## Implementation Strategy

- MVP = Phase 3 (US1): kills the only 100%-crash public API
- Then US2/US3 (P1 engine correctness), US4, then US5/US6/Polish
- Every source fix lands together with its regression test in the same commit
