# Implementation Plan: P2 Hardening + CI/Docs Batch

**Branch**: work committed straight to `main` (repo convention) | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

## Summary

Nine remediation stories from the 2026-11-05 review's P2/P3 list: stable identity for
named providers (inline-leak), three concurrency-contract fixes (useReducer re-entrancy,
Debounce race, bounded propagation), persistence correctness (file race, SwiftData
reload), stream ordering, honest notifier docs, CI hardening (blocking lint, Xcode pin,
SPM cache, experimental TSan), dead-dependency removal, reference-doc sync, and a real
`1.0.0` release tag.

## Technical Context

**Language/Version**: Swift 6.2 (swift-tools-version 6.2), SPM

**Primary Dependencies**: swift-syntax (macros); removing swift-composable-architecture
(zero imports verified at tip)

**Testing**: Swift Testing + XCTest via `swift test` (396 green at 904b1d0)

**Target Platform**: macOS host for tests; package declares 5 platforms

**Performance Goals**: unchanged suite runtime; LRU/path hot code untouched

**Constraints**: public API signatures unchanged except the documented named-identity
contract (FR-001/FR-003 — public provider inits derive `_id` from name when provided)

**Scale/Scope**: ~8 source files, ~4 test files, 2 workflows, 3 docs

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Modular Layering | ✅ PASS | Removing a dep; no new edges |
| II. React-Hooks Parity | ✅ PASS | useReducer fix restores React drain semantics (queued re-entrancy captured) |
| III. Unidirectional Data Flow | ✅ PASS | Bounded propagation keeps flow unidirectional; cap = loud debug report |
| IV. Loud Failures | ✅ PASS | Flush bound reports loudly in DEBUG; debounce/reducer fixes fail softly by design contract |
| V. Docs Tell the Truth | ✅ PASS | Notifier docs corrected; inventory/test-plan synced |
| VI. Test-First for Defects | ✅ PASS | Regression test per fix; propagation-bound test red-phase would hang at tip (documented exception, verified by construction + green) |
| VII. Versioning | ✅ PASS | Tag `1.0.0` per V1 convention + README guidance |
| VIII. Workspace rules | ✅ PASS | No workspace noise committed |

## Project Structure

```text
specs/011-p2-hardening-ci/
├── plan.md (this) | research.md | data-model.md | quickstart.md
├── contracts/public-api.md
└── tasks.md

Sources/Riverpods/Core/ProviderID.swift            # (identity via public inits, see below)
Sources/Riverpods/Providers/{Provider,FutureProvider,NotifierProvider,StateProvider,
  StreamProvider,AsyncSequenceProvider,AsyncNotifierProvider}.swift  # _id from name
Sources/Riverpods/Container/ProviderContainer.swift # flushChanges round cap
Sources/Riverpods/Providers/StreamProvider.swift    # serialized state writes
Sources/StateKit/Use/useReducer.swift               # drain under flag
Sources/StateConcurrency/Actions/DebouncedAction.swift # atomic cancel+store
Sources/StateKitPersistence/{FileAtom.swift,SwiftDataIntegration.swift}
Sources/Riverpods/Providers/NotifierProvider.swift  # docs only
.github/workflows/{ci.yml}
Package.swift + Package.resolved                     # drop TCA
docs/core/PUBLIC_API_INVENTORY.md, Tests/UNIT_TEST_PLAN.md, docs/release/CHANGELOG.md
```

**Structure Decision**: surgical edits + one new regression test file per affected
target area; identity fix touches the 7 provider public inits (single pattern).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
