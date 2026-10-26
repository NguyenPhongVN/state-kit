# Feature Specification: Quality Remediation — Remaining Review Findings

**Feature Branch**: `009-quality-remediation`

**Created**: 2026-10-27

**Status**: Draft

**Input**: User description: "Fix ALL remaining production-review findings (P1 architectural container cycle, all P2, quick P3s) from docs/production-review-2026-10-27.md. Behavior fixes ship regression tests; doc-only fixes verified by grep parity."

Per-finding evidence and file:line references live in `docs/production-review-2026-10-27.md` (the
authoritative inventory). This spec groups them into independently testable stories and states the
decision for each where more than one remedy exists.

## Clarifications

### Session 2026-10-27 (unattended — defaults chosen per workspace rules)

- Q: Container back-reference remedy? → A: Weak container on `ProviderElement`; nil-container
  semantics = element is unreachable and its async work becomes a no-op (no crash, no notify).
  Dispose no longer needs the container.
- Q: Dependency-edge rebuild (stale `watch` edges)? → A: In scope — clear `dependencies`/
  reverse edges at the start of each recompute and re-register during the build, mirroring the
  atom graph.
- Q: `IntegrationTestHelpers` stubs? → A: Implement the trivially implementable (override storage,
  verifyTransition semantics); delete the dishonest ones (verifyWithinTimeout, measureMemory,
  FeatureTestHarness.observe, dead fixtures) from public API via deprecation → removal in the
  same release (V1 pre-1.0 policy allows it; changelog documents).
- Q: `AnalyticsConfig.persistLocal` / `includeValues`? → A: Implement `includeValues` (serialize
  values into the event); deprecate-and-ignore `persistLocal` is NOT acceptable — implement
  local persistence as a JSON file store behind the existing config flag.
- Q: Cache `.batch` invalidation stub? → A: Remove the case (enum is library-internal contract,
  V1) — silently acting as `.immediate` is a counterfeit API (constitution V.6).
- Q: `Notifier.state` force-unwrap before attachment? → A: Return the built initial value
  instead of trapping (notifier materializes lazily on first read).
- Q: Hook slot mismatch (`useEffect` silent no-op)? → A: Fail loudly like every other hook
  (shared `slot<T>()` accessor with the same fatalError contract).
- Q: `StateContext.states` public mutable? → A: `public private(set)`; runtime-provided mutation
  only; `StateRuntime.context` outside a render becomes a fatalError like every hook.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provider elements do not pin their container (Priority: P1)

Releasing a provider container deallocates every element it holds, even elements that were
abandoned mid-work or never explicitly disposed; conversely an element whose container is gone
stops notifying (no crash). Today the element holds its container strongly and the container
holds its elements, so any abandonment path leaks both.

**Why this priority**: architectural memory leak affecting every container teardown; blocks the
library's lifecycle trust.

**Independent Test**: create a container with Future/State/AsyncSequence providers (mix of
listened and never-listened elements), release the container, assert container and all elements
deallocate (weak refs nil after run-loop drain).

**Acceptance Scenarios**:

1. **Given** a container with listened and unlistened provider elements, **When** the container
   is released, **Then** the container and every element deallocate.
2. **Given** an element with in-flight async work, **When** its container is released before
   the work finishes, **Then** the work observes the nil container and exits without crashing
   or notifying.
3. **Given** normal operation (container alive), **When** providers recompute/dispose, **Then**
   existing behaviors are unchanged (full regression suite stays green).

---

### User Story 2 - Riverpods semantics match their documented contracts (Priority: P2)

Six semantic gaps close: (a) `container.listen`/`ref.listen` observe Notifier/AsyncNotifier
state mutations and `notifyProviderUpdated` fires for them; (b) `removeListener` resolves
parent-served elements; (c) conditional `watch` edges rebuild each recompute and
`_dependentRefs` dedupes; (d) `FutureProvider.future` throws on a failed refresh instead of
returning stale data; (e) `AsyncNotifier` cancels its task and resumes pending futures on
dispose; (f) the recompute cycle fallback cannot recurse infinitely in Release.

**Independent Test**: per-contract regression suites (notifier listen, parent removeListener,
conditional watch eviction, stale-future throw, notifier dispose cancellation, cycle error).

**Acceptance Scenarios**:

1. **Given** `container.listen(notifierProvider)`, **When** `notifier.state = x`, **Then** the
   listener fires with old/new values and observers see the update.
