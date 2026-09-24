# Feature Specification: Health Bundle — CI, Honest APIs, Performance & Hygiene

**Feature Branch**: `health-bundle`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Close the quality debt from the feature review: (1) GitHub Actions CI running build/test/Examples/lint on every push and PR; (2) fix the DevTools replay() stub so the API is honest; (3) rewrite LRU cache internals from O(n) to O(1) with zero behavior change; (4) harden the flaky restartThrowingTask test; (5) add ProviderContainer.removeObserver pairing addObserver. No other behavior changes; full suite stays green."

## Clarifications

### Session 2026-09-25

- Q: Trong CI, SwiftLint nên chặn hay chỉ báo cáo? → A: Non-blocking trước — lint chạy và báo violation nhưng không fail CI trong giai đoạn đầu (existing force-unwrap/cast có justification hợp lệ); chuyển sang blocking sau khi sạch, ghi chú trong workflow.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every push is verified automatically (Priority: P1)

A contributor pushes a branch. Today nothing checks it until someone runs builds by hand — the review found the project has zero CI. After this story, pushes and pull requests trigger an automated check that builds the library, runs the full test suite, builds the Examples package, and runs the linter. Failures are visible on the commit/PR, so no regression can land silently.

**Why this priority**: Every other guarantee (conventions, zero-logic-change, test gates) depends on automation existing; the review ranked this the top gap.

**Independent Test**: Push a commit; observe the check run passes on a healthy tree, and observe a deliberate break is reported as failed.

**Acceptance Scenarios**:

1. **Given** a healthy tree, **When** any commit is pushed to `main` or a PR opened, **Then** the automated check runs build, tests, Examples build, and lint, and passes.
2. **Given** a commit that breaks compilation or a test, **When** pushed, **Then** the check fails and names the failing step.
3. **Given** the lint step, **When** violations exist, **Then** they are reported (non-blocking per Clarifications; flipped to blocking once the codebase is clean).

---

### User Story 2 - Replay is real or honest (Priority: P1)

A developer debugging state history clicks "replay". Today `replay()` only sleeps through the recorded timings and executes nothing — the API promises what it cannot do. After this story, replay re-executes recorded actions through an action handler supplied by the host (the history cannot know how to execute arbitrary actions by itself), or if no handler applies to an action, that entry is reported as skipped. The API never silently pretends to work.

**Why this priority**: Constitution V.4/V.5 — an API that lies is a defect.

**Independent Test**: Record history with known actions; replay with a handler that logs invocations; assert every applicable action was passed to the handler in order, with pacing respected; unknown actions are reported as skipped.

**Acceptance Scenarios**:

1. **Given** a history with three recorded actions and a working handler, **When** replay runs, **Then** the handler receives all three actions in recorded order.
2. **Given** an action the handler cannot map, **When** replay runs, **Then** the replay result reports it as skipped instead of pretending.
3. **Given** no handler is provided, **When** replay is attempted, **Then** it fails fast with a clear message (replay requires a handler) rather than sleeping silently.

---

### User Story 3 - LRU cache scales (Priority: P1)

An app caches thousands of entries. Today every `get`/`set` rebuilds the order array with O(n) removals, so large caches degrade linearly. After this story, the LRU cache keeps identical behavior (eviction order, callbacks, stats, aliases) but with O(1) bookkeeping via constant-time move-to-front and eviction from the back.

**Why this priority**: Performance debt in a shipped data structure; correctness is already pinned by existing tests.

**Independent Test**: The existing LRU test suite passes unchanged; a new stress test performs a large number of mixed operations and completes promptly (bounded work per op).

**Acceptance Scenarios**:

1. **Given** the current LRU tests, **When** run against the rewritten cache, **Then** all pass without modification.
2. **Given** a cache with a large capacity under mixed get/set churn, **Then** per-operation cost is constant (no linear scans), observable via the stress test completing in bounded time.

---

### User Story 4 - The suite is load-proof (Priority: P2)

A contributor runs the suite on a busy machine. Today one timing-sensitive atom test (`restartThrowingTask launches a new request`) failed once under load. After this story, that test (and any sibling using fixed single sleeps for async outcomes) asserts via bounded polling on state instead of a single timed wait, so machine load cannot flip it.

