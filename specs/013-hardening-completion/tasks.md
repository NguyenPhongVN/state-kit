# Tasks: Hardening Completion

**Feature**: 013-hardening-completion | **Plan**: [plan.md](plan.md)

## Phase 1: Architecture (US1)

- [X] T001 Write `docs/engineering/ARCHITECTURE.md`: 3-engine decision, per-engine scope/non-goals, selection table, dependency map; link from README module section

## Phase 2: Lint (US2)

- [X] T002 Remove 6 stale `swiftlint:disable` commands flagged as superfluous
- [X] T003 Targeted autofix `swiftlint --fix --only switch_case_alignment`; verify suite green
- [X] T004 Fix 28 orphaned doc comments (`///` → `//` where no declaration follows)
- [X] T005 Fix 143 trailing-whitespace sites outside string literals; inline-disable inside macro expected-source strings
- [X] T006 identifier_name 194: inspect causes; rename cheap offenders; document config choice for 1-2 char test locals
- [X] T007 line_length 77: wrap (codegen templates already excluded)
- [X] T008 force_cast/force_unwrapping in Sources: safe-pattern replacements; rulebook documents deliberate test-path usage
- [X] T009 file_length/nesting/for_where/type_name small counts: fix or document; final ledger in tasks log + rulebook

## Phase 3: Sleep sweep (US3)

- [X] T010 Classify 84 sleep sites (assert-path polling / try?-swallow fix / intentional)
- [X] T011 Convert assert-path sites to bounded deadline polling; propagate cancellation; comment intentional sleeps
- [X] T012 Stability proof: 3 consecutive full-suite runs, zero failures

## Phase 4: Sendable audit (US4)

- [X] T013 Enumerate 38 sites; verify isolation story per site; fix unsafe ones with regression tests
- [X] T014 Annotate every accepted site (`// Sendable audit 013: …`) + publish `docs/engineering/SENDABLE_AUDIT.md` table

## Phase 5: Gate & ship

- [X] T015 Full gate (test + Examples + lint) green; changelog + production-review row; commit/push straight to main; memory update

## Dependencies

T001 independent; T002-T009 sequential-ish per category (same files possible); T010→T011→T012; T013→T014; all → T015.

## Parallel Opportunities

T001 ∥ T002-T009; T013 ∥ T002-T009 (different files mostly); T012 after T011 only.