2. **Given** a `@Watch` on a parent-served provider, **When** the view's listener cleans up,
   **Then** the parent element's count decrements (no leak).
3. **Given** a provider that switches `watch(A)`→`watch(B)`, **When** A changes, **Then** the
   provider does not recompute; **When** B changes, **Then** it does; **When** B's element is
   autoDispose with no other listeners, **Then** it can dispose.
4. **Given** a FutureProvider that succeeded then a refresh failed, **When** `future` is
   awaited, **Then** it throws the refresh error.
5. **Given** an AsyncNotifier with an in-flight build and a suspended `future`, **When** the
   element disposes, **Then** the build task is cancelled and the future resumes throwing
   `CancellationError`.
6. **Given** a genuine A↔B watch cycle on first access, **Then** the library fails with a
   diagnostic in both Debug and Release (no stack overflow).

---

### User Story 3 - Hook semantics are consistent and honest (Priority: P2)

(a) `useTransition` keeps `isPending` until the LAST overlapping start finishes; (b) a
`CancellationError` that the hook did not cause surfaces as `.failure` (or reverts to `.idle`)
instead of leaving `.loading` forever; (c) render-time state writes follow ONE policy
(deferred) across all async/publisher hooks — including the synchronous-delivery case; (d)
effect slots mismatch fails loudly like every other hook; (e) `StateContext.states` is no
longer publicly mutable and `StateRuntime.context` outside a render fails loudly; (f)
`useReducer`'s dispatch tolerates one re-entrant level deterministically.

**Independent Test**: extended StateTest suites per behavior (overlap pending, external
cancellation, Just() delivery, slot mismatch, reducer nesting).

**Acceptance Scenarios**:

1. **Given** two overlapping `start(work)` calls, **When** the first finishes, **Then**
   `isPending` stays true until the second finishes.
2. **Given** an operation cancelled by an external timeout (not the hook), **When** it throws
   `CancellationError`, **Then** the phase does not remain `.loading`.
3. **Given** `usePublisher(Just(1))`, **When** the first render runs, **Then** the returned
   phase already reflects the delivered value or a deferred write lands before the next
   observed read — no mid-render mutation crash and no lost value.
4. **Given** a corrupted hook slot for `useEffect`, **Then** the failure is loud (fatal with
   the same message shape as `useState`).
5. **Given** a reducer action dispatched from inside a reducer, **Then** state updates
   deterministically instead of hitting an exclusivity crash.

---

### User Story 4 - Persistence is safe by default and honest (Priority: P2)

(a) `KeychainNotifier.build` surfaces retrieval failures as an error state instead of silently
substituting the initial value; keychain error mapping throws `decodingFailed` where decoding
fails; (b) `PersistentAtomStorage.save` throws on encode failure and notifies observers only
on success; `observeChanges()` is replaced by an honest API; (c) `FileAtomStorage.load` reports
corruption through an optional hook while keeping the forgiving default, and `fileAtom` caches
its loaded value (no per-read disk I/O); (d) `PersistenceMigration` persists a schema version;
(e) keychain items gain an optional service namespace to avoid cross-provider collisions and
`.always` is removed from the public surface.

**Independent Test**: error-injection suites per behavior (already-established seam patterns).

**Acceptance Scenarios**:

1. **Given** a locked-keychain retrieval failure, **When** `build` runs, **Then** the failure
   is observable (error state), not a silent initial fallback.
2. **Given** an unencodable value, **When** `save` runs, **Then** it throws and observers are
   not notified of a write that did not happen.
3. **Given** a corrupt file, **When** a corruption hook is installed, **Then** it fires with
   the underlying error before the default fallback applies.
4. **Given** two providers with the same account key and different service namespaces,
   **Then** their items do not collide.

---

### User Story 5 - Cache primitives are correct under concurrency and pressure (Priority: P2)

(a) `SlidingWindowTTLCache.get` checks expiry eagerly and does not extend expired entries;
(b) the background sweep interval has a floor independent of tiny TTLs; (c) cache-aside
helpers provide single-flight (per-key in-flight dedup) so N concurrent misses fetch once;
(d) `clear()` fires `onEvict(.cleared)` for every evicted entry; (e) `SKAsyncCache.sweepExpired`
collects keys before mutating; (f) the fake `.batch` invalidation case is removed and
`MemoryPressureHandler` offers a system-notification wiring helper.

**Independent Test**: cache suites (expired-while-suspended, cap-floor, concurrent single-flight,
clear eviction callbacks).

