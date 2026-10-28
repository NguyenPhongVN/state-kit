# StateKit Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## Unreleased (part of V1)

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
