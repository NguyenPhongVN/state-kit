---
description: "Task list for DX Essentials"
---

# Tasks: DX Essentials (DocC, focusAtom, fileAtom, ErrorBoundary)

**Input**: Design documents from `/specs/006-dx-essentials/`

**Prerequisites**: plan.md ✅ · spec.md ✅ (no clarify questions needed) · research.md ✅ · data-model.md ✅ · contracts ✅ · quickstart.md ✅

---

## Phase 1: focusAtom (US2)

- [x] T001 [P] [US2] Write red tests in Tests/StateKitAtomsTests/SKFocusAtomTests.swift: write through focus updates base with exactly one field changed; base dependents notified; external base change reflects in focus; distinct key paths = distinct atoms
- [x] T002 [US2] Implement SKFocusAtom + `.focus(_:)` + `SKFocusWriting` protocol + write redirection in SKAtomStore.setStateValue, per research D1, in Sources/StateKitAtoms/

## Phase 2: fileAtom (US3)

- [x] T003 [P] [US3] Write red tests in Tests/StateKitPersistenceTests/FileAtomTests.swift (temporary directory): round-trip, missing file → default, corrupt file → default + repair-on-save, delete
- [x] T004 [US3] Implement FileAtomSerializable, FileAtomStorage, fileAtom factory mirroring UserDefaultsAtom patterns, in Sources/StateKitPersistence/FileAtom.swift

## Phase 3: ErrorBoundary (US4)

- [x] T005 [P] [US4] Write red tests in Tests/StateKitUITests/ErrorBoundaryTests.swift: throwing content → fallback + onError; clean content → rendered; throwing fallback propagates
- [x] T006 [US4] Implement ErrorBoundary view per research D3 in Sources/StateKitUI/ErrorBoundary.swift

## Phase 4: DocC (US1)

- [x] T007 [P] [US1] Create .github/workflows/docs.yml (DocC build + Pages publish per research D4, permissions pages:write/id-token:write)
- [x] T008 [P] [US1] Add the local DocC command to docs/engineering/CODING_CONVENTIONS.md §8

## Phase 5: Verification

- [x] T009 Full gates: root build+test, Examples build; quickstart checklist recorded
- [x] T010 CHANGELOG entries under Unreleased (part of V1) for all four additions

---

## Dependencies & Execution Order

T001→T002 · T003→T004 · T005→T006 (pairs, test-first) — the three pairs are independent of each other. T007/T008 independent. T009 after all. T010 last.

## Implementation Strategy

Single-agent order: T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010.
