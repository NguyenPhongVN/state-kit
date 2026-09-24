# Implementation Plan: Fresher-Friendly Examples ("Start Here" Learning Path)

**Branch**: `003-fresher-friendly-examples` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

## Summary

Add a complete "Start Here" learning path (~20 lessons in 6 progressive chapters, English text)
inside the existing ReferenceExamplesApp, reachable as the first home-screen section. Chapters:
(1) local state with hooks, (2) global state with atoms, (3) Riverpod-style providers,
(4) async & derived state, (5) persistence & caching, (6) architecture + final capstone. Every
lesson is one small interactive screen with plain-language WHY comments and a next-lesson
pointer. Pre-existing advanced examples stay untouched, grouped below the roadmap. Verified by
building the Examples package plus a manual walkthrough checklist.

## Technical Context

**Language/Version**: Swift 6.2, SwiftUI (iOS 17+), `swift-tools-version: 6.0` for the Examples package

**Primary Dependencies**: only StateKit products; **`StateKitPersistence` must be ADDED to the
ReferenceExamplesApp target dependencies** (chapter 5 needs `userDefaultsAtom`;
`StateKitCache` is already linked)

**Storage**: in-memory by default; chapter 5 uses UserDefaults (via `userDefaultsAtom`) and the
library's TTL/LRU caches — deliberate spec exception

**Testing**: no new unit tests (examples are app code — FR-10); acceptance gate = Examples build
green + root full test suite green + manual walkthrough checklist

**Target Platform**: iOS 17+ simulator (ReferenceExamplesApp executable)

**Project Type**: SwiftUI example app inside a multi-module SPM workspace

**Performance Goals**: N/A (demo screens)

**Constraints**: zero changes to pre-existing advanced example files (only the home view gains
the roadmap section — SC-04); progression rule (FR-06): each lesson uses only earlier lessons'
APIs plus its one new concept; all lesson text English (clarified)

**Scale/Scope**: ~20 lessons across 8 new files + 1 home-view edit + 1 manifest edit

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status |
|------|--------|
| Principle I (modular) — examples consume products only, no source copying | PASS |
| Principle V.4 (doc examples compile) — the whole feature IS compiling examples | PASS by construction |
| Principle VIII — docs match reality: roadmap teaches current API incl. post-002 read/watch semantics | Planned (lessons L7/L8 teach the honest semantics) |
| Zero new external dependencies | PASS |
| Full root test suite stays green (nothing in Sources/ changes) | FR-10 |
| originals-preserved convention | FR-07/SC-04 |

## Project Structure

### Documentation (this feature)

```text
specs/003-fresher-friendly-examples/
├── plan.md            # This file
├── research.md        # API grounding + lesson-design decisions
├── data-model.md      # The definitive lesson catalog (6 chapters, 19 lessons + roadmap)
├── quickstart.md      # Build + manual walkthrough checklist
├── contracts/lesson-authoring-contract.md   # Structure every lesson file must follow
└── tasks.md           # Phase 2 output
```

### Source Code (repository root)

```text
Examples/Package.swift                                          # + StateKitPersistence product dep
Examples/CaseStudies/ReferenceExamplesApp/
├── ReferenceExamplesHomeView.swift                             # + "Start Here" section (first)
└── StartHere/
    ├── StartHereCatalog.swift        # Lesson model + ordered catalog + navigation helpers
    ├── StartHereRoadmapView.swift    # Roadmap screen (chapters, lessons, progress-free list)
    ├── Chapter1_LocalState.swift     # L01 Counter · L02 Two-way binding · L03 Todo list
    ├── Chapter2_GlobalState.swift    # L04 Shared atom, two screens · L05 Edit elsewhere · L06 Derived
    ├── Chapter3_Providers.swift      # L07 Provider + read · L08 watch vs read · L09 @Watch wrapper
    ├── Chapter4_AsyncDerived.swift   # L10 TaskAtom loading→success · L11 ThrowingTaskAtom error · L12 Selector/filter
    ├── Chapter5_PersistenceCache.swift # L13 userDefaultsAtom survives relaunch · L14 TTL cache · L15 LRU capacity
    ├── Chapter6_Architecture.swift   # L16 Feature-module state file · L17 Unidirectional flow · L18 Testing your state (read-along)
    └── Capstone_StudyTracker.swift   # L19 Final capstone mini-app
```

**Structure Decision**: one folder, one file per chapter (keeps the roadmap catalog trivial to
scan), separate capstone file. Home view gains exactly one additive section.

## Complexity Tracking

No constitution violations — design complies with all principles.
