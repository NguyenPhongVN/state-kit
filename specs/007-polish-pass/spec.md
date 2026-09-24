# Feature Specification: Polish Pass — Deferred Hooks, Async Cache, Remote Flags, Behavior Fixes

**Feature Branch**: `polish-pass`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Remaining review items in one pass: (1) useDeferred hook — a value that lags rapid state changes by re-rendering at low task priority (SwiftUI take on React useDeferredValue) plus useTransition exposing (isPending, start); (2) SKAsyncCache — actor-based key-value cache in StateKitCache usable from background contexts, optional LRU capacity and TTL expiry; (3) remote flag adapter — a Sendable protocol in StateKitFeatureFlags supplying remote flag overrides fetched from anywhere, merged over local evaluation, plus an in-memory test adapter; (4) behavior fixes: TTL cache expiry fires only onExpire (onEvict reserved for capacity/manual), and GeolocationRollout gains an injectable region resolver so isEnabled can actually work. All new APIs follow the conventions rulebook, ship with tests written first, and keep all gates green."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Expensive updates stop blocking the screen (Priority: P1)

A developer renders a large filtered list fed by a fast-changing search field. Today every keystroke re-renders everything at once. After this story, two new hooks exist: `useDeferred(value)` returns a lagging copy of the value that catches up at low task priority (so urgent renders — the text field — stay responsive), and `useTransition()` exposes `isPending` plus a `start` closure so heavy work can be marked as non-urgent. Both are plain hooks usable inside `StateScope`/`StateView` with the same stable-order rules as the rest.

**Why this priority**: The single most requested missing capability from the React model.

**Independent Test**: Update the tracked value rapidly; the deferred copy catches up within a bounded window while the urgent binding updated immediately; `isPending` flips true during the transition.

**Acceptance Scenarios**:

1. **Given** `useDeferred`, **When** the source value changes several times quickly, **Then** the deferred value updates after the urgent renders, eventually equal to the latest source.
2. **Given** `useTransition`, **When** `start` runs a heavy update, **Then** `isPending` is true during the work and false afterwards.

---

### User Story 2 - Cache usable from any isolation domain (Priority: P1)

Background tasks today cannot use the library's caches (all MainActor-only). After this story, an actor-based key-value cache exists: `get`, `set`, `remove`, `removeAll` callable from any isolation domain; optional capacity with least-recently-used eviction; optional per-entry time-to-live. Same family semantics as the existing MainActor caches, no global state.

**Why this priority**: Unlocks the cache module for non-UI use (network layers, background refresh).

**Independent Test**: Concurrently exercise the cache from multiple tasks; entry count never exceeds capacity; LRU/TTL eviction behaves as documented; race-free.

**Acceptance Scenarios**:

1. **Given** a capacity-bounded async cache under concurrent writes beyond capacity, **Then** the size stays at capacity and eviction follows recency.
2. **Given** entries with a short TTL, **When** read after expiry, **Then** nil returns and the entries are gone.

---

### User Story 3 - Flags can come from anywhere (Priority: P2)

A team wants flag values from a backend/Firebase. Today evaluation is purely local. After this story, a Sendable adapter protocol supplies remote overrides (flag id → enabled), a merge point applies them over local evaluation (remote wins when present), and an in-memory adapter ships for tests/previews.

**Why this priority**: Completes the feature-flags story; adapter keeps the library dependency-free.

**Independent Test**: Register an adapter returning overrides; evaluation reflects them; adapter returning nothing falls back to local evaluation.

**Acceptance Scenarios**:

1. **Given** an adapter providing `{ "new_checkout": true }` while local says false, **Then** evaluation returns true.
2. **Given** an adapter providing no entry for a flag, **Then** local evaluation decides.

---

### User Story 4 - Callback semantics cleaned up (Priority: P2)

