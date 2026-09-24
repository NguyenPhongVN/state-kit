# Implementation Plan: DX Essentials (DocC, focusAtom, fileAtom, ErrorBoundary)

**Branch**: `006-dx-essentials` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

## Summary

Four developer-experience additions: (1) a DocC publishing workflow (CI-side only — no
package dependency) plus the documented local command; (2) `SKFocusAtom` + `.focus(_:)` — a
key-path lens over a state atom where reads derive reactively from the base and writes are
translated back into a base write (Jotai focusAtom idiom); (3) `fileAtom` — JSON-file-backed
atom persistence mirroring `userDefaultsAtom` for values beyond UserDefaults limits;
(4) `ErrorBoundary` — a SwiftUI view wrapping a throwing content closure with a fallback view
and optional onError hook (catches synchronous errors from its own content closure).

## Technical Context

**Language/Version**: Swift 6.2, iOS 17+/macOS 14+
**Primary Dependencies**: none added (DocC publishing is a CI-side action)
**Testing**: red→green tests per FR-06; new test coverage in StateKitAtomsTests,
StateKitPersistenceTests, StateKitUITests, StateKitDevToolsTests… (per feature)
**Performance Goals**: focus reads are derived (no copies); file I/O only on explicit save
**Constraints**: conventions rulebook compliance; no existing public API changes
**Scale/Scope**: 3 new source files + 1 workflow + tests + rulebook/DOCS links

## Constitution Check

| Gate | Status |
|------|--------|
| V (clean API, docs, tests-first) | Enforced per FR-06 |
| Zero new package dependencies (DocC is CI-side) | PASS |
| Gates green | FR-07 |

## Project Structure

```text
.github/workflows/docs.yml                       # DocC build + Pages publish
docs/engineering/CODING_CONVENTIONS.md           # + local DocC command (§8)
Sources/StateKitAtoms/Selector/SKFocusAtom.swift # SKFocusAtom + .focus(_:) + store write hook
Sources/StateKitAtoms/Core/SKAtomStore.swift     # setStateValue: focus write redirection
Sources/StateKitPersistence/FileAtom.swift       # FileAtomSerializable + FileAtomStorage + fileAtom
Sources/StateKitUI/ErrorBoundary.swift           # ErrorBoundary view
Tests/StateKitAtomsTests/SKFocusAtomTests.swift
Tests/StateKitPersistenceTests/FileAtomTests.swift
Tests/StateKitUITests/ErrorBoundaryTests.swift
```

**Structure Decision**: each feature lands in its natural home module with its own tests; no
cross-module changes except the focus write hook inside `SKAtomStore.setStateValue`.

## Constitution Check (post-design): PASS.

## Complexity Tracking

No violations — the one internal change (focus write redirection in `setStateValue`) is the
feature's own mechanism and is fully covered by tests.
