---
description: "Task list for Fresher-Friendly Examples (Start Here learning path)"
---

# Tasks: Fresher-Friendly Examples ("Start Here")

**Input**: Design documents from `/specs/003-fresher-friendly-examples/`

**Prerequisites**: plan.md ✅ · spec.md ✅ (Clarifications: English · section in existing app · 6-chapter full curriculum) · research.md ✅ · data-model.md (catalog) ✅ · contracts/lesson-authoring-contract.md ✅ · quickstart.md ✅

**Tests**: No new unit tests (FR-10 — examples are app code). Gates: Examples build green + root suite green + manual walkthrough (quickstart §3).

**Organization**: Setup → roadmap core → chapters (parallel per file) → home wiring → verification.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: parallelizable (different files)
- Stories: US1 roadmap · US2 ch1 · US3 ch2 · US4 ch3 · US7 ch4–6 · US5 capstone · US6 originals

---

## Phase 1: Setup

- [x] T001 Add `StateKitPersistence` product to ReferenceExamplesApp target dependencies in Examples/Package.swift (chapter 5 needs `userDefaultsAtom`)

**Checkpoint**: `cd Examples && swift build` still green after manifest change.

---

## Phase 2: User Story 1 — Roadmap core

- [x] T002 [US1] Create StartHereCatalog.swift (Lesson/Chapter model, ordered catalog for L01–L19 per data-model.md) and StartHereRoadmapView.swift (chapter-grouped roadmap screen, "You will learn" lines, value-based NavigationStack destinations) in Examples/CaseStudies/ReferenceExamplesApp/StartHere/

---

## Phase 3: Chapters (User Stories 2–4, 7) — parallel per file

- [x] T003 [P] [US2] Write Chapter1_LocalState.swift (L01 useState counter · L02 useBinding field · L03 todo list) per contracts/lesson-authoring-contract.md, in Examples/CaseStudies/ReferenceExamplesApp/StartHere/
- [x] T004 [P] [US3] Write Chapter2_GlobalState.swift (L04 shared atom two screens · L05 edit from settings screen · L06 derived atom) in Examples/CaseStudies/ReferenceExamplesApp/StartHere/
- [x] T005 [P] [US4] Write Chapter3_Providers.swift (L07 read-once · L08 watch-live with explicit read-vs-watch contrast · L09 @Watch wrapper) in Examples/CaseStudies/ReferenceExamplesApp/StartHere/
- [x] T006 [P] [US7] Write Chapter4_AsyncDerived.swift (L10 @TaskAtom loading→success · L11 @ThrowingTaskAtom failure+retry · L12 selector-style filtered list) in Examples/CaseStudies/ReferenceExamplesApp/StartHere/
- [x] T007 [P] [US7] Write Chapter5_PersistenceCache.swift (L13 userDefaultsAtom survive-relaunch + reset · L14 TTL cache expiry in seconds · L15 LRU capacity eviction) in Examples/CaseStudies/ReferenceExamplesApp/StartHere/
- [x] T008 [P] [US7] Write Chapter6_Architecture.swift (L16 feature-module state file · L17 unidirectional flow demo · L18 read-along unit test) in Examples/CaseStudies/ReferenceExamplesApp/StartHere/
- [x] T009 [P] [US5] Write Capstone_StudyTracker.swift (L19 mini-app combining L01–L18; every state piece cites its lesson; no new API) in Examples/CaseStudies/ReferenceExamplesApp/StartHere/

---

## Phase 4: User Story 6 — Home wiring (originals preserved)

- [x] T010 [US6] Add the "Start Here" section as the FIRST section of ReferenceExamplesHomeView.swift (links to roadmap; existing groups untouched below) in Examples/CaseStudies/ReferenceExamplesApp/ReferenceExamplesHomeView.swift

**Checkpoint**: `cd Examples && swift build` — fix any compile issues before proceeding (may iterate per file; crib exact macro usage patterns from the existing ReferenceExamples files).

---

## Phase 5: Polish & Verification

- [x] T011 Run quickstart.md §3 walkthrough checklist on an iOS 17+ simulator (or verify by code review per lesson if no simulator is attached) and record results in specs/003-fresher-friendly-examples/quickstart.md
- [x] T012 Verify originals untouched: `git diff --stat -- Examples/CaseStudies/ReferenceExamplesApp/ReferenceExamples` shows only HomeView + new files (SC-04)
- [x] T013 Run root `swift build && swift test` — zero failures (SC-05); add a short changelog line in docs/release/CHANGELOG.md under Unreleased

---

## Dependencies & Execution Order

- T001 → (T002…T009 parallel) → T010 → build checkpoint → T011–T013
- Chapter files are independent of each other; all depend only on the catalog types from T002 (write T002 first).

## Implementation Strategy

Single-agent order: T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → build-fix loop → T011 → T012 → T013.
