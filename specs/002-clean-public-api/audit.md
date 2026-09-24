# Public API Audit — StateKit (feature 002)

Date: 2026-09-25 · Method: per-module source review of exported declarations against
constitution Principles II–V · Basis: `grep -E '^public …'` enumeration + reading of each
declaration's docs/behavior. Re-run by repeating the scan per module section below.

**Scope note**: "Public declaration" = symbols exported by the package's products. Deep
per-symbol verdicts below cover the modules reviewed line-by-line in the 2026-09-24/25 review
sessions (StateKit, Riverpods, StateKitAtoms, StateKitCache, StateKitPersistence,
StateKitAnalytics, StateKitFeatureFlags, StateKitDevTools-history). StateKitUI,
StateKitCombine, StateKitTesting, StateConcurrency carry group-level verdicts from surface
survey (see F7).

## Findings Index (final — feature 002 shipped)

| ID | Sev | Location | Finding | Disposition |
|----|-----|----------|---------|-------------|
| F1 | P1 | Riverpods/Container/ProviderContainer.swift | `watch()` identical to `read()` — counterfeit reactive name; `addListener(for:)` duplicates the same operation | **FIXED**: `watch()` now registers a reactive listener (refcount, balanced by `removeListener(for:)`); `read()` documented as the pure read; `addListener(for:)` deprecated with a renamed-to-watch annotation; `@Watch`/`useRiverpod` migrated (value reads via `read`, registration via `watch` in `ProviderListener.setup`); tests: `Tests/RiverpodsTests/ProviderAccessTests.swift` (red→green) |
| F2 | P1 | ProviderContainer.ensureElement override paths | Override force-casts reachable from caller-supplied values/elements crashed unexplained | **FIXED**: `ProviderOverrideDiagnostics.mismatchDiagnostic` validates override element/value types; mismatch aborts with a message naming provider, role, and both types; tests: `Tests/RiverpodsTests/OverrideDiagnosticsTests.swift` |
| F3 | P2 | Container/provider element-lookup casts + hook-slot casts | Invariant-backed conversions lacked written justification | **JUSTIFIED**: invariant comments added at ProviderContainer (refresh/read/watch/listen), ProviderElement.watch, StateProvider/NotifierProvider/FutureProvider/AsyncNotifierProvider lookups, and the hook-slot casts (useState/useRef/useMemo/useCallback/useReducer/useOnChange) with the canonical invariant documented on `StateContext.nextIndex` |
| F4 | P2 | StateKit/Core/UpdateStrategy.swift | 8 `preserved(by:)` overloads lacked per-variant selection guidance | **FIXED (docs, clarified)**: family decision table added; nothing deprecated |
| F5 | P2 | docs | No selection guidance between hook functions and `@Hook*` macros | **FIXED (docs)**: `docs/core/HOOKS_VS_MACROS.md` + DOCS.md index entry |
| F6 | P3 | StateKitPersistence/KeychainStateProvider.swift | `clearAll()` doc implied a pattern wipe | **FIXED (docs)**: doc states it deletes exactly this provider's key |
| F7 | P3 | StateKitUI, StateKitCombine, StateKitTesting, StateConcurrency | Group-level survey only — no counterfeits/crash paths surfaced, but no per-symbol deep review yet | **DEFERRED** (P3, next API-hygiene pass) |
| F8 | P3 | StateKitAtoms/Core/SKAtomStore.swift (`SKSubscriberToken.Box`) | Public helper surface possibly broader than needed | **DEFERRED** pending cross-module usage analysis |
| F9 | P3 | StateConcurrency (`SC*` prefixes) | Prefix deviates from the `SK*`/`use*`/unprefixed convention map | **DEFERRED**: renaming is breaking; recorded convention exception, revisit at next MAJOR (removal/renames then also require the MAJOR bump per constitution V.5) |
| F10 | P2 | all modules (ignored-parameter rule) | Sweep for parameters that do not affect behavior | **CLEAN** — the one instance (`deleteAll(matching:)`) was fixed in feature 001 |

## Module Verdicts

### StateKitCore — CLEAN
Runtime primitives (`StateContext`, `StateRuntime`, `StateSignal`, `StateRef`): docs state
MainActor confinement and lifecycle; no caller-input-reachable casts; naming per convention.

### StateKit (hooks) — CLEAN (with F3/F4 bookkeeping)
`useState/useBinding/useRef/useMemo/useCallback/useReducer/useEffect/useLayoutEffect/useOnChange/
useAsync*/usePublisher*/useAsyncSequence`: React-parity contracts documented; first-render
semantics explicit; hook-slot casts covered by F3 (justified comments); `UpdateStrategy` covered
by F4. Naming follows `use*`.

### Riverpods — FINDINGS F1, F2, F3 (all closed this feature)
Container accessors, elements, providers, SwiftUI wrappers otherwise conform: refcounted listener
semantics documented; `ProviderSubscription` double-close safe; overrides documented for testing.

### StateKitAtoms — CLEAN (with F8 note)
Store/box/graph/key/eviction APIs MainActor-documented; eviction semantics honest
(`evictWhenUnused`); family keys parameterized by value; selector contexts distinguish
`watch` (dependency) vs `read` (non-reactive) correctly — the idiom F1 brings the Riverpods
layer up to.

### StateKitCache — CLEAN
LRU/LFU/TTL/sliding caches: MainActor documented; eviction callbacks explicit; `TTLCache.count`
honestly documents inclusion of expired entries.

### StateKitPersistence — CLEAN (with F6 doc fix)
Keychain provider/batch/notifier: error enums precise; scoped-delete contract corrected in
feature 001; accessibility mapping documented (secAttr vs rawValue).

### StateKitAnalytics / StateKitFeatureFlags — CLEAN
EventTracker contracts updated in feature 001 (uncapped history documented as host
responsibility); rollout strategies document their bucketing; `GeolocationRollout` honestly
documents that it never matches without external region resolution.

### StateKitDevTools — CLEAN
History capped at `maxEntries` (documented); recording APIs explicit about memory cost.

### StateKitUI / StateKitCombine / StateKitTesting / StateConcurrency — GROUP-LEVEL (F7/F9)
Surface survey found no counterfeit names or caller-input crash paths; deep per-symbol review
deferred (F7); `SC*` prefix convention exception recorded (F9).

## Tally

Assessed modules: 15 · Findings: 10 (P1×2, P2×3, P3×4, clean-sweep×1) ·
Closed this feature: F1, F2, F3, F4, F5, F6, F10 · Deferred: F7, F8, F9 (all P3).
