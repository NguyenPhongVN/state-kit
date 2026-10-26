# Research: P1 Blocker Fixes

All findings pre-verified in `docs/production-review-2026-10-27.md` (spot-checked directly against
source on 2026-10-27). No open NEEDS CLARIFICATION items; decisions below record the chosen approach
per fix and the alternatives rejected.

## D1. Hook box ↔ work retain cycle (US1, FR-001/FR-002)

**Decision**: capture the box weakly (`[weak box]`) inside every Task closure and Combine sink closure
that the box itself stores; after a `[weak box]` unwrap fails, the work result is discarded (box gone).
Keep the existing `Task.isCancelled` guards and phase-write semantics unchanged. For `useLoadMore`,
apply the same pattern to the stored `reload`/`loadNext` closures.

**Rationale**: the box owns the work; the work must not own the box. Weak capture is the minimal change
that lets `deinit { task?.cancel() }` actually run when the scope releases the slot, and it preserves
every existing write-order guarantee while the box is alive.

**Alternatives considered**:
- *Null out `box.task = nil` at completion*: fixes the cycle only after completion; in-flight teardown
  still leaks. Rejected as the load-bearing fix (kept as optional hygiene, not required).
- *Return a cancel closure the scope runs on teardown*: requires runtime/`StateScope` API changes —
  larger blast radius, touches the hook runtime contract. Rejected for this feature.
- *Unowned capture*: crashes if the box dies mid-flight; wrong semantics. Rejected.

## D2. Off-main publisher delivery (US2, FR-003)

**Decision**: route each sink through `.receive(on: DispatchQueue.main)` before subscribing
(`publisher.receive(on: DispatchQueue.main).sink(…)`), matching the semantics of the existing
`sinkOnMain` helper in `StateKitCombine` (which `StateKit` cannot import — dependency direction).

**Rationale**: Combine delivers on the upstream scheduler; the receive-on-main hop is the standard,
scheduler-agnostic fix and needs no assumption about upstream operators.

**Alternatives considered**:
- *`MainActor.assumeIsolated` in the sink*: only valid if already on the main thread; wrong for
  background upstreams. Rejected.
- *Move StateKitCombine's `sinkOnMain` down into StateKitCore*: cross-module refactor of a shared
  utility (constitution I favors consolidation long-term) but changes StateKitCombine's public surface;
  deferred — inline the hop now, consolidate later if a second call site appears.

## D3. Interceptor removal API (US3, FR-004)

**Decision**: add a token-based API to `SKAtomStore`: a new method returning an opaque removal handle
(or a `removeInterceptor(_:)` accepting the registration's identity), implemented as an idempotent
removal from the interceptors array. Deprecate the existing append-only `addInterceptor` signature in
the same change (keep it working — it forwards to the new path and discards the token). Update
`EcosystemBridge`'s `watch` to store the token and remove it in the element's `onDispose` path.

**Rationale**: additive, source-compatible, and matches how subscriber tokens (`SKSubscriberToken`)
already work in the store. Idempotent removal satisfies the re-entrancy edge case (remove during an
in-flight notify).

**Alternatives considered**:
- *Weak interceptors (store closures in weak containers)*: changes semantics for every current caller
  (closures would die as soon as no one holds them). Rejected.
- *Snapshot + filter on every notify (no API change)*: O(n) per atom write forever; hides the leak
  instead of fixing it. Rejected.

## D4. DevToolsObserver argument label (US4, FR-005)

**Decision**: rename the parameter to `oldValue:` so the implementation becomes the protocol
requirement's witness (the protocol extension's no-op default stops shadowing it). Add a container-level
test that registers the observer on a real `ProviderContainer`, updates a provider, and asserts history
recording — pinning both update and lifecycle callbacks.

**Rationale**: a one-word fix; the test is what prevents recurrence (this bug class compiles cleanly).

**Alternatives considered**:
- *Change the protocol to `previousValue:`*: public protocol change affecting `DebugProviderObserver`
  and any external conformers; breaks source compatibility for no benefit. Rejected.

## D5. Provider element `onDispose` self-retention (US5, FR-006)

