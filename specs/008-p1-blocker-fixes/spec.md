# Feature Specification: P1 Blocker Fixes (Production Readiness)

**Feature Branch**: `008-p1-blocker-fixes`

**Created**: 2026-10-27

**Status**: Draft

**Input**: User description: "Fix P1 production blockers found in docs/production-review-2026-10-27.md — retain cycles in hooks, interceptor leak, dead DevTools observer, off-main state writes, ABTest crash, Release render loop, provider onDispose cycles, unbounded analytics buffer, Keychain destructive ordering, no-op time advance. Each fix ships with a regression test."

## Clarifications

### Session 2026-10-27 (unattended — defaults chosen per workspace rules)

- Q: Weak-capture strategy for hook boxes? → A: `[weak box]` in task/subscription closures; clearing
  `box.task = nil` on completion optional hygiene, not load-bearing.
- Q: Interceptor API shape? → A: Additive token-based removal (`addInterceptor` gains a returning variant
  or a new `removeInterceptor`); old append-only signature deprecated, not removed (Principle V.5).
- Q: How is Release stripping enforced for `StateDevScope`? → A: `#if DEBUG` around the counting
  mechanism, mirroring how the overlay view is already stripped.
- Q: `EventTracker` retention semantics? → A: Unbounded `events` history becomes capped, opt-in debug
  tooling (default retains nothing unbounded); tracking/flush contracts unchanged.
- Q: Keychain batch failure semantics? → A: Fail-fast with thrown error; previous secret survives any
  failure; partial-batch state is documented.
- Q: Negative `advance(by:)` intervals? → A: Permitted (time moves backwards); no clamping.
- Q: Scope of this feature vs remaining review findings? → A: Only the 10 P1 blockers listed; ~45 P2 and
  ~23 P3 findings deferred to feature 009+.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Async/publisher hooks release their work on teardown (Priority: P1)

A library consumer renders a view whose body calls `useAsync`, `useAsyncPerform`, `useAsyncRefresh`,
`useAsyncSequence`, `usePublisher`, `usePublisherPerform`, or `usePublisherRefresh`, then the view (or
`StateScope`) is torn down while work is still in flight. Today the hook's internal box participates in a
retain cycle with its own Task/subscription: teardown never cancels the in-flight work, the box leaks for
the process lifetime, and an infinite source (e.g. a 1-second timer sequence, the documented example for
`useAsyncSequence`) keeps firing into an orphaned signal forever. After the fix, releasing the scope
releases the box and cancels the work, verified by deallocation assertions (weak-reference tests), not
just behavior.

The same cycle exists in `useLoadMore` (`StateKitSupport`): its stored `reload`/`loadNext` closures capture
the box strongly, so the box leaks and in-flight page loads continue into a dead signal after teardown.

**Why this priority**: memory leaks that grow with navigation are the single largest production risk in the
review; the affected hooks are the library's headline API.

**Independent Test**: render a hook over an in-flight/infinite operation inside a `StateTest` (or equivalent
harness), drop the context, and assert (a) the box deallocates (weak reference becomes nil) and (b) the
in-flight task is cancelled (operation observes `Task.isCancelled` or the timer stops firing).

**Acceptance Scenarios**:

1. **Given** a `useAsync` hook with an operation suspended awaiting a never-resolving future, **When** the
   owning scope is released, **Then** the operation task is cancelled and the hook box deallocates.
