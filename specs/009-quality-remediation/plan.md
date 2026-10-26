# Implementation Plan: Quality Remediation — Remaining Review Findings

**Branch**: `009-quality-remediation` | **Date**: 2026-10-27 | **Spec**: [spec.md](./spec.md)

## Summary

Close every remaining finding from `docs/production-review-2026-10-27.md`: the architectural
weak element↔container link (P1), the Riverpods/hooks semantic contracts, persistence & cache
correctness, flags/analytics truthfulness, DevTools production behavior, testing-helper honesty,
concurrency hardening, macro codegen correctness, and the P3 sweep. Behavior fixes ship
red→green tests; doc-only fixes verified by grep parity.

## Technical Context

**Language/Version**: Swift 6.2, swift-tools-version 6.2 (strict concurrency)
**Primary Dependencies**: unchanged (swift-syntax for macros; TCA for StateConcurrency — untouched)
**Storage**: JSON file for `persistLocal`; schema-version key in UserDefaults — no format breaks
**Testing**: Swift Testing + existing XCTest suites; red→green per behavior fix
**Target Platform**: unchanged (iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+)
**Project Type**: Swift package (15 products)
**Performance Goals**: metrics queries O(providers) cached; single-flight fetch exactly once per key
**Constraints**: public API changes limited to: `element.container` optionality, `.batch` removal,
stub-helper removal, `.always` accessibility removal, `Notifier.state` non-trapping — all changeloged
**Scale/Scope**: ~30 source files, ~60 findings, 11 stories

## Constitution Check

| Principle | Status | Notes |
|---|---|---|
| I. Modular Layering | ✅ | No new cross-module deps; consolidation only (slot accessor, salt helper). |
| II. Hooks Parity | ✅ | Strengthens: one deferred-write policy, loud failures, overlap-safe pending. |
| III. Unidirectional Flow | ✅ | Edge rebuild mirrors the atom graph; cycle fails loudly in Release. |
| IV. Lifecycle Fidelity | ✅ | Core of the feature: weak link, notifier listen, dispose cancellation. |
| V. Clean Public API | ✅ | Removals are V1 stubs/counterfeits with changelog entries; optionality change documented. |
| VI. Concurrency Discipline | ✅ | Weak captures, cancellation paths, trap clamps. |
| VII. Test-First | ✅ | Red→green per behavior fix; leak fixes by deallocation assertions. |
| VIII. Docs Match Reality | ✅ | Grep-parity verification; changelog + migration notes. |

## Key Design Decisions (full rationale recorded here; spec holds the WHAT)

1. **Weak container (US1)**: `ProviderElement.container` becomes `weak var container:
   ProviderContainer?`; async-frame sites use `guard let container` and exit silently
   (no crash, no notify). Sync entry points called BY the container keep `guard let` guards —
   container alive by construction. `element.container` public optionality is a documented,
   changeloged API change with a migration note.
2. **Edge rebuild (US2)**: `dependencies` cleared at recompute start and re-registered during
   the build (atom-graph pattern); reverse `dependents` maintained on insert; `_dependentRefs`
   deduped by object identity.
3. **Notifier listen (US2)**: notifier `onUpdate` routes through a shared publish helper:
   equality-checked external listeners + `container.notifyProviderUpdated`.
4. **Single-flight (US5)**: per-key in-flight task map inside the cache-aside helper; waiters
   await the same task; error propagates to all; map entry removed on completion.
5. **Salted bucketing (US6)**: `hashString("\(experimentId):\(userKey)") % 100`; stability +
   independence tests pin two known ids.
6. **persistLocal (US6)**: flushed batches appended as JSON lines to a file in the platform
   caches directory; 1 MB rotation by truncation. `includeValues` serializes old/new via
   `AnyCodable` when enabled.
7. **Macros (US10)**: parameter-aware peers (required params first, defaults preserved),
   generated names derived from the annotated type name, `MacroError` diagnostics for misuse
   (non-struct atoms, mismatched task signatures, non-defaulted non-optional form fields).
8. **Deterministic RNG (US8)**: existing `DeterministicRandom` wired to the stored seed and
   exposed as `env.random`; doc claims corrected to reference it. Dishonest helpers are deleted
   (V1 policy), documented in changelog.

## Complexity Tracking

No constitution violations requiring justification.