**Acceptance Scenarios**:

1. **Given** an expired entry, **When** `get` runs (even if the background sweep has not),
   **Then** it returns nil and does not refresh `lastAccessedAt`.
2. **Given** a `ttl: 0.02` cache, **Then** the sweep interval is ≥ 1 second (no hot loop).
3. **Given** 50 concurrent `cacheAside.get` calls for one cold key, **Then** the fetcher runs
   exactly once.
4. **Given** `clear()` on a cache with `onEvict` installed, **Then** every entry reports
   `.cleared`.

---

### User Story 6 - Feature flags and analytics tell the truth (Priority: P2)

(a) Remote overrides win over local overrides (documented contract), remote snapshots replace
stale bool entries, and `clearAllOverrides` clears both stores; (b) rollout/AB bucketing salts
with the experiment id (independent assignment across experiments); (c) `FunnelAnalyzer`
tracks ordered step progression and `totalCompletions` counts users; (d) `UserJourneyTracker`
bounds its history and stops silently dropping inter-session events (buffers or flags them);
(e) `EventTracker.flush` re-queues events when the flush callback reports failure; (f)
`includeValues` serializes values into the event; `persistLocal` persists flushed batches to a
local file.

**Independent Test**: flags/analytics suites (precedence, independence, funnel order, bounds,
flush retry).

**Acceptance Scenarios**:

1. **Given** a remote override and a local override for one flag, **Then** remote wins as
   documented; **Given** a flag removed from the remote snapshot, **Then** its stale remote
   value is replaced on apply.
2. **Given** the same user across two experiments with different ids, **Then** assignments are
   statistically independent (different salt → different bucket, pinned by a determinism test
   on two known ids).
3. **Given** events `[purchase, view]`, **Then** the user does NOT count as a full-funnel
   completion; **Given** `[view, cart, purchase]`, **Then** `totalCompletions` counts that user.
4. **Given** a flush callback that returns failure, **When** flush runs, **Then** the batch is
   re-queued and retried on the next flush.

---

### User Story 7 - DevTools work in production conditions (Priority: P2)

(a) DevTools UI observes data changes (history/metrics updates reach the views); (b)
performance metrics cache aggregates per provider, drop metrics for disposed providers, and
history respects `storeSnapshots == false` by recording entries with null snapshots; (c)
`replay` clamps/validates computeTime (negative/NaN from imported JSON cannot trap).

**Independent Test**: observer-recording + replay suites extended for the new semantics.

**Acceptance Scenarios**:

1. **Given** `storeSnapshots = false`, **When** providers update, **Then** history entries are
   still recorded (with null before/after).
2. **Given** an imported history with `computeTime: -1` or NaN, **When** replay runs, **Then**
   no trap occurs and the entry replays immediately.
3. **Given** a disposed provider, **When** metrics are queried, **Then** its records are gone.

---

### User Story 8 - Testing helpers enforce what they claim (Priority: P2)

(a) `DeterministicTestEnvironment` wires its seed into an injectable RNG exposed as
`env.random`, and its doc stops claiming `Int.random` is seeded; (b) `override(_:with:)` stores
and `build()` applies overrides; `verifyTransition` verifies via the provided action's observed
state; (c) dishonest helpers (`verifyWithinTimeout` always-nil, `measureMemory` always-0,
`FeatureTestHarness.observe` empty, `FixtureBuilder` unconsumed, `CommonFixtures` nil
stubs, `FixtureFactory.weightedRandom` zero-weight trap) are removed or implemented; (d)
test-facing assertion helpers record test failures instead of `fatalError`.

**Independent Test**: StateKitTesting suites (seeded RNG reproducibility, override application,
transition verification).

**Acceptance Scenarios**:

1. **Given** two environments seeded alike, **When** `env.random.next(in:)` draws, **Then**
   both produce identical sequences.
2. **Given** `override(provider, with: value)`, **When** `build()` resolves the provider,
   **Then** the override value is returned.
3. **Given** a fixture suite, **Then** no public symbol returns a silent stub.

---

### User Story 9 - Concurrency utilities survive adversarial inputs (Priority: P2)

(a) `Task.throwingTimeout` returns an already-computed success instead of racing the timeout,
and documents that non-cancellation-responsive operations are not bounded; (b)
`SKConcurrencyLimiter` handles cancellation-before-registration without deadlocking waiters;
(c) `SKTaskDuration(TimeInterval)` clamps negatives instead of trapping and retry policy
validates its multiplier; (d) `AsyncSequence.publisher` documents subscribe-immediately
semantics honestly (no backpressure claim) and cancels its pump on publisher deinit; (e)
`MainActor.runImmediately` documents the deadlock hazard.

