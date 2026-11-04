# Phase 0 Research: P2 Hardening + CI/Docs Batch

**Feature**: 011-p2-hardening-ci | **Date**: 2026-11-05

## R1. Named provider identity

- **Verified**: `Provider.hash(into:)`/`==` operate solely on `_id` (Provider.swift:208-226);
  every public init sets `_id = UUID()` (7 provider types) → inline recreation leaks one
  element per instance.
- **Verified**: family providers use a separate `internal init(id: AnyHashable, …)`
  (stable per-arg id, Provider.swift:182) — unaffected by public-init changes.
- **Decision**: in the 7 public inits, derive `_id` from the explicit name when provided:
  `name.map { AnyHashable("\($0)#\(String(describing: T.self))") } ?? UUID()`. Same name +
  same value type ⇒ same identity (FR-001); distinct name or type ⇒ distinct (FR-002);
  unnamed keeps UUID (FR-003). `ProviderID` itself stays unchanged (AnyHashable(provider)
  now collapses for same-named instances via `_id` equality).
- **Alternatives considered**: name-keying inside `ProviderID` (rejected — would collapse
  family members that share a base name); type-scoped name registry (rejected — more state
  for the same outcome).

## R2. useReducer lost update

- **Verified**: `defer` resets `isDispatching` BEFORE the drain loop (useReducer.swift:121-129);
  a dispatch made from inside a queued reduce runs the direct path mid-drain and is overwritten
  by the next queued apply.
- **Decision**: keep the flag raised through the drain: defer resets only the flag; drain runs
  inside the dispatch body after the initial apply. Re-entrant dispatches append to the queue
  and drain within the same pass (bounded by action count; self-recursion remains user error
  as in React).

## R3. DebouncedAction race

- **Verified**: cancel and store are two separate `withValue` calls (DebouncedAction.swift:38-47);
  interleaved calls can cancel the OLD task after the other stored taskA → both fire.
- **Decision**: serialize the whole body with an `NSLock` around cancel+create+store (locks the
  two `LockIsolated` calls into one critical section; avoids parameter-pack capture pitfalls of
  creating the Task inside `withValue`).

## R4. flushChanges bound

- **Verified**: `repeat { … } while !pendingChanges.isEmpty` has no cap (ProviderContainer.swift:664-676);
  a listener that invalidates another provider creates dynamic ping-pong the static cycle
  detector (`_recomputePathSet`) does not cover.
- **Decision**: round counter with a fixed internal constant (100). Reaching it: `break` +
  DEBUG-only diagnostic print naming the remaining pending set (FR-006 — report, not trap:
  trapping would crash user apps on graphs that are merely wasteful).
- **Red-phase note**: at tip this scenario hangs forever, so a pre-fix failing test would
  block the suite; verified by construction + post-fix termination test instead (recorded
  as TDD exception).

## R5. FileAtomStorage race

- **Verified**: `cachedValue` mutated in `load()`/`save()`/`delete()` without the lock (the
  lock only guards `observers`; FileAtom.swift:65-117); class is `@unchecked Sendable`.
- **Decision**: guard the whole load/save/delete bodies with the existing `NSLock`.

## R6. SwiftDataNotifier reload

- **Verified**: `build()` returns `initialState` and never reads `SwiftDataStateRecord`
  (SwiftDataIntegration.swift:121-123); `updateAndPersist` writes under key
  `String(describing: T.self)`.
- **Decision**: store the same key on init; `build()` fetches the record and decodes,
  falling back to `initialState` on miss/decode failure. `AsyncNotifier` is `@MainActor`
  (AsyncNotifierProvider.swift:91-93) so the override can touch `ModelContext` safely.

## R7. Stream ordering

- **Verified**: `receiveValue`/`failure` spawn one `Task { @MainActor }` per Combine delivery
  (StreamProvider.swift:66-79 post-010); enqueue order from different threads is not FIFO.
- **Decision**: serialize state writes through a per-element write chain — each write task
  awaits the previous one before publishing. Terminal failure enqueues on the same chain so a
  trailing error cannot overtake the last value.

## R8. Notifier docs

- **Verified**: `Notifier` class doc claims "**Observable**: Conforms to the Observation
  protocol for SwiftUI integration" while `state`/`onUpdate` are `@ObservationIgnored`
  (NotifierProvider.swift:62-119).
