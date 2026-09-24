# Implementation Plan: Coding Conventions Standardization (MAJOR 3.0.0)

**Branch**: `004-coding-conventions` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

## Summary

Standardize coding conventions across the whole project so an outside developer can navigate
any file predictably. Deliverables: (1) the canonical rulebook `docs/engineering/CODING_CONVENTIONS.md`
(Swift API Design Guidelines + constitution + ecosystem idioms, each rule with example and
origin); (2) machine enforcement via `.swiftlint.yml` + `.swiftformat.json` (config-only);
(3) the breaking rename of the `SC*` prefix family in `StateConcurrency` to `SK*` (~71 usages,
the audit's F9 deviation), shipped as **MAJOR 3.0.0** with a migration guide; (4) a
MARK-skeleton + doc-comment sweep across all 16 modules targeting 100% of public symbols;
(5) safe cleanups: consolidate the duplicated `Function.swift`, remove dead code.
**Zero logic changes** — behavior identical; tests pass with only renamed references updated.

## Technical Context

**Language/Version**: Swift 6.2; Examples `swift-tools-version: 6.0`

**Primary Dependencies**: none added to the package; SwiftLint/SwiftFormat are contributor
machine tools (config files only, documented in the rulebook)

**Storage**: N/A

**Testing**: existing suites are the behavior gate — assertions stay unchanged except renamed
references; additionally a doc-coverage scan script re-run measures SC-03

**Target Platform**: all supported platforms (no platform-specific changes)

**Project Type**: Multi-module Swift library; refactor touches Sources/, Tests/, Examples/, docs/

**Performance Goals**: N/A (no logic changes)

**Constraints**: zero logic changes (FR-05); MAJOR 3.0.0 + migration guide (FR-09); all gates
green (FR-08); naming exceptions (e.g. `*Utils`, `*Manager` where established) are documented
in the rulebook rather than churned

**Scale/Scope**: 220 source files swept; 6 renamed public types (~71 usages); ~420 public
symbols to document; 120 files to skeletonize

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status |
|------|--------|
| V.5 breaking changes — MAJOR route | PASS via 3.0.0 + migration guide (clarified) |
| V.3 force-conversion policy — encoded into lint config | Planned |
| VIII docs match reality — sweep IS the docs work | PASS by construction |
| Zero new package dependencies (tooling is machine-level) | PASS |
| Gates: build/test/Examples green | FR-08 |

## Project Structure

### Documentation (this feature)

```text
specs/004-coding-conventions/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/rename-map-3.0.0.md     # every public rename, before → after
└── tasks.md
docs/engineering/CODING_CONVENTIONS.md   # THE rulebook (deliverable, linked from README + DOCS.md)
docs/release/CHANGELOG.md                # 3.0.0 entry
docs/release/MIGRATION_GUIDE.md          # rename table
.swiftlint.yml / .swiftformat.json       # enforcement configs
```

### Source Code (repository root)

```text
Sources/StateConcurrency/**     # SC* → SK* renames (SCTaskDuration, SCRetryPolicy, SCTimeoutError,
                                # SCConcurrencyLimiter, SCLocalActor, SCGlobalActor)
Sources/StateKitCore/Internal/Function.swift   # single home (StateKit keeps an internal shim type)
Sources/**                      # MARK skeleton + doc comments, all 16 modules
Tests/**, Examples/**           # updated to renamed symbols only
```

**Structure Decision**: rulebook first, then enforcement configs, then the rename (mechanical,
verifiable by build), then the module-by-module doc/MARK sweep ordered core-outward, then
cleanups and the release docs.

## Complexity Tracking

No constitution violations — the breaking rename rides the MAJOR route the constitution
explicitly allows.
