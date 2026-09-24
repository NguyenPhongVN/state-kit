# Implementation Plan: Fix Critical Defects Found in Code Review

**Branch**: `001-fix-critical-defects` | **Date**: 2026-09-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-fix-critical-defects/spec.md`

## Summary

Fix three critical and two medium defects found in the code review, without changing any public API signature: (1) TTL caches (`TimeToLiveCache`, `SlidingWindowTTLCache`) and `EventTracker` leak because their periodic housekeeping `Task` strongly captures `self` in a non-terminating loop and is cancelled only in `deinit`, which therefore never runs — fixed by weak capture + loop exit; (2) `KeychainBatch.deleteAll(matching:)` ignores both its `items` and `pattern`, deleting the app's entire keychain — fixed to delete only batch items with prefix filtering (clarified: prefix match; nil/empty = all batch items); (3) `KeychainAccessibility` uses invented `kSecAttrAccessible` strings — fixed by mapping each case to the official Security framework constants; plus (4) `djb2Hash` maps non-ASCII to 0 (Vietnamese user IDs collapse onto one bucket) — fixed by hashing UTF-8 bytes in unsigned arithmetic; and (5) README's "47 public macros" is actually 48.

## Technical Context

**Language/Version**: Swift 6.2 (`swift-tools-version: 6.2`), strict-concurrency-ready package

**Primary Dependencies**: `swift-syntax` 603+ (macros only), `swift-composable-architecture` 1.26.2 (only `StateConcurrency` — untouched by this feature); affected modules use only Foundation/Security/Combine

**Storage**: N/A (Keychain accessed via Security framework C API in `StateKitPersistence`)

**Testing**: Swift Testing (`swift test`); per-module test targets already exist for Cache/Analytics/FeatureFlags; **no test target exists for `StateKitPersistence`** — one must be added

**Target Platform**: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ (host test runs on macOS)

**Project Type**: Multi-module Swift library (16 SPM products) + Examples executable

**Performance Goals**: Housekeeping loops keep their configured interval semantics for live instances (cleanup every ½ TTL; auto-flush every `flushInterval`); no busy-looping for any TTL/interval value ≥ 0.001s

**Constraints**: No public API signature changes (FR-10); `KeychainAccessibility` raw-value change and one-time rollout re-bucketing are the only accepted behavior breaks, both changelog-documented; all existing tests must keep passing

**Scale/Scope**: 5 source files modified across 4 modules (`StateKitCache`, `StateKitPersistence`, `StateKitAnalytics`, `StateKitFeatureFlags`) + 1 doc file (`README.md`) + `Package.swift` (new test target) + new tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unratified template (no project-specific principles defined). Default gates apply:

| Gate | Status |
|------|--------|
| Full test suite passes after changes | Planned (SC-07) |
| No unjustified complexity added | PASS — all fixes are minimal local changes |
| No scope creep beyond spec | PASS — EventTracker cap explicitly out of scope per Clarifications |
| Behavior breaks limited to spec-approved set | PASS — see Constraints |

## Project Structure

### Documentation (this feature)

```text
specs/001-fix-critical-defects/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── public-api-contracts.md
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
Sources/
├── StateKitCache/
│   └── TTLCache.swift                     # TimeToLiveCache + SlidingWindowTTLCache housekeeping loops
├── StateKitAnalytics/
│   └── EventTracker.swift                 # auto-flush loop (leak only — no cap, per Clarifications)
├── StateKitPersistence/
│   └── KeychainStateProvider.swift        # KeychainAccessibility mapping + KeychainBatch.deleteAll
├── StateKitFeatureFlags/
│   └── Internal/HashUtils.swift           # djb2Hash over UTF-8 bytes
└── (other modules untouched)

Tests/
├── StateKitCacheTests/CacheTests.swift            # add deinit/loop-termination tests
├── StateKitAnalyticsTests/AnalyticsTests.swift    # add tracker leak tests
├── StateKitFeatureFlagsTests/FeatureFlagsTests.swift  # add distribution/stability/monotonic tests
└── StateKitPersistenceTests/                      # NEW test target (Keychain scoping + accessibility mapping)

README.md                                           # macro count 47 → verified count
Package.swift                                       # add StateKitPersistenceTests target
```

**Structure Decision**: Existing multi-module SPM layout is preserved; changes stay inside the four affected modules. The only structural addition is the missing `StateKitPersistenceTests` target, mirroring the one-test-target-per-module convention already used by the package.

## Complexity Tracking

No constitution violations to justify — table intentionally empty.
