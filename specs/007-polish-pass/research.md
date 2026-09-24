# Research & Data Model: Polish Pass

Feature: specs/007-polish-pass · Date: 2026-09-25

## D1 — useDeferred / useTransition

**Decision**: `useDeferred<T: Equatable>(_ value: T) -> T` — hook slots: `useState(value)`
for the deferred copy + two `useRef` slots (last source seen, generation counter). When the
source differs from the ref, bump the generation and spawn `Task(priority: .utility)` that
sleeps one micro-yield, then applies the captured value **only if the generation is still
current** (out-of-order protection; rapid changes coalesce to latest). Returns the deferred
state. `useTransition() -> (isPending: Bool, start: (@MainActor () async -> Void) -> Void)` —
`start` sets `isPending = true`, runs the async work on the main actor, then clears the flag
(await points let the UI render the pending state).

**Rationale**: mirrors React semantics with the existing positional hook machinery; the
generation guard makes rapid updates coalesce deterministically.

## D2 — SKAsyncCache

**Decision**: `public actor SKAsyncCache<Key: Hashable & Sendable, Value: Sendable>` with
`init(capacity: Int? = nil, ttl: TimeInterval? = nil)` and `get`/`set`/`remove`/`removeAll`/
`count`. Internals: `[Key: (value: Value, expiresAt: Date?)]` + recency array for LRU when
capacity set. Expiry checked lazily on `get` (and on set-eviction sweep). Actor isolation
makes it race-free from any domain.

**Alternatives**: mirroring the MainActor classes (rejected — the whole point is background
use); timers for TTL (rejected — lazy expiry is simpler and deterministic under test).

## D3 — Remote flag adapter

**Decision**: `public protocol RemoteFlagSource: Sendable { func fetchOverrides() async -> [String: Bool] }`;
`FeatureFlagRegistry.applyRemoteOverrides(from:) async` fetches and stores bool overrides by
flag id (visible through the existing override path in `value(for:)` for Bool flags). Ships
`InMemoryRemoteFlagSource` (thread-safe dictionary) for tests/previews.

**Rationale**: pull model keeps the registry synchronous and the host in control of refresh;
bool-only matches the current rollout/flag surface.

## D4 — TTL callback semantics

**Decision**: expiry paths (`get` on expired entry, background cleanup) fire **only**
`onExpire`. `onEvict` fires for `.capacityExceeded` (LRU) and `.manual` removal. TTLCache docs
updated. Behavior change changelog-documented (hosts relying on double-fire must move to
`onExpire`).

## D5 — GeolocationRollout resolver

**Decision**: `init(allowedRegions:percentage:regionResolver:)` where
`regionResolver: (@Sendable () -> String?)? = nil`; `isEnabled` = resolver?().map {
allowedRegions.contains($0) } ?? false. Default nil keeps documented false.

## Catalog of public additions

`useDeferred`, `useTransition`, `SKAsyncCache`, `RemoteFlagSource`,
`InMemoryRemoteFlagSource`, `FeatureFlagRegistry.applyRemoteOverrides(from:)`,
`GeolocationRollout(allowedRegions:percentage:regionResolver:)`.