**Decision**: change the three `onDispose { self… }` registrations in `FutureProviderElement`,
`StreamProviderElement`, and `AsyncSequenceProviderElement` to `[weak self]` with guard-unwrap inside.
Disposal semantics (cancel task, resume continuations with `CancellationError`, cancel subscription)
unchanged; if the element is already gone, nothing to cancel.

**Rationale**: the callback storage (`_callbacks`) keeps the closure alive as long as the element does;
the closure must not keep the element alive. Weak capture is the smallest correct change.

**Alternatives considered**:
- *Clear `_callbacks` eagerly on abandonment*: requires a new lifecycle hook ("element abandoned without
  dispose") that doesn't exist; larger redesign. Rejected.

## D6. ABTest empty variants (US6, FR-007)

**Decision**: `guard !variants.isEmpty else { return nil }` at the top of `assignUser` (after the
`isActive` guard).

**Rationale**: assignment is impossible without variants; returning nil matches the existing
"not assigned" contract. Prevents the `min(0, -1)` trap.

**Alternatives considered**: none worth recording.

## D7. StateDevScope Release stripping (US7, FR-008)

**Decision**: wrap the render-count enqueue/increment mechanism in `#if DEBUG`, mirroring how the
overlay view body is already stripped. Debug behavior unchanged except the self-sustaining loop is also
gone (count increments only when a render is caused by actual state change, not by the counter itself).

**Rationale**: build-time removal has zero Release cost; the counting side effect was only ever for the
Debug overlay.

**Alternatives considered**:
- *Non-invalidating counter (e.g. manual clock)*: keeps the machinery in Release for no consumer.
  Rejected.
- *Guard against counter-induced invalidation*: complex, still burns cycles in Release. Rejected.

## D8. EventTracker bounded retention (US8, FR-009)

**Decision**: the `events` array stops being an unconditional mirror of every tracked event. Default:
no unbounded retention — `events`/`allEvents` becomes opt-in debug tooling with an explicit cap
(default 0/none, ring-buffer drop-oldest when capped). `track()`/`flush()` contracts unchanged.

**Rationale**: the array exists for inspection only (flush releases `batch`); unbounded retention in a
process-lifetime singleton is the defect. Ring-buffer drop-oldest is predictable and bounded.

**Alternatives considered**:
- *Cap with error/flush on overflow*: couples retention to the flush pipeline; surprising. Rejected.
- *Remove the array outright (breaking)*: public API removal without deprecation — violates V.5.
  Rejected in favor of capped opt-in.

## D9. Keychain ordering (US9, FR-010/FR-011)

**Decision**: (a) `KeychainNotifier.updateValue` — `try provider.store(value)` first, then commit
`state = value`; the thrown error propagates and state still reflects the stored truth. (b)
`KeychainBatch.store` — replace delete-then-add with the update-then-insert pattern already used by
`KeychainStateProvider.store` (query-update first; on `errSecItemNotFound` fall back to add), so a
failed write never destroys the previous secret; fail-fast with the thrown error.

**Rationale**: commit-after-success is the standard write-through ordering; update-then-insert is
already proven elsewhere in the same file (and pinned by its tests).

**Alternatives considered**:
- *Rollback on failure (re-read + restore)*: extra keychain round trips and its own failure modes.
  Rejected — update-then-insert never destroys anything in the first place.

## D10. DeterministicTimeProvider.advance (US10, FR-012)

**Decision**: `currentTime = currentTime.addTimeInterval(interval)` (matches the correct
`DeterministicTestEnvironment.advance`). Negative intervals allowed; no clamping.

**Rationale**: the API's documented meaning; one-line fix pinned by a test.

**Alternatives considered**: none.

## Test strategy (all fixes, FR-013 / constitution VII)

- Write each regression test first, run it, observe red (where feasible: crash/no-op fixes red is
  observable; deallocation tests fail by non-nil weak refs; the DevToolsObserver label test fails by
  zero history entries).
- Leak fixes verified by deallocation assertions: keep a `weak` reference to the box/element, release
  the scope/container, assert nil (optionally after one `await Task.yield()` hop for async teardown).
- Off-main test: a publisher that emits from a non-main queue with thread assertions in the phase
  observer; the test fails on any off-main phase write.
- Keychain tests reuse the existing error-injection/mock patterns from `Tests/StateKitPersistenceTests`.
- Run order per fix: `swift test --filter <Suite>` for the touched target; full `swift test` before
  completion report.
