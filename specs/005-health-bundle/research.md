# Research: Health Bundle

Feature: specs/005-health-bundle · Date: 2026-09-25

## D1 — Replay design

**Decision**: replace `replay()` with
`mutating func replay(using handler: @Sendable (String) async throws -> Bool) async -> ReplayReport`
where `ReplayReport` exposes `executed: [String]`, `skipped: [String]`, `failure: Error?`.
Semantics: entries with recorded actions are passed to the handler; `true` = executed,
`false` = skipped (handler can't map it); handler throw = replay stops, report carries the
error and progress so far; entries without actions are skipped. The no-argument stub is
removed (V1, changelog-documented).

**Rationale**: the history cannot know how to execute app actions — only the host can.
Handler-driven replay is how Redux DevTools works (dispatch recorded actions). The report
makes partial progress visible instead of silently pretending.

**Alternatives**: keep `replay()` and rename to `simulateTiming()` (honest but useless);
encode action closures in history (breaks export/import and adds retain semantics).

## D2 — LRU internals

**Decision**: `[Key: Node]` dictionary + intrusive doubly linked list (`final class Node`
with key/value/prev/next). `head` = most recent, `tail` = least recent. `get` → unlink + push
head. `set` → update-in-place + push head; on over-capacity pop tail and fire
`onEvict(.capacityExceeded)`. Public surface unchanged: `get/set/remove/clear/stats/keys/
count/preload/resetStats` — `keys` keeps returning oldest → newest order.

**Rationale**: identical observable behavior pinned by existing tests; O(1) per op.

**Alternatives**: `OrderedDictionary` (swift-collections) — new dependency; rejected.

## D3 — Flaky test hardening

**Decision**: add a small polling helper to the test file
(`waitUntil(timeout:pollInterval:_:)` — polls a condition up to a deadline, default 2 s,
10 ms steps) and rewrite the failing assertion in `restartThrowingTask` to poll the box value
instead of a single fixed sleep; adopt the same helper for the sibling timing assertions in
`SKAtomStoreTaskTests.swift` where a fixed sleep guards an async outcome.

**Rationale**: single-sleep assertions encode the machine's speed; polling encodes the
contract ("within 2 s").

## D4 — CI workflow

**Decision**: single `.github/workflows/ci.yml`, `on: push/pull_request`, macOS runner, two
jobs: (1) `test` — `swift build`, `swift test`, Examples `swift build`; (2) `lint` — install
SwiftLint via brew, `swiftlint lint --quiet` with `continue-on-error: true` (Clarifications:
non-blocking until the codebase is clean; flip by deleting that flag).

**Rationale**: uniform gates on every push/PR with zero package changes; lint stays visible
without red-locking the project over justified legacy conversions.

## D5 — removeObserver

**Decision**: `public func removeObserver(_ observer: ProviderObserver)` on
`ProviderContainer` — removes every list entry identical (`===`) to the argument
(`ProviderObserver: AnyObject` already holds). Repeat calls are no-ops; observers of other
containers are unaffected.