2. **Given** a `useAsyncSequence` hook over an infinite timer sequence, **When** the owning scope is
   released, **Then** no further sequence values are consumed (the timer's underlying task is cancelled)
   and the box deallocates.
3. **Given** a `usePublisher`/`usePublisherPerform`/`usePublisherRefresh` hook subscribed to a subject,
   **When** the owning scope is released, **Then** the subscription is cancelled and the box deallocates.
4. **Given** a `useLoadMore` hook that has started loading a page, **When** the owning scope is released,
   **Then** the in-flight load task is cancelled and the hook box deallocates.

---

### User Story 2 - Publisher hooks never write view state off the main thread (Priority: P1)

A consumer subscribes `usePublisher` (or `usePublisherPerform`/`usePublisherRefresh`) to a publisher that
emits on a background queue (e.g. URLSession). Today the hook writes `@Observable` hook state directly from
the emitting thread, racing SwiftUI's main-thread render. After the fix, hook state writes from publisher
deliveries happen on the main actor regardless of the upstream scheduler.

**Why this priority**: a cross-thread write to view state is a data race — undefined behavior, UI
corruption, and (under strict concurrency) exactly the class of bug this library promises to prevent.

**Independent Test**: drive the hook with a subject/publisher that emits from a background thread and
assert every state observation (phase changes) is observed on the main actor.

**Acceptance Scenarios**:

1. **Given** `usePublisher` attached to a publisher emitting from a background queue, **When** values
   arrive, **Then** the hook's phase signal updates on the main actor (no off-main write).
2. **Given** the same setup for `usePublisherPerform` and `usePublisherRefresh`, **When** the operation
   completes, **Then** completion and failure phases also land on the main actor.

---

### User Story 3 - Watching an atom from a provider does not leak a permanent store interceptor (Priority: P2)

A provider element watches an atom via the ecosystem bridge. Today each watch installs a closure into the
atom store's append-only interceptor list with no removal API: the closure lives for the store's lifetime,
memory grows by one leaked closure per (provider, atom) edge ever created (including every family member),
and every atom write in the app iterates the full accumulated list, degrading linearly with usage history.
After the fix, interceptors are removable, the bridge removes its interceptor when the provider element
disposes, and a long-lived app's interceptor count returns to its steady-state after disposal.

**Why this priority**: unbounded memory + linear performance degradation in the hot write path; affects
every navigation-heavy app using providers over atoms.

**Independent Test**: record the store's interceptor count, create and dispose a provider that watches an
atom, and assert the count returns to its baseline; additionally assert a second provider still receives
invalidation while alive.

**Acceptance Scenarios**:

1. **Given** a provider element that watches an atom, **When** the element is disposed, **Then** the
   store's interceptor count returns to what it was before the watch was installed.
2. **Given** two live provider elements watching the same atom, **When** the atom is written, **Then**
   both elements invalidate; **When** one disposes and the atom is written again, **Then** only the
   surviving element invalidates.

---

### User Story 4 - DevTools observer actually receives provider updates (Priority: P2)

A consumer registers `DevToolsObserver` on a `ProviderContainer` to record provider history. Today the
observer implements the update callback with the wrong argument label (`previousValue:` instead of the
protocol's `oldValue:`); the protocol extension's no-op default satisfies the conformance, so the
container calls the default and the observer's implementation never runs — history recording is silently
dead. After the fix, the observer's method matches the protocol requirement and a test through a real
`ProviderContainer` proves updates are recorded.

**Why this priority**: the module's headline feature is a no-op today; it is undetectable without a test
because the code compiles.

**Independent Test**: create a container with a `DevToolsObserver`, update a provider, assert the
observer's history/counts changed.

**Acceptance Scenarios**:

1. **Given** a container with a `DevToolsObserver`, **When** a watched provider's state is updated,
   **Then** the observer records the update (history entry count increases, before/after values present).
2. **Given** the same observer, **When** a provider is added/disposed, **Then** the corresponding
   lifecycle callbacks fire (they already do; the test pins them so the label regression cannot recur).

---

### User Story 5 - Async provider elements do not retain themselves through onDispose (Priority: P2)

`FutureProviderElement`, `StreamProviderElement`, and `AsyncSequenceProviderElement` register
`onDispose { self… }` closures that capture themselves strongly, forming element→callbacks→closure→element
cycles. After the fix, these closures capture weakly, the async-sequence pump captures its element weakly
across iteration (cancelling from `deinit`), and the listener-driven disposal path (addListener →
removeListener → checkAutoDispose) deallocates the element and cancels its in-flight work.

**Why this priority**: same leak class as Story 1 but in the Riverpods layer; fix is small and local.

**Independent Test**: drive the real lifecycle (addListener → work in flight → removeListener → container
released) and assert the element deallocates (weak reference becomes nil) and the work is cancelled.

**Acceptance Scenarios** *(revised during implementation — see Assumptions)*:

1. **Given** a container holding a `FutureProvider` element with an active listener, **When** the work
   completes, the listener is removed and the container is released, **Then** the element deallocates.
2. **Given** the same setup for `StreamProvider` and `AsyncSequenceProvider` elements, **When** the
   listener is removed and the container is released, **Then** the elements deallocate and the
   stream/pump is cancelled.
3. **Given** a disposal, **When** it runs, **Then** in-flight work is cancelled (existing semantics
   preserved).

> Implementation discovery (2026-10-27): abandonment WITHOUT listener-driven disposal still pins the
> element through its strong `container` back-reference (element → container → elements dict → element).
> Breaking that architectural cycle requires a weak-container refactor with nil-semantics audit across
> the recompute/watch/read paths — deferred to feature 009 as its own P1 finding.

---

### User Story 6 - A/B test assignment is total: no crash on empty variants (Priority: P3)

`ABTest.assignUser` traps (index out of range) when the test declares zero variants — reachable from
public API. After the fix, an empty-variant test assigns no user (returns nil) and never traps.

**Why this priority**: a reachable crash in a public analytics API; trivial guard.

**Independent Test**: call `assignUser` on an `ABTest` with an empty variant list; assert nil, no crash.

**Acceptance Scenarios**:

1. **Given** an active `ABTest` with `variants: []`, **When** `assignUser(userId)` is called, **Then** it
   returns nil (assignment impossible) instead of trapping.

---

### User Story 7 - `StateDevScope` render counting does not run in Release builds (Priority: P3)

`StateDevScope`'s body enqueues a post-render effect that increments a `@State` render counter on every
body pass; the increment invalidates the view, which runs the body again — a self-sustaining re-render
loop that also runs in Release builds (the `#if DEBUG` strip covers only the overlay view). After the fix,
the counting/enqueue machinery is compiled out (or made non-invalidating) in Release, and the overlay's
count still works in Debug without an infinite loop.

**Why this priority**: silent CPU/battery burn in production apps that ship a dev scope; Debug behavior
unchanged.

**Independent Test**: the counter mechanism is absent from Release builds (build-time condition); in
Debug, a body pass does not enqueue another invalidating body pass (render count stable when state is
quiescent).

**Acceptance Scenarios**:

1. **Given** a `StateDevScope` in a Debug build, **When** no state changes occur, **Then** the view does
   not continuously re-render (body passes stop after the initial ones).
2. **Given** the same scope compiled for Release, **Then** no render-counting effect is enqueued at all.

---

### User Story 8 - EventTracker memory is bounded (Priority: P3)

`EventTracker` appends every tracked event to an `events` array that only a manual `clearEvents()`
empties; flush releases only the batch. A long-lived tracker grows without bound for the app's lifetime.
After the fix, the retained history is bounded: flush no longer leaves flushed events accumulating
forever, and any debug retention is capped and opt-in.

**Why this priority**: unbounded memory in a module intended to run for the whole app lifetime; the fix
must not change the tracking/flush contract.

**Independent Test**: track more than N events (with flushing), assert retained memory (the `events`
array / allEvents view) stays within the documented bound.

**Acceptance Scenarios**:

1. **Given** an `EventTracker` that has flushed batches repeatedly, **When** thousands of events have
   been tracked, **Then** the tracker's retained event storage does not grow without bound (bounded by a
   documented cap; default behavior retains no unbounded history).
2. **Given** a consumer that explicitly enables debug retention with a cap, **When** the cap is exceeded,
   **Then** the oldest retained events are dropped (ring-buffer semantics) and tracking/flush behavior is
   unchanged.

---

### User Story 9 - Keychain writes never destroy the previous secret on failure (Priority: P3)

Two defects in the persistence layer's keychain ordering: (a) `KeychainNotifier.updateValue` commits the
in-memory state before the store call, so a failed store leaves state claiming success (silently reverted
on next build); (b) `KeychainBatch.store` deletes the existing item before adding, so a failed re-add
destroys the previous secret and aborts the batch mid-way. After the fix, state is committed only after a
successful store, and batch updates use the update-then-insert pattern already proven by
`KeychainStateProvider.store` (never destroy the old value first).

**Why this priority**: data loss (irreversible secret destruction) and silently lying state in the
security-critical path.

**Independent Test**: force a store failure (error-injected provider for (a); mocked SecItem path or
error-provoking item for (b)) and assert the previous value survives and state reflects failure.

**Acceptance Scenarios**:

1. **Given** a `KeychainNotifier` whose provider throws on `store`, **When** `updateValue` is called,
   **Then** it throws and the notifier's state still reflects the previously stored value.
2. **Given** a `KeychainBatch` with an existing item, **When** the store of that item fails, **Then** the
   previously stored value remains readable and the error is surfaced to the caller.

---

### User Story 10 - Deterministic time actually advances (Priority: P3)

**Resolved as verified-not-a-defect during implementation**: the review's "no-op" finding was a false
positive — on current Apple SDKs `Date.addTimeInterval(_:)` is a *mutating* call (returns `Void`), so
`currentTime.addTimeInterval(interval)` correctly advances the clock. The behavior is now pinned by a
regression test (`DeterministicTimeAdvanceTests`) instead of a code change; the review report is
corrected accordingly.

**Why this priority**: the finding claimed a public testing API silently did nothing; the red→green run
disproved it, and the pinned test prevents regressions either way.

**Independent Test**: create a `DeterministicTimeProvider`, advance by an interval, assert the current
time changed by exactly that interval.

**Acceptance Scenarios**:

1. **Given** a `DeterministicTimeProvider` at time T, **When** `advance(by: 60)` is called, **Then**
   `now()` equals T + 60 seconds (pinned by test; passes against the unchanged implementation).

### Edge Cases

- Hook operation that completes successfully before teardown: cancellation must be a no-op and the final
  phase must remain `.success`/`.value` (no double-write after completion).
- A cancelled task that has already written its final phase must not write again (existing
  `Task.isCancelled` guards preserved).
- Interceptor removal during an in-flight atom write (remove while `notifyInterceptors` iterates) must
  not crash — removal semantics must tolerate re-entrancy or be deferred.
- `ABTest` with `variants: []` but `trafficPercentage: 0` and `trafficPercentage: 100` (guard ordering).
- `EventTracker` with `batchSize` larger than total events (flush never fires) — cap still enforced.
- `DeterministicTimeProvider.advance` with negative interval (allowed — moves time backwards; must still
  mutate).
- Keychain batch where the first item fails: later items must not be silently half-updated without an
  error report (fail-fast with the thrown error is acceptable; document it).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every async/publisher hook box (`useAsync`, `useAsyncPerform`, `useAsyncRefresh`,
  `useAsyncSequence`, `usePublisher`, `usePublisherPerform`, `usePublisherRefresh`) MUST release its
  in-flight task/subscription when the hook's owning scope releases the box, and the box MUST deallocate
  (no retain cycle between the box and its own work closures).
- **FR-002**: `useLoadMore`'s stored reload/loadNext closures MUST NOT retain the hook box; teardown MUST
  cancel the in-flight load.
- **FR-003**: Publisher-driven hooks (`usePublisher`, `usePublisherPerform`, `usePublisherRefresh`) MUST
  deliver all hook-state writes on the main actor regardless of the upstream scheduler.
- **FR-004**: The atom store interceptor registry MUST support removal (token-based), and the
  provider→atom bridge MUST remove its interceptor when the provider element disposes.
- **FR-005**: `DevToolsObserver` MUST implement the observer protocol's update requirement with the
  protocol's exact argument labels, and a container-level test MUST exercise the observer's update path.
- **FR-006**: `onDispose` registrations in `FutureProviderElement`, `StreamProviderElement`, and
  `AsyncSequenceProviderElement` MUST NOT capture their element strongly; disposal semantics (cancel
  in-flight work) MUST be preserved.
- **FR-007**: `ABTest.assignUser` MUST return nil for a test with no variants instead of trapping.
- **FR-008**: `StateDevScope`'s render-counting mechanism MUST NOT be active in Release builds.
- **FR-009**: `EventTracker` MUST bound its retained event history (no unbounded growth by default; any
  retention feature is capped and opt-in).
- **FR-010**: `KeychainNotifier.updateValue` MUST persist before committing in-memory state (failure
  leaves prior state intact and surfaces the error).
- **FR-011**: `KeychainBatch.store` MUST NOT delete an existing item before its replacement is
  successfully stored (update-then-insert; the previous secret MUST survive any failure).
- **FR-012**: `DeterministicTimeProvider.advance(by:)` MUST mutate the provider's current time by the
  given interval.
- **FR-013**: Every fix above MUST ship with a regression test that fails before the fix and passes
  after (constitution Principle VII); leak fixes verified by deallocation (weak-reference) assertions.

### Key Entities *(include if feature involves data)*

- **Interceptor token**: a handle returned when registering an atom-store interceptor; removing a token
  unregisters exactly that interceptor. Removal is idempotent (removing twice or after store teardown is
  a no-op).
- **Hook box**: per-slot state container for a hook; owns its task/subscription only until teardown.
- **Event retention cap**: maximum number of retained (non-flushed-archived) events in an
  `EventTracker`; default excludes unbounded retention.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Releasing a scope running an infinite async-sequence hook results in zero further sequence
  consumption within one run-loop tick and full deallocation of the hook box (verified by weak-reference
  assertion in tests).
- **SC-002**: Repeated create/dispose cycles of a provider watching an atom leave the store's interceptor
  count at its baseline (zero growth after N cycles).
- **SC-003**: A `DevToolsObserver` registered on a container records 100% of provider state updates made
  through the container (pinned by test).
- **SC-004**: Background-emitting publisher drives hook state exclusively on the main actor (pinned by
  test that fails on any off-main write).
- **SC-005**: All existing tests continue to pass; the 10 new regression suites (one per story) pass.
- **SC-006**: No public API removal is required for these fixes; the only public API addition is the
  interceptor token/removal API, documented with lifecycle semantics.

## Assumptions

- Fixes follow the review report `docs/production-review-2026-10-27.md` findings 1, 2, 4, 7, 10, 12, 13,
  16, 17, 24 (P1 list); P2 semantic items (dependency-edge rebuild, listen blind spot, funnel math,
  SwiftData facade, Testing stubs) are deferred to a follow-up feature.
- Weak-capture (`[weak box]`) is the chosen strategy for hook boxes; clearing `box.task = nil` on
  completion may be added for hygiene but is not the load-bearing fix. Documented default chosen
  unattended per workspace rules.
- The interceptor removal API is additive (token-based `addInterceptor` returning a removal handle) to
  avoid breaking existing call sites; the existing append-only signature is deprecated in the same change
  rather than removed (constitution Principle V.5 deprecation rule).
- `StateDevScope` Release behavior is enforced with `#if DEBUG` around the counting mechanism (build-time
  removal), matching how the overlay view is already stripped.
- `EventTracker` default behavior: retained `events` history becomes opt-in debug tooling with an
  explicit cap (default 0/none); tracking and flush contracts unchanged.
- Keychain tests use the existing error-injection/mocking patterns from the keychain test suite (no new
  test infrastructure).
- `DeterministicTimeProvider` semantics: negative intervals are permitted (time moves backwards); no
  clamping introduced.
- Out of scope: the remaining ~45 P2 and ~23 P3 findings (tracked for feature 009+).

### Implementation addendum (2026-10-27)

- **US5 verification contract revised** (see Story 5): acceptance now uses the listener-driven disposal
  lifecycle; abandonment-without-disposal is blocked by the element↔container strong back-reference
  cycle — newly documented as a P1 candidate for feature 009 (weak-container refactor + nil-semantics
  audit of recompute/watch/read paths).
- **US10 resolved as not-a-defect** (see Story 10): `Date.addTimeInterval(_:)` is mutating on current
  SDKs; behavior pinned by test, review report corrected.
- **US2 observable behavior change**: publisher deliveries now arrive one main-queue turn later; the
  existing `Publisher.asPhase` bridge test was updated to await the hop, and the change is
  changelog-documented.
- `EventTracker` retained history became opt-in (`AnalyticsConfig(historyCap:)`); the pre-existing
  `testEventTracking` test was updated to opt in.
