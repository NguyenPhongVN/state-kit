---
description: "Task list for Coding Conventions Standardization (MAJOR 3.0.0)"
---

# Tasks: Coding Conventions Standardization

**Input**: Design documents from `/specs/004-coding-conventions/`

**Prerequisites**: plan.md ✅ · spec.md ✅ (Clarifications: SwiftLint+SwiftFormat · rename thẳng toàn bộ · zero logic changes · sweep cả 16 module) · research.md ✅ · data-model.md ✅ · contracts/rename-map-3.0.0.md ✅ · quickstart.md ✅

**Tests**: No new tests — the EXISTING suites are the zero-logic-change gate (assertions update only for renamed symbols).

---

## Phase 1: Rulebook & Enforcement (US1, US2)

- [x] T001 Write `.swiftlint.yml` + `.swiftformat.json` per research D3 (naming, force-unwrap warnings consistent with constitution V.3, todo discipline, line length 120; conservative format) in repo root
- [x] T002 Write the rulebook docs/engineering/CODING_CONVENTIONS.md (all FR-01 categories, before/after examples, origins) and link it from README.md and docs/DOCS.md

## Phase 2: The rename (US4 scope, breaking MAJOR)

- [x] T003 Apply the rename map (contracts/rename-map-3.0.0.md): whole-word `SC*` → `SK*` across Sources/, Tests/, Examples/, docs/; move folder `SCTask/` → `SKTask/`; update MIGRATION_GUIDE.md with the table; add the 3.0.0 section to CHANGELOG.md
- [x] T004 Gate: `swift build && swift test` and `cd Examples && swift build` — green with only renamed references changed

## Phase 3: Safe cleanups (US4)

- [x] T005 Consolidate the duplicated `Function.swift` to a single home (StateKitCore) and delete StateKit's copy; remove dead `CanaryRollout.defaultHasher`; re-run build+tests

## Phase 4: Doc/MARK sweep — all 16 modules (US3)

- [x] T006 Sweep StateKitCore + StateKit (MARK skeleton, 100% public symbol docs)
- [x] T007 Sweep StateKitAtoms
- [x] T008 Sweep Riverpods
- [x] T009 Sweep StateConcurrency (post-rename files)
- [x] T010 Sweep StateKitPersistence + StateKitCache
- [x] T011 Sweep StateKitAnalytics + StateKitFeatureFlags
- [x] T012 Sweep StateKitUI + StateKitCombine + StateKitSupport
- [x] T013 Sweep StateKitTesting + StateKitDevTools + StateKitMacros (+ plugin header docs)

## Phase 5: Verification & release docs

- [x] T014 Re-run the doc-coverage scan; record per-module numbers in the rulebook's Rollout & Coverage ledger (SC-03)
- [x] T015 Run `swiftlint` + `swiftformat --lint`; fix top violations or explicitly configure them as recorded warnings; perform the deliberate break-then-fix check (SC-02)
- [x] T016 Final gates: root build+test, Examples build, quickstart checklist recorded (SC-04/SC-05/FR-08)

---

## Dependencies & Execution Order

T001–T002 (rulebook) → T003 (rename) → T004 (gate) → T005 (cleanups) → T006–T013 (sweep; modules independent, parallel-able) → T014 → T015 → T016.

## Implementation Strategy

Rulebook defines the target → rename is mechanical and gated → cleanups small → sweep is the marathon, module by module, core-outward, scan-driven (write docs for the enumerated undocumented symbols).
