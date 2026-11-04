# Phase 1 Data Model: P2 Hardening + CI/Docs Batch

**Feature**: 011-p2-hardening-ci | **Date**: 2026-11-05

## Entity: Provider identity

| Aspect | Before | After |
|---|---|---|
| Unnamed provider | `_id = UUID()` per instance | unchanged |
| Named provider | `_id = UUID()` per instance | `_id = AnyHashable("<name>#<ValueType>")` — stable per name+type |
| Family instance | internal init with explicit per-arg id | unchanged |

Invariants: same name + same value type ⇒ one element per container; distinct name/type ⇒
distinct element; `Hashable` continues to hash `_id` only.

## Entity: Reducer dispatch queue

State machine (per hook slot): idle → dispatching(initial apply) → draining(queue)
→ idle. Re-entrant dispatch during ANY phase appends to `pendingActions`; flag resets
only after the queue is empty. Invariant: no queued action is applied outside the flag's
protection.

## Entity: Debounce schedule

Critical section (lock) wraps cancel-previous → create-task → store. Invariant: at most
one live scheduled task; the latest stored task always carries the latest input.

## Entity: Propagation round

`flushChanges` performs at most 100 rounds per flush; each round drains the current
`pendingChanges` set. On bound hit: remaining set reported (DEBUG), loop breaks,
`isBatching` still resets (no stuck batching).

## Entity: File-backed storage

`cachedValue` joins `observers` under the same lock. Invariant: no unguarded read/write
of `cachedValue`; concurrent save/load never tear (atomic file write unchanged).

## Entity: SwiftData-backed notifier

Key: `String(describing: T.self)`. Build: fetch record by key → decode → value, else
seed default. `updateAndPersist` contract unchanged (commit after successful save).

## Entity: Stream write chain

Per-element FIFO of write tasks; each awaits its predecessor. Invariant: state
transitions observed in emission order; terminal failure ordered after last value.

## CI artifacts

Workflow gains: explicit Xcode selection (fail loud if declared version missing),
`actions/cache` on `.build` keyed by `Package.resolved`, lint without permissive
override, experimental thread-sanitizer job (non-blocking, comment records promotion
rule).

## Dependency graph

`swift-composable-architecture` removed from manifest + lockfile; StateConcurrency keeps
`StateKit` only.
