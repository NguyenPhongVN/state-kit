# Implementation Plan: P1 Blocker Fixes (Production Readiness)

**Branch**: `008-p1-blocker-fixes` | **Date**: 2026-10-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-p1-blocker-fixes/spec.md`

## Summary

Fix the 10 P1 production blockers identified in `docs/production-review-2026-10-27.md` across five
modules, each with a red→green regression test (constitution Principle VII): (1) retain cycles between
hook boxes and their own Task/subscription in 7 async/publisher hooks plus `useLoadMore`; (2) off-main
state writes in the 3 Publisher hooks; (3) un-removable atom-store interceptors leaking per
provider→atom edge; (4) `DevToolsObserver`'s update callback never firing (wrong argument label);
(5) self-retaining `onDispose` closures in 3 async provider elements; (6) `ABTest.assignUser` crash on
empty variants; (7) `StateDevScope`'s Release-mode re-render loop; (8) `EventTracker`'s unbounded
retained buffer; (9) Keychain write ordering that can destroy the previous secret / commit state before
success; (10) `DeterministicTimeProvider.advance(by:)` being a no-op.

Approach: local, minimal edits at each finding site; the only public API addition is a token-based
interceptor removal API (additive, old signature deprecated). No new targets, no new dependencies, no
data-format changes.

## Technical Context

**Language/Version**: Swift 6.2, `swift-tools-version: 6.2` (strict concurrency)

**Primary Dependencies**: swift-syntax (macros only), swift-composable-architecture (StateConcurrency only) — untouched by this feature

**Storage**: N/A (no persisted-format changes; Keychain/UserDefaults/FileAtom APIs unchanged in shape)

**Testing**: Swift Testing (`@Suite`/`@Test`/`#expect`) per existing test targets; red→green per fix

**Target Platform**: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ (unchanged)

**Project Type**: Swift package (15 library products + test targets)

**Performance Goals**: interceptor count returns to baseline after provider disposal (no growth across
create/dispose cycles); hook teardown cancels in-flight work within one run-loop tick

**Constraints**: no public API removal; behavior changes are bug fixes observable only where the old
behavior was defective (dead observer, no-op advance, crash) — all changelog-documented

**Scale/Scope**: ~19 source files touched across 5 modules (`StateKit`, `StateKitSupport`,
`StateKitAtoms`, `Riverpods`, `StateKitDevTools`, `StateKitFeatureFlags`, `StateKitAnalytics`,
`StateKitPersistence`, `StateKitTesting` — see task breakdown), 10 new regression suites

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Modular Layering | ✅ Pass | Fixes stay inside existing module boundaries; no new cross-module deps. `receive(on: DispatchQueue.main)` is inlined in `StateKit` because `StateKitCombine` (which has `sinkOnMain`) depends on `StateKit`, not vice versa. |
| II. React-Hooks Parity | ✅ Pass | Strengthens parity: teardown cancels in-flight work (React unmount semantics). |
| III. Unidirectional Flow / Loud Cycles | ✅ Pass | No new side channels; cycles made reclaimable. |
| IV. Provider & Atom Lifecycle Fidelity | ✅ Pass | Directly repairs Principle IV items: async providers cancel in-flight work on disposal; refcount/lifecycle balance. |
| V. Clean Public API | ✅ Pass | One additive API (interceptor token removal) with full docs; old signature deprecated in the same change; changelog entry required (V.5, V.4). |
| VI. Concurrency Discipline | ✅ Pass | Long-lived work captures owner weakly (VI.2); deinit-side cancellation made effective. |
| VII. Test-First Regression Coverage | ✅ Pass | Every fix lands with a test observed to fail before the fix; leak fixes use weak-reference deallocation assertions (VII.4). |
| VIII. Documentation Matches Reality | ✅ Pass | `docs/release/CHANGELOG.md` entry in the same change; DevTools docs claims become true. |

**Post-design re-check**: no violations introduced — the design adds no state duplication, no hidden
channels, no new dependencies. See `data-model.md` for the interceptor token lifecycle notes.

## Project Structure

### Documentation (this feature)

```text
specs/008-p1-blocker-fixes/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (interceptor-removal-api.md)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

Existing SPM layout; no new targets. Files touched:

```text
Sources/
├── StateKit/Use/UseAsync/{useAsync.swift, useAsyncPerform.swift, useAsyncRefresh.swift,
│                         useAsyncSequence.swift}
├── StateKit/Use/usePublisher/{usePublisher.swift, usePublisherPerform.swift, usePublisherRefresh.swift}
├── StateKitSupport/Hooks/Functions/useLoadMore.swift
├── StateKitAtoms/Core/SKAtomStore.swift              # interceptor token + removal
├── Riverpods/Core/EcosystemBridge.swift              # remove interceptor on dispose; weak onDispose
├── Riverpods/Providers/{FutureProvider.swift, StreamProvider.swift, AsyncSequenceProvider.swift}
├── Riverpods/Container/ProviderElement.swift         # (onDispose storage already supports removal pattern)
├── StateKitDevTools/Observers/DevToolsObserver.swift # oldValue: label
├── StateKitDevTools/StateDevTools.swift              # #if DEBUG render counting
├── StateKitFeatureFlags/ABTestFramework.swift        # empty-variants guard
├── StateKitAnalytics/EventTracker.swift              # bounded retention
├── StateKitPersistence/KeychainStateProvider.swift   # store-then-commit; update-then-insert
└── StateConcurrency/SKTask/… (none — advance fix lives in StateKitTesting)

Tests/StateKitTests, Tests/StateKitSupportTests, Tests/StateKitAtomsTests, Tests/RiverpodsTests,
Tests/StateKitDevToolsTests, Tests/StateKitFeatureFlagsTests, Tests/StateKitAnalyticsTests,
Tests/StateKitPersistenceTests, Tests/StateKitCoreTests
```

**Structure Decision**: no structural change — each fix lands at the finding's own site with its
regression test in the corresponding existing test target (constitution VII).

## Complexity Tracking

> No constitution violations to justify.
