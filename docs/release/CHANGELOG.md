# StateKit Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## Unreleased (part of V1)

### Hardening completion (specs/013-hardening-completion)

- **Architecture decision published** — the three engines (hooks / atoms / providers)
  are the intended design; `docs/engineering/ARCHITECTURE.md` is the boundary contract
  with selection guidance and the dependency map, linked from the README.
- **Linter noise eliminated** — 965 warnings → 132, each residual category documented
  in the rulebook's lint policy ledger (whitespace inside pinned macro strings, justified
  force casts, by-design size thresholds). 43 switch-case alignments reindented; 28
  orphaned doc comments converted; stale disable commands removed.
- **Deterministic test waits** — 17 fixed-sleep-then-assert sites converted to bounded
  deadline polling; intentional time-modeling sleeps carry justification comments.
  Stability proven by 3 consecutive full-suite runs.
- **`@unchecked Sendable` audit published** — all 40 sites carry a justification comment
  (`// Sendable audit 013: …`) and are tabulated in `docs/engineering/SENDABLE_AUDIT.md`;
  no unsafe site found (FileAtomStorage's 011 lock fix held under re-review).

### Hardening completion (specs/013-hardening-completion) — tests

- Async hook/atom test bodies converted to bounded waits (non-behavioral; the assertions
  are unchanged, only how long they wait).


### Fixed (final sweep — specs/012-final-sweep)

- **Diagnostics go through the unified system log** — `CompositionDebugger`, the DevTools
  observer, and `DebugProviderObserver` no longer `print` to stdout; they emit through
  `os.Logger` (subsystems `app.statekit.riverpods` / `app.statekit.devtools`) behind the
  same gates as before. The public `usePrint` hook is unchanged (it is the feature).
- **Stale docs swept** — `SKStatus` no longer references the non-existent
  `AsyncSequenceStatus`/`PublisherStatus` types; `SCGlobalActor` doc examples use its
  current name instead of the retired `PerformerActor`; the `ThrottledAction` example no
  longer awaits a fire-and-forget call.
- **Repo hygiene** — the bare `Package.resolved` ignore rule is gone (tracking resolved
  pins is the library's deliberate convention); three `xcuserdata` plists are no longer
  tracked; zero tracked-and-ignored files remain.
- **Lint gate proven green** — SwiftLint (now blocking in CI) runs at zero errors:
  `empty_count` autocorrects, long lines wrapped, and the configuration now documents the
  repo's deliberate conventions (`_`-prefixed internal slots/boxes, long tutorial
  chapters, core-store size) instead of failing on them.

### Added (final sweep — specs/012-final-sweep)

- **Pins for already-correct contracts** — TTL expiry reports through `onExpire` only and
  `GeolocationRollout` evaluates through its host-supplied resolver; both were previously
  flagged as defects and are now regression-tested so they cannot silently regress.
- **`StateKitTestingTests` target** — the testing-support module (previously 0 tests for
  1344 LOC) now covers the deterministic time source, seeded randomness, async drain,
  and the integration builder's override/setup contract.
- **Support hook coverage** — `useCountdown` lifecycle (start/pause/cancel/reset) and
  `useSeenSKStatus` latch semantics pinned; support module grows from 8 to 12+ tests.
- **CI builds the iOS destination** — the package declares five platforms; CI now also
  compiles the library for iOS alongside the macOS suite.

### Fixed (P2 hardening — specs/011-p2-hardening-ci)

- **Named providers are logical identities** — creating a provider with an explicit
  `name:` now derives its identity from name + value type: two instances with the same
  name resolve to one element instead of leaking one per recreation (the inline-in-view-body
  pattern). Unnamed providers keep per-instance identity; family providers keep their
  per-argument identity. *Observable change:* two same-named instances now share state by
  design (previously silently independent).
- **`useReducer` no longer loses re-entrant dispatches during the queue drain** — the
  dispatching flag now stays raised through the whole drain; a dispatch made from a queued
  action's reduce previously took the direct path between two drain writes and was
  overwritten.
- **`DebouncedAction` cancellation is atomic** — cancel→create→store now runs in one
  critical section; two concurrent calls previously could each leave a scheduled task alive
  and both run the operation.
- **Update propagation is bounded** — a listener that re-invalidates providers in a loop
  can no longer spin `flushChanges` (and the main thread) forever: propagation is capped at
  100 rounds per flush, reporting in DEBUG when the bound is hit.
- **`FileAtomStorage` is fully thread-safe** — the value cache is now guarded by the same
  lock as the observer list; concurrent save/load previously raced on `cachedValue`.
- **`SwiftDataNotifier` reloads persisted state** — a re-created notifier now loads its
  previously persisted record instead of resetting to the seed default.
- **Stream deliveries no longer crash from background threads** — `StreamProviderElement`
  now delivers via `receive(on: DispatchQueue.main)`: forming the `@MainActor` task for a
  delivery arriving on a background thread tripped the Swift 6.2 runtime isolation check
  (SIGTRAP). Main-queue delivery also makes state writes FIFO in send order.
- **Notifier docs tell the truth about observability** — `state` is `@ObservationIgnored`;
  the docs no longer claim direct `notifier.state` reads are observed by SwiftUI and state
  the supported path (`@Watch` / provider observation) instead.

### Changed (CI & dependencies — specs/011-p2-hardening-ci)

- **CI gates instead of observes** — SwiftLint no longer `continue-on-error` (violations
  fail the build; `--strict` deferred until warning-clean); explicit Xcode selection
  matching the declared Swift 6.2 tools (fails loudly when absent); `.build` caching keyed
  by `Package.resolved`; new experimental (non-blocking) Thread Sanitizer job.
- **Dead dependency removed** — `swift-composable-architecture` was declared on
  `StateConcurrency` but never imported anywhere; consumers no longer download it (and its
  transitive graph) for the concurrency primitives module.

### Fixed (P0/P1 review fixes — specs/010-p0-p1-review-fixes)

- **`overrideWithProvider` no longer crashes** — the element-kind override validated the
  created element against the exact base metatype, but every real element is a
  `ProviderElement` subclass, so the documented "swap real API for mock API in tests"
  path `fatalError`ed on 100% of calls. Validation is now cast-based; genuinely wrong
  override kinds still fail loudly. Pinned by override tests for the standard and
  FutureProvider kinds.
- **Keep-alive links close exactly once** — `KeepAliveLink.close()` is now idempotent as
  its documentation always promised ("Safe to call multiple times. Subsequent calls have
  no effect."); a defensive double-close previously decremented `keepAliveLinksCount`
  twice and could dispose the provider out from under live listeners.
- **Container listeners receive async completions** — `FutureProviderElement` success and
  failure paths and `StreamProviderElement` value/error paths wrote the state box directly,
  bypassing `externalListeners`: a listener registered via `container.listen` never saw
  `.data`/`.error` after async work finished. Both now publish through the same pipeline as
  a recompute (`publishExternalState`), matching the documented listener contract.
- **Cross-container disposal targets the owning container** — `removeListener` resolves the
  element through the parent chain, but `checkAutoDispose` removed it from the *receiving*
  container's dict, leaving a disposed zombie in the owner's registry and notifying the
  wrong observers; `clearDependencyEdges` likewise only searched the local dict, pinning
  parent-owned dependencies' back-edges (auto-dispose providers pinned forever). Both now
  resolve the owner (`element.container`) / the parent chain (`existingElement`).
- **`ProviderScope(overrides:)` falls back to the shared container** — the scope's override
  container never received a `parent`, so every unoverridden provider was recreated from
  scratch inside the scope and shared state silently reset. The scope now passes
  `parent: .shared`.
- **Docs pipeline locates its archive** — `docs.yml` searched `.build` for the
  `StateKit.doccarchive` while `xcodebuild docbuild` (without `-derivedDataPath`) wrote to
  the default DerivedData; the build step now passes `-derivedDataPath .build` and the find
  step fails loudly when no archive exists.
- **Verified false positive (no code change)** — the "resume fires twice when listening
  before the first compute" finding does not manifest: the attach-time fire reaches no
  callbacks (none registered yet) and the first-compute fire is the only observable one,
  so the exactly-once contract holds. Pinned by a regression test asserting exactly one
  `onResume` invocation for a fresh provider.

Behavior-only release: no public API signature changed (see
`specs/010-p0-p1-review-fixes/contracts/public-api.md`).

### Fixed (P1 blocker fixes — specs/008-p1-blocker-fixes)

- **Hook teardown no longer leaks in-flight work** — the boxes behind `useAsync`,
  `useAsyncPerform`, `useAsyncRefresh`, `useAsyncSequence`, `usePublisher`,
  `usePublisherPerform`, `usePublisherRefresh`, and `useLoadMore` no longer retain their own
  task/subscription through result-writing closures. Releasing a hook slot now cancels the
  in-flight work and deallocates the box (previously an infinite sequence kept firing into an
  orphaned signal forever).
- **Publisher-driven hooks write hook state on the main actor only** — `usePublisher`,
  `usePublisherPerform`, and `usePublisherRefresh` now hop deliveries through
  `receive(on: DispatchQueue.main)`. *Observable change:* values emitted by a synchronous
  upstream are delivered one main-queue turn later; callers asserting synchronously must
  await one main-queue turn (see `Publisher.asPhase` test).
- **Atom-store interceptors are removable** — new `SKInterceptorToken`,
  `SKAtomStore.addInterceptorRemovable(_:)` and `removeInterceptor(_:)` (idempotent removal,
  snapshot-iteration notifications). The append-only `addInterceptor(_:)` is deprecated; the
  provider→atom ecosystem bridge now removes its interceptor when the provider element
  disposes, so watch/dispose cycles no longer accumulate permanent closures in
  `SKAtomStore.shared`.
- **`DevToolsObserver` records provider updates again** — its update callback used the wrong
  argument label (`previousValue:`) and was silently shadowed by the protocol extension's
  no-op default; time-travel history recording is live and pinned by a container-level test.
- **Async provider elements release themselves on disposal** — `FutureProviderElement`,
  `StreamProviderElement`, and `AsyncSequenceProviderElement` no longer self-retain through
  `onDispose` registrations or work closures; listener-driven disposal deallocates the
  element and cancels the in-flight operation/pump (the sequence pump additionally cancels
  from `deinit`).
- **`ABTest.assignUser` is total** — an active test with an empty variant list returns `nil`
  instead of trapping on an out-of-range index.
- **`StateDevScope` render counting is DEBUG-only and no longer self-invalidating** — the
  counter moved to a reference type the scope body never reads, eliminating a self-sustaining
  re-render loop that previously ran even in Release builds.
- **`EventTracker` retention is bounded** — the retained `events` history is now opt-in via
  `AnalyticsConfig(historyCap:)` with drop-oldest semantics; by default no unbounded history
  is kept (`eventCount`/`allEvents` report retained events only). *Observable change:* hosts
  relying on the old always-on mirror must pass a `historyCap`.
- **Keychain writes never destroy the previous secret** — `KeychainBatch.store` now uses
  update-then-insert (previously delete-then-add, which destroyed the old value when the
  re-add failed) and `KeychainNotifier.updateValue` commits in-memory state only after a
  successful store.

### Changed (quality remediation — specs/009-quality-remediation)

**Riverpods**
- **`element.container` is now optional (weak)** — breaking change: releasing a
  `ProviderContainer` deallocates every element it holds; elements no longer
  pin their container through a strong back-reference. Graph APIs
  (`watch`/`read`/`listen`) fail loudly without a live container.
- `container.listen`/`ref.listen` and observers now observe Notifier and
  AsyncNotifier state mutations (`notifier.state = x`).
- `removeListener` resolves elements served by a parent container.
- Provider dependency edges rebuild at every recompute (conditional watches
  drop stale edges); dependent refs are deduplicated.
- `FutureProvider.future` throws after a failed refresh instead of returning
  stale `previousData`; recompute cycles `fatalError` in Release (no stack
  overflow); AsyncNotifier cancels its build and resumes pending futures with
  `CancellationError` on dispose.
- `StateController` gained `update(_:)`; the docs now teach whole-value
  updates (nested mutation on the `state` getter copy was always a no-op).
- `@Read` docs corrected: it observes value changes when read in `body`; the
  difference from `@Watch` is listener registration, not reactivity.

**Hooks**
- `useTransition` holds `isPending` until the last overlapping start finishes.
- A `CancellationError` the hook did not cause surfaces as `.failure` instead
  of leaving the phase stuck at `.loading`.
- Render-time hook writes follow one deferred policy (`_safeUpdate`).
- `useEffect`/`useLayoutEffect` slot mismatches fail loudly (previously
  silently skipped the effect and its cleanup).
- `StateContext.states` is read-only outside the runtime; the dead
  `StateContext.context` storage was removed; `StateRuntime.context` outside a
  render now fails loudly.
- `useReducer` queues re-entrant dispatches instead of crashing on exclusivity.

**Persistence / Cache**
- `PersistentAtomStorage.save` throws `PersistenceError.encodingFailed`;
  `observeChanges()` (always returned `[]`) replaced by `changes() ->
  AsyncStream`; `addObserver` returns a removal token; `PersistenceMigration`
  persists a schema version and never re-runs silently.
- `FileAtomStorage`: optional `onCorruption` hook; loads are cached.
- Keychain: decode failures throw `.decodingFailed`; `KeychainNotifier`
  records `lastLoadError`; service namespace (`service:`) isolates same-account
  items; the deprecated `.always` accessibility was REMOVED.
- `SlidingWindowTTLCache.get` checks expiry eagerly and fires
  `onEvict(.expired)`; background sweeps are floored at 1s;
  `CacheAsidePattern` is now a class with single-flight per-key fetch; `clear()`
  fires `onEvict(.cleared)`; the fake `.batch` invalidation case was REMOVED;
  `MemoryPressureHandler.wireToSystemNotifications()` added.

**Feature flags / Analytics**
- Remote flag overrides beat local overrides (documented contract); remote
  snapshots replace stale entries; `clearAllOverrides` clears both stores.
- AB/rollout bucketing is salted per experiment (`salt:` on
  `PercentageRollout`, experiment id in AB assignment).
- Funnel analysis is order-sensitive and `totalCompletions` counts users;
  `UserJourneyTracker` bounds retained sessions and buffers inter-session
  events; `EventTracker` supports result-reporting flush callbacks (failure
  re-queues the batch); `persistLocal` and `includeValues` are implemented.

**DevTools / Testing**
- `DevToolsObserver` publishes changes (views update live); performance
  metrics are cached and forget disposed providers; `storeSnapshots = false`
  records entries with null snapshots; `replay` clamps hostile compute times.
- `DeterministicTestEnvironment` exposes a seeded `random` generator; test
  overrides are actually applied by `build()`; `verifyTransition` verifies
  observed state; the dishonest helpers (`verifyWithinTimeout`, `measureMemory`,
  nil `CommonFixtures`, `weightedRandom`) were REMOVED; assertion helpers
  record `Issue.record` failures instead of aborting the run.

**Concurrency / Macros**
- `Task.throwingTimeout` returns a computed success over a racing timeout;
  `SKConcurrencyLimiter` handles cancelled-before-registration waiters;
  `SKTaskDuration` clamps negative input; `Task.race` throws typed
  `SKRaceError.emptyInput`; `AsyncSequence.publisher` docs state its
  subscribe-immediately, no-backpressure semantics.
- `@Debounce` forwards parameters; hook peer macros preserve defaults and emit
  required-first signatures; `@Atom` rejects non-structs with a diagnostic;
  `@Provider` overloads disambiguate by arity (`fetchProvider1`); `@HRef`
  defers initializer evaluation via `useRefLazy`.
- Documented language limitation: peer macros at global scope can only
  introduce static names — one `@HookForm`/`@HookContext` per module.

### Verified-not-a-defect (P1 blocker fixes)

- **`DeterministicTimeProvider.advance(by:)` works as documented** — the review report's
  "no-op" finding was a false positive: on current SDKs `Date.addTimeInterval(_:)` is a
  mutating call, so time advances correctly. A regression test now pins the behavior.

### Added (polish pass)

- **`useDeferred(_:)`** — deferred value hook: keeps urgent renders responsive while an
  expensive derived part catches up at lower task priority; rapid changes coalesce to the
  latest value (React `useDeferredValue` idiom).
- **`useTransition()`** — `(isPending, start)` pair for marking non-urgent work; `isPending`
  is observable while the awaited work is in flight.
- **`SKAsyncCache`** (StateKitCache) — actor-isolated, race-free key-value cache usable from
  any isolation domain, with optional LRU capacity and TTL expiry.
- **`RemoteFlagSource` protocol + `InMemoryRemoteFlagSource`** (StateKitFeatureFlags) — hosts
  can pull flag overrides from any backend; `FeatureFlagRegistry.applyRemoteOverrides(from:)`
  merges them with remote entries winning over local.
- **`GeolocationRollout` region resolver** — `init(allowedRegions:percentage:regionResolver:)`
  makes the rollout actually usable; default (nil resolver) keeps the documented false.

### Changed (polish pass — behavior fix)

- **TTL cache expiry now fires only `onExpire`** — previously it double-fired both `onEvict`
  and `onExpire`. `onEvict` is now reserved for capacity eviction and manual removal. Hosts
  relying on the double fire should migrate to `onExpire`.

### Added (DX essentials)

- **`SKFocusAtom` + `.focus(_:)`** — a read/write lens over one field of a state atom
  (Jotai `focusAtom` idiom): reads derive reactively from the base, writes update the base
  with only the focused field changed and notify its dependents.
- **`fileAtom` / `FileAtomStorage`** — JSON-file-backed atom persistence for payloads beyond
  UserDefaults limits; falls back to the documented default on missing/corrupt files.
- **`ErrorBoundary` view** (StateKitUI) — wraps a throwing content closure, renders a
  fallback with the caught error, optional `onError` hook.
- **DocC publishing** — `docs.yml` workflow builds and publishes API documentation to GitHub
  Pages on push to `main` (no package dependency); local command documented in the rulebook.

### Added (health bundle)

- **GitHub Actions CI** (`.github/workflows/ci.yml`): build + full test suite + Examples build
  on every push/PR; SwiftLint runs non-blocking until the codebase is fully clean.
- **`ProviderContainer.removeObserver(_:)`** — detaches a lifecycle observer by identity;
  double-removal is a safe no-op (pairs `addObserver`).
- **`InMemoryStateHistory.replay(using:)`** with `ReplayReport` — real action replay through a
  host-supplied handler; reports executed/skipped actions and surfaces handler errors.
- LRU cache stress test (10,000 mixed operations).

### Changed (health bundle)

- **`InMemoryStateHistory.replay()` replaced** with the handler-based `replay(using:)` — the
  old no-argument version only slept through recorded timings and executed nothing.
- **`LeastRecentlyUsedCache` internals rewritten to O(1)** (dictionary + doubly linked list);
  behavior identical, existing tests unchanged.
- Hardened the timing-sensitive atom task tests with bounded-polling assertions.

### 💥 Renames (applied within V1 development — zero logic changes)

- **StateConcurrency renamed to the `SK*` convention** (resolves audit F9):

  | Before | After |
  |--------|-------|
  | `SCTaskDuration` | `SKTaskDuration` |
  | `SCTimeoutError` | `SKTimeoutError` |
  | `SCGlobalActor` | `SKGlobalActor` |
  | `SCLocalActor` | `SKLocalActor` |
  | `SCRetryPolicy` | `SKRetryPolicy` |
  | `SCConcurrencyLimiter` | `SKConcurrencyLimiter` |

  See `docs/release/MIGRATION_GUIDE.md` for the one-command migration.

### Added

- **Coding conventions rulebook** — `docs/engineering/CODING_CONVENTIONS.md`: file layout,
  MARK skeleton, naming and prefixes, documentation requirements, concurrency annotations,
  force-conversion policy, testing conventions, and tool setup.
- **Machine enforcement configs**: `.swiftlint.yml`, `.swiftformat` (contributor-side tools;
  no dependency added to the package).

### Changed

- **Documentation sweep**: every public symbol in all 16 modules now carries a doc comment
  (0 undocumented of 1,186); MARK skeletons added across multi-section files.
- Removed dead code: `CanaryRollout.defaultHasher`; consolidated the triplicated
  `Function.swift` helpers into single homes (`guardFunction` → StateKitCore, `sourceId` →
  StateKitSupport, ~330 lines of dead duplicates deleted).

### Added (examples)

- **"Start Here" learning path** in the Examples app: 19 tiny lessons across 6 progressive
  chapters (local state → atoms → providers → async & derived → persistence & cache →
  architecture) ending in a capstone mini-app. Each lesson is one concept, one screen, with
  plain-language why-explanations and a next-lesson pointer. The existing advanced examples are
  unchanged and remain available below the path.

### ⚠️ Behavior Changes

- **`ProviderContainer.watch(_:)` is now genuinely reactive** (Riverpod idiom: read = pure,
  watch = reactive). It registers a listener — keeping auto-dispose providers alive — and
  returns the current value; balance every `watch` with `removeListener(for:)`. Previously
  `watch` was an exact synonym of `read` and registered nothing, so callers using it as a
  throwaway read MUST now release the listener (SwiftUI wrappers `@Watch` and `useRiverpod`
  handle this internally and are unaffected).

### Deprecated

- **`ProviderContainer.addListener(for:)`** — exact duplicate of `watch(_:)`; use `watch(_:)`
  balanced with `removeListener(for:)`. No behavior difference; removed at the next MAJOR.

### Fixed

- **Override type mismatches now fail with a precise diagnostic** instead of an unexplained
  cast crash: `ProviderContainer.ensureElement` validates override element/value types and
  names the provider, role, and both types in the failure message.
- Docs: `KeychainStateProvider.clearAll()` documented as deleting exactly its own key (never a
  pattern wipe); the full `preserved(by:)` overload family gained a selection table (nothing
  deprecated, per design decision); new guide `docs/core/HOOKS_VS_MACROS.md` explains when to
  use function hooks vs `@Hook*` macros.
- Public API audit shipped with this feature (`specs/002-clean-public-api/audit.md`): all P1
  findings closed; remaining force-conversions carry written invariant justifications;
  deferred P3 items recorded (per-symbol review of UI/Combine/Testing/Concurrency modules,
  `SKSubscriberToken.Box` surface, `SC*` prefix convention exception).

### Fixed (feature 001 — keychain/cache/rollout)

- **Memory leak in `TimeToLiveCache`, `SlidingWindowTTLCache`, `EventTracker`**: the periodic
  housekeeping/auto-flush task captured `self` strongly in a non-terminating loop and was only
  cancelled in `deinit`, so instances were never deallocated and kept waking the CPU forever.
  The loop now captures `self` weakly and exits as soon as the instance is released. Live
  instances behave unchanged.
- **`KeychainBatch.deleteAll(matching:)` ignored its `pattern` parameter** (and the batch's
  items) and deleted *every* generic-password keychain item the app could access — including
  auth tokens. Deletion is now scoped to the items the batch stored; `pattern` is a prefix
  match, `nil`/empty deletes all batch items. Foreign keychain items are unreachable by
  construction.
- **`KeychainAccessibility` applied invalid `kSecAttrAccessible` values**
  (`"com.apple.keychain.*"` strings are not valid Keychain attributes), making store fail on
  device or set an unintended protection level. Each case now applies the official
  `kSecAttrAccessible*` constant via a new internal `secAttr` mapping.
- **`djb2Hash` mapped every non-ASCII character to 0**, collapsing distinct international
  user IDs (Vietnamese, CJK, Cyrillic, …) onto the same rollout/A-B bucket. The hash now runs
  over the ID's UTF-8 bytes in unsigned 32-bit arithmetic (also removing the `abs(Int.min)`
  trap and negative-modulo hazard).
- **README** stated 47 public macros; the actual count is 48.

### ⚠️ Behavior Changes (feature 001 — accepted, documented)

- `KeychainAccessibility` raw values changed from invented `"com.apple.keychain.*"` strings to
  the platform's canonical codes (`"ak"`, `"aku"`, `"ck"`, `"cku"`, `"dk"`). Hosts persisting
  raw values must remap. Items written by previous builds either failed to store or used an
  unintended protection level, so no migration is possible or needed.
- Rollout/A-B bucket assignments may change for some users due to the `djb2Hash` fix — a
  one-time re-bucketing.

---

## [1.0.0] — V1 (Current Release)

### ✨ New Features

#### Riverpods Enhancements
- **Ecosystem Bridge**: Direct interoperability between Atoms and Riverpods
  - New `RiverpodAtom<P>` to wrap providers as atoms
  - New `watch<A: SKAtom>()` method in ProviderRef
  - Use atoms and providers together seamlessly
  
- **AsyncNotifierProvider Improvements**
  - New `.notifier` property to access instance directly
  - Matches `NotifierProvider` API pattern
  - `AsyncNotifierInstanceProvider<N, T>` for instance access
  - Cleaner API for complex async state management

- **Enhanced Lifecycle Observation**
  - `ProviderObserver` protocol for tracking provider events
  - `didAddProvider`, `didUpdateProvider`, `didDisposeProvider` callbacks
  - Built-in logging/analytics/debugging support

- **Selector Providers**
  - New `.select()` method with KeyPath support
  - Only notify dependents when selected value changes
  - Prevents unnecessary rebuilds
  - Example: `@Watch(userProvider.select(\.name))`

#### Testing Improvements
- **Better Provider Testing**
  - Enhanced mock/override support
  - Easier test container setup
  - StateTest harness improvements

- **AsyncValue Enhancements**
  - New `when()` pattern matching method
  - State transitions tracking
  - Better error handling patterns

#### Developer Experience
- **Comprehensive Documentation**
  - Complete API documentation for all modules
  - Professional Riverpods documentation
  - Architecture guide (ARCHITECTURE_GUIDE.md)
  - Examples and use-case docs

- **Swift Macros**
  - `@Atom` macro for atom definition
  - `@Provider` macro for provider definition
  - Significant boilerplate reduction

- **API Stability Documentation**
  - Clear stability levels (Stable/Beta/Experimental)
  - Commitment to API compatibility
  - Deprecation policy documented

#### Code Quality
- **Strict Concurrency Support**
  - Full Swift 6.2 compliance
  - No compiler warnings
  - Thread-safe by default

- **Extended Platform Support**
  - iOS 17+ (primary)
  - macOS 14+ (desktop support)
  - tvOS 17+ (Apple TV support)
  - watchOS 10+ (wearable support)
  - visionOS 1+ (spatial computing)

### 🔧 Bug Fixes
- Fixed type-checking complexity in complex view hierarchies
- Fixed closure self-capture semantics in examples
- Fixed AsyncValue error case destructuring
- Improved compiler performance with ViewBuilder refactoring

### 📚 Documentation
- Riverpods comprehensive documentation completed
- API stability guide (API_STABILITY.md)
- Migration guide for V1 (MIGRATION_GUIDE.md)
- Development roadmap (DEVELOPMENT_ROADMAP.md)
- Example app fixes and improvements

### ✅ What's Stable
- All core Riverpods features
- Complete hooks system
- Atoms system
- StateConcurrency utilities
- Testing framework

### ⚠️ What's Beta
- Property wrappers (@HState, @HMemo, etc.)
- Combine integration
- DevTools debug overlay

See [API_STABILITY.md](API_STABILITY.md) for complete API stability information.

---

## [1.x] - Previous Releases

### v1.5.0
- Initial Riverpod features
- Hooks system foundation
- Atoms system

### v1.0.0
- Initial release
- Core state management
- SwiftUI integration

---

## 📋 Future Planned Features

### Post-V1 Phase 1 (Planned)
- **Architecture Guidelines**: Professional composition patterns
- **Enhanced Composability**: Better module composition
- **Modularity Framework**: Clear boundary definitions

### Post-V1 Phase 2 (Planned)
- **Time-Travel Debugging**: Redux DevTools integration
- **Performance Profiling**: Update frequency tracking
- **Enhanced DevTools**: Live debugging overlay

### Post-V1 Phase 3 (Planned)
- **Advanced Testing**: 100% deterministic testing
- **Test Fixtures**: Pre-built test data generators
- **Integration Tests**: Multi-module testing

### Post-V1 Phase 4 (Planned)
- **E-Commerce Example App**: Production-grade example
- **Architecture Showcase**: Real-world patterns
- **Best Practices Guide**: Expert recommendations

### Post-V1 Phase 5+ (Planned)
- **State Persistence**: Local storage integration
- **SwiftData Bridge**: Database-driven atoms
- **CloudKit Sync**: iCloud synchronization
- **VisionOS Patterns**: Spatial computing support

---

## 🎯 Versioning Policy

StateKit follows [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH**
- **Breaking changes**: MAJOR version bump
- **New features (backward compatible)**: MINOR version bump  
- **Bug fixes**: PATCH version bump

### Stability Commitment
- Stable APIs maintained for **minimum 2 major versions**
- Beta APIs typically reach stability within **2 minor versions**
- Deprecation notice given **3+ versions before removal**

---

## 🙏 Contributors

This release represents the culmination of:
- 187 Swift files of carefully crafted code
- 34 comprehensive test files
- Complete Riverpod feature parity
- Professional-grade documentation

Contributors: Mike Packard and Claude AI assistant team

---

## 📞 Support

- **Documentation**: [GUIDE.md](GUIDE.md), [API_STABILITY.md](API_STABILITY.md)
- **Migration**: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- **Issues**: GitHub Issues with appropriate labels
- **Roadmap**: [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md)

---

**Current Version**: 1.0.0  
**Release Date**: May 17, 2026  
**Next Review**: next release planning cycle
