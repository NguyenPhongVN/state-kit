# Data Model: P1 Blocker Fixes

No persisted data formats change. This feature touches in-memory entities only; below are the entities
whose lifecycle semantics change, with validation rules.

## InterceptorToken (new, `StateKitAtoms`)

- **Represents**: one registered atom-write interceptor inside `SKAtomStore`.
- **Fields**: opaque identity bound to the registration site (no public payload).
- **Relationships**: created by `SKAtomStore` on registration; held by the registrant
  (`EcosystemBridge`'s provider element) for the registration's lifetime.
- **Lifecycle / state transitions**: created at `addInterceptor` → active (receives changed-key
  notifications) → removed via `removeInterceptor(token)` → inert (removal is idempotent; removing an
  already-removed or never-registered token is a no-op, never a crash).
- **Validation rules**: store must not retain the interceptor closure after removal (release the
  closure so the registrant can deallocate); `notifyInterceptors` must tolerate concurrent removal
  during iteration (snapshot or index-safe iteration).

## HookBox (existing, `StateKit` / `StateKitSupport` — semantics change)

- **Represents**: per-slot state container for async/publisher hooks (`_HookAsyncBox`, publisher
  boxes, `StateLoadMore` box).
- **Changed invariant**: the box may own its Task/subscription, but the work closures MUST NOT
  strongly retain the box (weak capture only). Consequence: when the hook slot is released, the box
  deallocates and `deinit` cancels in-flight work.
- **State transitions**: unchanged (idle → loading → success/failure; loading phase writes still
  deferred via `_safeUpdate` where already in place).

## ProviderElement.onDispose registrations (existing, `Riverpods` — semantics change)

- **Changed invariant**: dispose callbacks stored in `_callbacks` MUST NOT strongly capture their
  element. Cancellation/resume work on disposal is preserved; a disposed-then-released element no
  longer self-retains.

## EventTracker retention (existing, `StateKitAnalytics` — semantics change)

- **Changed invariant**: retained event history is bounded and opt-in.
  - Default: no unbounded `events` mirror (retention cap = 0/none).
  - Opt-in debug retention: explicit cap N; on exceeding N, oldest events are dropped (ring buffer).
- **Unchanged contracts**: `track()` records + batches; `flush()` clears batch and invokes `onFlush`;
  config clamps unchanged.

## Keychain write ordering (existing, `StateKitPersistence` — ordering fix)

- **`KeychainNotifier.updateValue`**: state transition now persists-then-commits. Failure path: store
  throws → state unchanged (still previous stored value) → error surfaces to caller.
- **`KeychainBatch.store`**: per item, update existing → fallback add on `errSecItemNotFound`; failure
  aborts the batch with the thrown error and never removes the previous item.

## DeterministicTimeProvider (existing, `StateKitTesting` — behavior fix)

- `advance(by:)` mutates `currentTime` by the interval (negative allowed). No other state.
