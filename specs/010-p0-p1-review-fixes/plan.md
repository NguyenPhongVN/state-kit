# Implementation Plan: P0/P1 Review Fixes (Riverpods Engine + CI Docs)

**Branch**: `010-p0-p1-review-fixes` (work committed straight to `main` per repo convention) | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/010-p0-p1-review-fixes/spec.md`

## Summary

Fix 8 defects from the 2026-11-05 quality review: one P0 crash (`overrideWithProvider`),
five P1 behavioral bugs in the Riverpods engine (keep-alive idempotency, double resume,
cross-container dispose/edge bookkeeping, override-scope parent fallback, async completion
events never reaching container listeners), one broken docs-publish pipeline step, and two
vacuous test assertions. All fixes are behavior-only — no public API signature changes —
and every fix ships with a regression test that fails without it.

## Technical Context

**Language/Version**: Swift 6.2 (swift-tools-version 6.2), SPM package

**Primary Dependencies**: swift-syntax (macros, untouched here), ComposableArchitecture
(declared on StateConcurrency, untouched here), swift-clocks / CasePaths (transitive)

**Storage**: N/A (in-memory provider graphs)

**Testing**: Swift Testing (`@Test`, `#expect`) + XCTest; suite runs via `swift test`
(385 tests green at review tip). Memory lesson: never pipe test output for exit codes.

**Target Platform**: macOS host for tests; package declares iOS/tvOS/watchOS/visionOS

**Project Type**: Swift library (16 source targets, 13 test targets)

**Performance Goals**: unchanged — existing suite runtime (~seconds) preserved

**Constraints**: public API signatures MUST NOT change (FR-010); fixes must be
@MainActor-confined consistent with the existing engine design

**Scale/Scope**: 6 source files + 2 test files touched, 1 CI workflow, 1 new regression
test file (~10 test cases)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Modular Layering | ✅ PASS | Fixes stay inside `Riverpods` (container/element/providers/scope); no new cross-module edges, no cycles introduced |
| II. React-Hooks Parity | ✅ PASS | Hooks target untouched |
| III. Unidirectional Data Flow with Loud Cycles | ✅ PASS | Fixes align behavior with documented contracts (resume-once, completion events flow through the normal propagation path) |
| IV. Loud Failures | ✅ PASS | Override diagnostic keeps failing loudly for *genuinely* wrong override kinds; the fixed path only stops crashing on valid subclass elements |
| V. Docs Tell the Truth | ✅ PASS | This feature exists because code contradicted docs; fixes bring code in line with documented contracts |
| VI. Test-First for Defects | ✅ PASS | FR-009: regression test per fix; tests written to fail without the fix |
| VII. Versioning | ✅ PASS | No API change → no VERSIONING bump beyond changelog entry |
| VIII. Memory/Workspace rules | ✅ PASS | `.opencode/`, `config/` stay untracked; no workspace noise committed |

## Project Structure

### Documentation (this feature)

```text
specs/010-p0-p1-review-fixes/
├── plan.md              # This file
├── research.md          # Phase 0: defect verification + fix decisions
├── data-model.md        # Phase 1: affected entities/state transitions
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   └── public-api.md    # Phase 1: no-signature-change contract
└── tasks.md             # Phase 2 output (NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
Sources/Riverpods/
├── Container/ProviderContainer.swift   # P0 ensureElement override check; checkAutoDispose owner resolution
├── Container/ProviderElement.swift     # keepAlive idempotency; getState() double-resume; clearDependencyEdges parent lookup
├── Providers/FutureProvider.swift      # completion → external listeners (success + failure)
├── Providers/StreamProvider.swift      # completion → external listeners (events)
└── SwiftUI/ProviderScope.swift         # overrides scope falls back to parent container

.github/workflows/docs.yml              # deterministic doccarchive path + empty-guard

Tests/RiverpodsTests/
└── P0P1ReviewFixRegressionTests.swift  # NEW: regression tests for all fixes above

Tests/StateKitCacheTests/CacheCorrectnessTests.swift      # rewrite #expect(true)
Tests/StateKitDevToolsTests/DevToolsObserverRecordingTests.swift  # rewrite #expect(true)
```

**Structure Decision**: single SPM package, existing layout unchanged; fixes are
surgical edits inside the identified files plus one new test file.

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
