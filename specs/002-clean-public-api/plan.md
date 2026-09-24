# Implementation Plan: Clean Public API Overhaul

**Branch**: `002-clean-public-api` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-clean-public-api/spec.md`

## Summary

Bring the public API surface into compliance with constitution Principle V by (1) producing a
complete ranked audit of every public declaration ([audit.md](./audit.md), the US4 deliverable),
and (2) closing all P1 findings plus the agreed P2 documentation work: `ProviderContainer.watch()`
becomes genuinely reactive (clarified decision) while `read()` stays a pure read and the duplicate
`addListener(for:)` is deprecated toward `watch()`; caller-input-reachable force-conversions in
`ProviderContainer.ensureElement` are replaced with loud, precise diagnostics; every remaining
force-conversion carries a written invariant justification; the `preserved(by:)` overload family
and the hooks-vs-`@Hook*` macros paths gain per-variant guidance docs. No signature removals;
deprecations keep existing call sites compiling; changelog documents the `watch` behavior change.

## Technical Context

**Language/Version**: Swift 6.2, `swift-tools-version: 6.2`, strict concurrency

**Primary Dependencies**: none added (constitution: zero new dependencies by default)

**Storage**: N/A

**Testing**: Swift Testing + XCTest targets per module; behavior changes need red→green test pairs

**Target Platform**: iOS 17+/macOS 14+/tvOS 17+/watchOS 10+/visionOS 1+

**Project Type**: Multi-module Swift library (audit unit = exported symbol per product)

**Performance Goals**: none affected — no hot-path changes; `watch()` gains a refcount increment

**Constraints**: no signature removals (FR-06); deprecations must keep call sites compiling;
`Examples/` and docs must end on canonical paths (FR-07); every change changelogged (FR-08)

**Scale/Scope**: ~160 public declarations audited across 7 surveyed modules; code changes
concentrated in `Riverpods` (container/provider layer), docs in `StateKit` core + guides

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status |
|------|--------|
| Principle V (Clean Public API) — the feature's own subject | PASS by construction |
| Principle V.5 — no removals without deprecation or zero-usage proof | Enforced via FR-06 |
| Principle VII — red→green tests for behavior changes (watch) | Planned (quickstart §2) |
| Principle VIII — changelog + examples parity | FR-07/FR-08 |
| Zero new dependencies | PASS |
| Full suite green | FR-09 |

## Project Structure

### Documentation (this feature)

```text
specs/002-clean-public-api/
├── plan.md              # This file
├── research.md          # Phase 0 — key decisions
├── audit.md             # Phase 0/1 — the full ranked API audit (US4 deliverable)
├── data-model.md        # Phase 1 — audit entities
├── quickstart.md        # Phase 1 — validation guide
├── contracts/           # Phase 1 — public API contracts changed here
│   └── access-and-deprecation-contracts.md
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
Sources/Riverpods/
├── Container/ProviderContainer.swift    # watch reactive; ensureElement diagnostics; addListener deprecated
└── SwiftUI/Watch.swift                  # @Watch wrapper migrates to container.watch()

Sources/StateKit/
└── Core/UpdateStrategy.swift            # per-overload use-case docs (keep all 8, per Clarifications)

docs/
├── macros/hooks-vs-macros-guide (in docs/macros/ or docs/core/)  # when to use functions vs @Hook*
└── release/CHANGELOG.md                 # watch behavior change + deprecations

Tests/RiverpodsTests/                     # red→green: watch registers/unregisters; override mismatch diagnostics
Examples/                                 # migrate any deprecated call sites (none expected)
```

**Structure Decision**: changes concentrate in the Riverpods container layer (the only module
with counterfeit/crash findings); everything else is documentation or audit bookkeeping.

## Complexity Tracking

No constitution violations to justify — the design complies with all principles; the `watch`
behavior change is the clarified resolution of a Principle V violation, not a new one.