**Independent Test**: StateConcurrency suites (timeout-with-success, cancelled-waiter, negative
duration, pump cancellation).

**Acceptance Scenarios**:

1. **Given** an operation that completes as the timeout fires, **Then** `throwingTimeout`
   returns the result (no spurious timeout throw).
2. **Given** a waiter cancelled before its continuation registers, **When** the limiter
   releases, **Then** the waiter's `execute` returns (no hang).
3. **Given** `SKTaskDuration(-0.5)` and a negative retry multiplier, **Then** no trap (clamped
   / validated).

---

### User Story 10 - Macros generate compilable code for real-world inputs (Priority: P2)

(a) `@Debounce` forwards parameters (and stores the last call's arguments); (b) `@HookForm`
names the generated hook struct after the annotated type, propagates access level, and
diagnoses non-defaulted non-optional fields; (c) `@HookContext` generates a per-type unique
global name; (d) `@HookState`/`@HookEffect`/`@HookLayoutEffect`/`@HookAsync` emit required
params first with defaults preserved and valid `preserved(by:)`/`cleanup` handling; (e) `@Atom`
applied to a non-struct throws `onlyApplicableToStructs`; `@TaskAtom`/`@ThrowingTaskAtom`
validate the task signature against the chosen protocol; (f) `@Provider` generated names
disambiguate overloads and keep parameter defaults; (g) `@HRef` defers its initializer
evaluation per its doc.

**Independent Test**: macro expansion assertions upgraded to compilability checks where
supported (two uses per module, parameterized functions).

**Acceptance Scenarios**:

1. **Given** `@Debounce func search(query: String) async {}`, **Then** the generated peer
   compiles and forwards `query`.
2. **Given** two `@HookForm` structs in one module, **Then** no duplicate symbol.
3. **Given** `@HookState` fields with a defaulted param before a required one, **Then** the
   generated function compiles.
4. **Given** `@Atom` on a class, **Then** a clear macro diagnostic names the restriction.

---

### User Story 11 - Sweep: dead code, dishonest docs, small traps (Priority: P3)

(a) Delete unreferenced `AnyEquatable`, dead `SKStatus` enums, `CacheMetadata` orphan wiring,
fixture vaporware leftovers from US8, duplicated `topologicallySortedDescendants`, duplicated
doc blocks; (b) correct dishonest docs: `useEnvironment` scanning claim, `SKAtomEffect` "not
yet wired", `@Read` reactivity table, `syncToState`, `SwiftDataIntegration` claims (or
implement its persistence honestly — see FR), `withLatestFrom` re-emit note, `HCount` naming,
`SKTask` doc `context` reference, `StateKitCache` thread-safety claim, `RiverpodAtom` bridge
claims (until US2 fixes the sync, or the sync is fixed here); (c) small traps: `djb2Hash`
32-bit-safe conversion, chi-square zero-denominator guard, `useNow` non-positive interval
guard, `ObservableTask` deinit cancel + state cleanup, `ReplayReport` Sendable-safe failure
storage, `JSONValue.from` degradation surfaced via the corruption hook, SwiftData
`updateAndPersist` either persists the state or is removed, `EventLogger` O(n²) string build,
`toDictionary` reserved-key collision guard.

**Independent Test**: grep parity for docs; unit tests for the behavioral bits (djb2 on 32-bit
semantics is a build-level concern — the conversion is made overflow-safe and pinned by a
hash-stability test).

**Acceptance Scenarios**:

1. **Given** the grep parity script over stated docs claims, **Then** no dishonest claim
   remains (counts equal reality).
2. **Given** `SwiftDataIntegration.updateAndPersist`, **Then** it either actually persists the
   state into a model or no longer claims to.

### Edge Cases

- Weak container + element whose work finishes exactly as the container deallocates: guards
  make it a no-op.
- Conditional watch where BOTH branches are watched in the same recompute (diamond) — edges
  must accumulate within one pass, not reset mid-pass.
- Single-flight fetcher that throws: all waiters receive the error; next caller fetches again.
- Remote snapshot applying an empty dictionary: local defaults resume (no sticky remote values).
- `historyCap` cap of 1: ring buffer keeps exactly the latest event.
- `@Debounce` on a function with default parameters: forwarding keeps defaults at the call
  site of the peer.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Provider elements MUST NOT strongly retain their container; container release
  MUST deallocate held elements; async element work with a nil container MUST exit silently.