- **Decision**: rewrite the doc block to describe the actual propagation path (provider box +
  `notifyDependents`; views observe through `@Watch`/providers, not direct `state` reads).

## R9. CI hardening

- **Verified**: lint job `continue-on-error: true` (ci.yml:30); no toolchain selection;
  no cache; no race job. `swiftlint` is NOT installed locally — cleanliness unverified.
- **Decision**: (a) drop `continue-on-error`; keep `--quiet` (fails on error-severity
  violations; `--strict` deferred until the base is proven warning-clean — recorded);
  (b) explicit Xcode selection step that resolves the declared-tools version from the runner's
  installed list and fails loudly when absent; (c) `actions/cache@v4` on `.build` keyed by
  `Package.resolved`; (d) separate `thread-sanitizer` job running `swift test --sanitize=thread`
  with `continue-on-error: true` + comment (mirrors lint's original non-blocking start; promote
  when clean).

## R10. Dead TCA dependency

- **Verified**: zero `import ComposableArchitecture` across Sources/Tests/Examples;
  declared once at top level + once on StateConcurrency (Package.swift:48, 94-101).
- **Decision**: remove both declarations; regenerate `Package.resolved` via resolve; commit
  the updated lockfile.

## R11. Reference docs sync

- **Verified**: `PUBLIC_API_INVENTORY.md` header-dated 2026-09-22, missing
  `SKInterceptorToken`/`removeInterceptor`/`AnalyticsConfig(historyCap:)`; no committed
  generator script. `UNIT_TEST_PLAN.md` lists 11 targets (13 actual), references a
  non-existent `StateKitMacroIntegrationTests`, still claims unmet exit criteria.
- **Decision**: append an "Added since 2026-09-22" section to the inventory (008/009/010/011
  APIs, date-stamped header note); correct the plan's target list and mark unmet exit criteria
  explicitly instead of asserting them.

## R12. Release tag

- **Decision**: after the full suite is green on the release commit: annotated tag `1.0.0`
  (no `v` prefix — matches README `from: "1.0.0"`), pushed to origin.

## R14. (Implement-time) Stream crash — new P1 found by the regression test

The stream-order regression test crashed the process (SIGTRAP) at tip:
`StreamProviderElement` formed `Task { @MainActor [weak self] … }` for Combine
deliveries arriving on a background thread; capturing the non-Sendable element
from a non-isolated context trips the Swift 6.2 runtime isolation check
(`swift_task_checkIsolatedSwift` → `dispatch_assert_queue_fail`, crash report
verified). Fix: `.receive(on: DispatchQueue.main)` before `sink` — the repo's
established idiom from spec 008 — which both removes the trap and makes state
writes FIFO in send order (FR-009 satisfied by delivery order).

## R15. (Implement-time) IssueReporting is a direct dependency, not TCA-only

Removing TCA broke the link of `StateConcurrencyTests`: `StateConcurrency` imports
`IssueReporting` directly (`AsyncStream.unimplemented`/`AsyncThrowingStream.unimplemented`
extensions) — previously a transitive dependency of TCA. Fix: declare
`pointfreeco/swift-issue-reporting` (2.1.1, same pin as before) as a direct dependency.
Net effect unchanged: TCA and its heavyweight graph are gone; only the actually-used
module is added back explicitly.

## R16. (Implement-time) Flush-bound test infeasibility + FileAtom deadlock

- The planned flush ping-pong test reproduced the PRE-EXISTING cycle detector fatal
  (`Circular dependency detected`, ProviderElement.swift:186) instead of a hang:
  listener-driven recompute ping-pong returns to an in-path provider id before the
  flush loop can spin. No public-surface regression test is feasible; the 100-round
  cap ships as depth-defence (T010 note in tasks.md).
- First FileAtom lock attempt deadlocked: `save()` held the lock and called
  `notify()`, which re-acquires the non-reentrant `NSLock`. Fixed by snapshotting
  observers under the lock and notifying outside it. The stress test caught it
  immediately (hang + stack sample) — test-first working as intended.

## R13. Test strategy

- New file `Tests/RiverpodsTests/P2HardeningRegressionTests.swift` (identity, flush bound,
  stream ordering) + additions to StateKit (reducer), StateConcurrency (debounce),
  StateKitPersistence (file race, notifier reload) test targets.
- Full-suite gate `swift test` unpiped; Examples build still green.
