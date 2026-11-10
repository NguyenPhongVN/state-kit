# Phase 0 Research: Final Sweep

**Feature**: 012-final-sweep | **Date**: 2026-11-05

## R1. TTL expiry — already correct, pin it

Verified `TTLCache.get()` (TTLCache.swift:45-58): expired entry reports through
`onExpire` ONLY; comment explicitly reserves `onEvict` for capacity/manual removal.
The memory/review note ("fires both") is stale. Deliverable: regression test.

## R2. GeolocationRollout — already resolver-based, pin it

Verified `GeolocationRollout.isEnabled` (Rollout.swift:98-101): uses the host-supplied
`regionResolver`; false without one. The memory note "always false (documented)" is
stale (resolver added in an earlier remediation). Deliverable: regression tests
(allowed/disallowed/nil-resolver). No CoreLocation dependency — resolver pattern is
the better design and stays.

## R3. print() scope

- `CompositionDebugger.logStateChange` + siblings (NotifierComposition.swift:370-405):
  public debug API in the production module → switch backend to the unified system
  logger (subsystem "app.statekit.riverpods"), signature unchanged.
- `DevToolsObserver` (6) + `DebugProviderObserver` (7): gated debug diagnostics →
  system logger, subsystem "app.statekit.devtools", gates checked at emission.
- `usePrint` (StateKitSupport): public printing hook — the documented feature; stays.

## R4. Tracked-but-ignored reality

`git ls-files -ci --exclude-standard` → 3 files, all `Package.resolved`-pattern or
xcuserdata: root `Package.resolved`, workspace + Examples resolved files (intentionally
tracked for deterministic builds), and 2 xcuserdata plists + 1 IDE plist (noise).
Decision: remove the bare `Package.resolved` line from `.gitignore` (tracking resolved
pins is the deliberate convention), untrack the 3 xcuserdata plists. (The review's
breakpoints-file claim was stale — not tracked; its spirit is covered by untracking
these.)

## R5. Stale docs

- `SKStatus.swift:18-21` — MARK headers name `AsyncSequenceStatus`/`PublisherStatus`,
  types that do not exist (only `SKStatus` does). Fix the MARKs/doc.
- `SCGlobalActor.swift:5,12,15,29` — doc examples use the old name `PerformerActor`;
  type is `SKGlobalActor`. Rename in docs.
- `ThrottledAction.swift:13-17` — doc example awaits `sync()` while `callAsFunction`
  is fire-and-forget. Fix example.

## R6. Coverage additions (bounded)

- NEW target `StateKitTestingTests`: DeterministicTestEnvironment (freeze/advance/now,
  deterministic random, async queue drain) + IntegrationTestHelpers core contract.
- `StateKitSupportCoverageTests`: `useCountdown`, `useLastValue`, `useSeen`,
  `useLoadMore` happy-path + teardown pins (4-6 tests).

## R7. CI iOS check + lint verification

- Add job `build-ios`: `xcodebuild build -scheme StateKit -destination 'generic/platform=iOS'`
  (library build only; needs scheme — verify scheme exists, else `swift build` with
  SDK env is not viable for iOS → fall back to `xcodebuild -list` discovery).
- Install SwiftLint locally, run with repo config, fix bounded violations (zero errors
  required by FR-008).

## R8. Out of scope (recorded)

Fixed-sleep sweep (79 sites) — mechanical churn risks flakiness; principle already in
UNIT_TEST_PLAN §8. `@unchecked Sendable` audit — dedicated spec. 3-engine consolidation
— product decision.