**Why this priority**: One flaky test poisons trust in every red run.

**Independent Test**: Run the full suite repeatedly (e.g., 5×) including under parallel build load — zero failures.

**Acceptance Scenarios**:

1. **Given** the hardened test, **When** the suite runs 5 consecutive times, **Then** zero failures occur.
2. **Given** the polling helper pattern introduced, **Then** sibling timing tests in the same file adopt it where applicable.

---

### User Story 5 - Observers can leave (Priority: P2)

A feature attaches a lifecycle observer to the shared container and later shuts down. Today `addObserver` exists but nothing can remove an observer, so long-running apps accumulate them. After this story, a matching removal API exists, is idempotent-safe, and the observer list no longer grows without bound.

**Why this priority**: Same leak class as bugs fixed in 001; small, safe closure of the audit gap.

**Independent Test**: Add an observer, remove it, trigger a provider event, assert the removed observer receives nothing; removing twice is harmless.

**Acceptance Scenarios**:

1. **Given** an added observer, **When** it is removed and a provider changes, **Then** it receives no callbacks.
2. **Given** the same observer removed twice, **Then** the second removal is a harmless no-op.

### Edge Cases

- What happens when replay's handler throws? (Replay stops at that entry and reports progress up to it — errors are surfaced, not swallowed.)
- What happens when two LRU entries tie in recency? (Impossible with unique keys and total ordering of operations — insertion order decides.)
- What happens when removeObserver is called with an observer attached to a different container? (No-op — observers are per-container.)
- What happens when CI runs on a tag/branch without Examples changes? (Examples build still runs — it is cheap and keeps the gate uniform.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-01**: Automated CI MUST run on pushes to `main` and on pull requests, executing: library build, full test suite, Examples build, and lint; results MUST be visible per commit/PR.
- **FR-02**: `replay` MUST require an action handler and MUST invoke it for every replayable recorded action in order, MUST report entries it could not replay (skipped), and MUST surface handler errors by stopping with a progress report.
- **FR-03**: LRU cache internals MUST be rewritten for O(1) `get`/`set`/eviction with behavior identical to today: same eviction order, same callbacks, same stats, same public API.
- **FR-04**: The flaky timing test MUST be rewritten to bounded-polling assertions; sibling fixed-sleep assertions in the same test file MUST adopt the same pattern where applicable.
- **FR-05**: `removeObserver` MUST exist, MUST prevent further callbacks to a removed observer, and MUST be safe to call repeatedly.
- **FR-06**: No other behavior changes; the public API grows only by `removeObserver` and the replay handler parameter/result.
- **FR-07**: All gates hold: root build green, full test suite green (assertions unchanged except the hardened ones), Examples build green.

### Key Entities *(include if feature involves data)*

- **CI workflow**: the automated check definition (build/test/examples/lint steps).
- **Replay report**: the outcome of a replay run — executed count, skipped list, and error state if a handler threw.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-01**: CI executes on every push/PR and passes on the healthy tree (verified by the run on the feature branch itself).
- **SC-02**: Replay executes 100% of applicable actions in order and reports skips; no silent no-op path remains.
- **SC-03**: Existing LRU tests pass unchanged; a stress test (≥10,000 mixed ops) completes in bounded time.
- **SC-04**: 5 consecutive full-suite runs (including under parallel-build load) show zero failures.
- **SC-05**: Removed observers receive zero callbacks; double-removal is a no-op.
- **SC-06**: Changelog documents the API growth (`removeObserver`, replay signature change is allowed within V1 development per project decision).

## Assumptions

- The replay signature change replaces the current no-argument stub within V1 (V1 is pre-stable; user decision from the conventions feature applies: straight changes allowed, changelog-documented).
- CI runs on macOS runners (the package requires Darwin frameworks for SwiftUI/Security); lint installs SwiftLint on the runner; lint failures are reported but non-blocking initially (policy confirmed during clarify).
- The LRU rewrite is internal only: public API, semantics, and complexity-visible behavior stay identical.
- The flaky-test fix targets the atom task tests file; other timing tests are swept opportunistically in the same file only.
