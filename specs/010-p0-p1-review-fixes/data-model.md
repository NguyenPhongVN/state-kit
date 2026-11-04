# Phase 1 Data Model: P0/P1 Review Fixes

**Feature**: 010-p0-p1-review-fixes | **Date**: 2026-11-05

No new persistent entities. This feature corrects state transitions of existing
in-memory entities. Fields below are behavior-relevant subsets.

## Entity: ProviderContainer

| Field | Role in fixes |
|---|---|
| `elements: [ProviderID: AnyProviderElement]` | Mutation rights corrected: only the **owning** container removes entries (P0 override path writes here for new override elements; checkAutoDispose now resolves owner first) |
| `overrides: [ProviderID: ProviderOverride]` | Provider-kind override element creation path fixed (P0) |
| `parent: ProviderContainer?` | Now actually wired from `ProviderScope(overrides:)` (R5) |

**State transitions (corrected)**:
- Override-by-provider: `overrides[id].providerOverride != nil` → element created,
  validated by cast (not metatype), inserted into `elements`, observers notified.
- Auto-dispose after listener removal: element owned by container C → C removes it from
  C.elements and notifies C.observers, regardless of which container received the
  removal call.

## Entity: ProviderElement

| Field | Role in fixes |
|---|---|
| `listenersCount` | Resume signal bound to 0→1 transition only (R3) |
| `keepAliveLinksCount` | Decremented exactly once per link (R2) |
| `externalListeners: [UUID: (P.State?, P.State) -> Void]` | Now notified on async completion (success/error/events) (R6) |
| `dependencies` / `dependents` | Edge cleanup resolves dep elements through the parent chain (R4) |
| `container: ProviderContainer?` (weak) | Source of truth for the owning container in dispose/edge operations (R4) |

**State transitions (corrected)**:
- `keepAlive() → close()` ×N: count −1 total; second+ closes are no-ops.
- `addListener(fireImmediately: true)` on never-computed provider: events = [resume ×1,
  value ×1] (was resume ×2).
- Future/Stream completion: stateBox write → continuations resolved → dependents
  notified → **external listeners notified** (new) → observers via notifyProviderUpdated.

## Entity: KeepAliveLink

| Field | Role in fixes |
|---|---|
| close closure + local `closed` flag | Idempotent close (R2) |

## Entity: ProviderScope (view layer)

Corrected init: override containers receive `parent: .shared` — provider resolution in
an override scope consults shared state for unoverridden providers.

## Invariants enforced after this feature

1. Each provider element is owned by exactly one container; only the owner mutates its
   registry for that element.
2. `keepAliveLinksCount ≥ 0` at all times.
3. `.resume` fires at most once per 0→1 listener transition.
4. A container listener registered before async completion receives exactly one
   completion event with the final state.
5. Unoverridden providers resolve identically inside and outside an override scope.