Two documented-but-surprising behaviors from the review get fixed: (a) TTL expiry fires only `onExpire` — `onEvict` is reserved for capacity pressure and manual removal; (b) `GeolocationRollout` accepts an injectable region resolver closure so `isEnabled` can work when the host knows the region (default resolver nil → still false, documented).

**Why this priority**: Correctness/honesty cleanups; small and safe.

**Independent Test**: TTL expiry triggers exactly one callback (`onExpire`); a GeolocationRollout with a resolver returning an allowed region evaluates true; default resolver stays false.

**Acceptance Scenarios**:

1. **Given** a TTL cache with both callbacks set, **When** an entry expires, **Then** only `onExpire` fires.
2. **Given** a resolver returning an allowed region, **When** `isEnabled` runs, **Then** true; with a disallowed or nil region, false.

### Edge Cases

- What happens when deferred source changes again before catch-up? (Only the latest value needs to land; intermediate renders may coalesce.)
- What happens when the async cache is hit by concurrent writes to the same key? (Actor serialization makes last-write-wins deterministic.)
- What happens when the remote adapter throws or returns stale data? (Throws surface as evaluation failure = flag disabled; adapter output replaces only the flags it provides.)
- What happens when GeolocationRollout's resolver returns a region with different casing? (Region matching is case-sensitive, documented.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-01**: `useDeferred(_:)` MUST return a value that initially equals the source and catches up to the latest source value asynchronously at lower task priority, without violating hook stability rules.
- **FR-02**: `useTransition()` MUST return an `isPending` flag and a `start` closure; `isPending` MUST be true from `start` until its work completes.
- **FR-03**: An actor-based cache MUST provide `get`, `set`, `remove`, `removeAll` from any isolation domain, with optional LRU capacity and optional TTL, race-free.
- **FR-04**: A remote flag adapter protocol MUST exist (Sendable), MUST be consulted during flag evaluation with remote overrides taking precedence, and MUST ship with an in-memory implementation.
- **FR-05**: TTL expiry MUST fire only `onExpire`; `onEvict` fires only for capacity eviction and manual removal (behavior fix, changelog-documented).
- **FR-06**: `GeolocationRollout` MUST accept an optional injectable region resolver; with a resolver, eligibility = resolver region ∈ allowedRegions; without one, eligibility stays false (documented).
- **FR-07**: All new APIs follow the conventions rulebook and ship with red→green tests; all gates hold (build/test/Examples).

### Key Entities *(include if feature involves data)*

- **Deferred value**: lagging copy of a source value with low-priority catch-up.
- **Transition**: `(isPending, start)` pair guarding non-urgent work.
- **SKAsyncCache**: actor; entries keyed, optional capacity (LRU) and TTL.
- **Remote flag adapter**: Sendable source of `{flagId: enabled}` overrides + in-memory implementation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-01**: Deferred value eventually equals the latest source (100% across rapid-update tests) while urgent renders were not delayed by the catch-up work.
- **SC-02**: `isPending` is observable true during and false after `start` work (test-verified).
- **SC-03**: Async cache sustains concurrent multi-task access with size ≤ capacity, LRU/TTL eviction verified by tests.
- **SC-04**: Remote override wins when present, local decides when absent (test-verified); in-memory adapter ships.
- **SC-05**: TTL expiry fires exactly one callback (`onExpire`) — test-verified; GeolocationRollout resolver paths test-verified.
- **SC-06**: All gates green; new symbols fully documented per rulebook.

## Assumptions

- The deferred/transition hooks live in the `StateKit` hooks module and follow the same positional-slot rules as existing hooks; the deferred catch-up runs on a lower-priority Task and coalesces to the latest value.
- `SKAsyncCache` is a standalone actor in `StateKitCache` — it does not bridge to the MainActor caches.
- The remote flag adapter fetches overrides as a dictionary snapshot; hosts control refresh timing (pull model) — push/streaming is out of scope.
- TTL callback fix is a behavior change (documented in changelog) — hosts relying on double-fire are affected.
- GeolocationRollout's region matching is exact string equality (case-sensitive), documented.