- **FR-002**: External listeners MUST observe Notifier/AsyncNotifier mutations; observer
  notifications MUST fire on that path.
- **FR-003**: `removeListener` MUST resolve elements served by a parent container.
- **FR-004**: Provider dependency edges MUST be rebuilt at each recompute (conditional watches
  work) and dependent-ref storage MUST be deduplicated.
- **FR-005**: `FutureProvider.future` MUST throw after a failed refresh; `AsyncNotifier` MUST
  cancel in-flight work and resolve pending futures on dispose; the recompute cycle fallback
  MUST fail loudly in Release.
- **FR-006**: `useTransition`/pending semantics, cancellation surfacing, deferred-write
  consistency, loud slot mismatches, non-mutable public hook storage, and deterministic
  reducer re-entrancy per Story 3 acceptance.
- **FR-007**: Persistence behaviors per Story 4 acceptance (error surfacing, throwing saves,
  corruption hook, cached fileAtom, versioned migration, keychain service namespace, `.always`
  removal).
- **FR-008**: Cache behaviors per Story 5 acceptance (eager expiry, sweep floor, single-flight,
  clear onEvict, sweep safety, `.batch` removal, memory-pressure wiring helper).
- **FR-009**: Flags/analytics behaviors per Story 6 acceptance (remote precedence + replace,
  salted bucketing, ordered funnels with correct completion counts, bounded journeys,
  flush-failure requeue, includeValues + persistLocal implementations).
- **FR-010**: DevTools behaviors per Story 7 acceptance (UI updates reachable, metrics
  cached/forgetful, storeSnapshots semantics, replay input validation).
- **FR-011**: Testing helpers per Story 8 acceptance (seeded injectable RNG, working overrides,
  no silent stubs in public API, failure-recording assertions).
- **FR-012**: Concurrency utilities per Story 9 acceptance (no spurious timeout, no limiter
  deadlock, no input traps, honest docs).
- **FR-013**: Macros per Story 10 acceptance (generated code compiles for the documented
  examples; diagnostics for misuse).
- **FR-014**: Sweep per Story 11 acceptance (no dead public code, no dishonest doc claims,
  overflow-safe hashing, guarded statistics).
- **FR-015**: Every behavior fix ships with a regression test (red→green where the old behavior
  was observable on host); doc-only fixes verified by grep parity; the full package test suite
  and Examples build stay green.

### Key Entities

- **Weak element↔container link**: the only new entity; semantics documented in data-model
  addendum.
- **Salted bucket key**: `"<experimentId>:<userKey>"` for rollouts and AB assignment.
- **Single-flight registry**: per-key in-flight task map inside the cache-aside helpers.
- **Schema version key**: persisted alongside UserDefaults-atom payloads.
- **Render counter (008) / history revision**: DevTools UI observation token.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Releasing a container with mixed listened/unlistened elements deallocates the
  container and all elements (weak-ref assertions).
- **SC-002**: Notifier mutations reach `container.listen` and observers 100% of the time
  (pinned test).
- **SC-003**: Every documented macro example compiles (compilability-checked expansions).
- **SC-004**: Zero silent stubs remain in public API (grep: empty-bodied public funcs).
- **SC-005**: Full package `swift test` green; Examples green; new regression suites for every
  behavioral story (US1–US10).
- **SC-006**: Grep parity script reports no dishonest doc claims from the review list.

## Assumptions

- Per-finding file:line evidence is in `docs/production-review-2026-10-27.md`; that report is
  normative for locations, this spec for decisions.
- The weak-container refactor preserves public API shape (`element.container` may become
  optional — public API change documented in the changelog with migration note).
- Removing V1-stub APIs (`.batch`, dishonest helpers) is allowed pre-1.0 with changelog
  entries; nothing already honored keeps its old meaning silently.
- Funnel ordering uses event timestamps when present; events without timestamps are treated as
  unordered arrivals for that user (documented).
- `persistLocal` writes flushed batches to a JSON file in the platform caches directory keyed
  by config; rotation/size limits are out of scope.
- Macro tests upgrade from expansion-string assertions to compilability assertions only where
  the test infrastructure supports it; otherwise two-use-per-module expansion tests approximate
  it.
- Out of scope: features not in the review findings; performance work beyond the named
  complexity fixes (metrics caching, single-flight, sweep safety).
