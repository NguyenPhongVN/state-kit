# Feature Specification: Final Sweep — Remaining Review Findings

**Feature Branch**: `012-final-sweep`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Fix ALL remaining findings from the 2026-11-05 quality review not covered by specs 010/011: structured logging instead of print in production paths; TTL expire callback correctness pinned by test; GeolocationRollout resolver path pinned by test; stale doc sweep (SKStatus, SCGlobalActor, ThrottledAction); repo hygiene (tracked xcuserdata, gitignore consistency); coverage for StateKitTesting + StateKitSupport; CI iOS destination check; verify now-blocking lint is green locally."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Diagnostics flow through the system logger (Priority: P1)

A developer running an app that uses Riverpods notifier composition or the DevTools
observers must see diagnostics in the unified system log (filterable by subsystem,
respects system log levels) instead of raw console prints that bypass the system log
and pollute release stdout.

**Why this priority**: the only remaining production-path code-quality finding from the
review; everything else in this spec is tests/docs/repo hygiene.

**Independent Test**: Can be fully tested by triggering observer callbacks and asserting
the logging calls occur (log abstraction injectable) — delivers system-logger-based
diagnostics.

**Acceptance Scenarios**:

1. **Given** notifier composition diagnostics enabled, **When** state changes propagate,
   **Then** diagnostics go through the system logger, not `print`.
2. **Given** a DevTools observer with logging flags on, **When** lifecycle events fire,
   **Then** diagnostics go through the system logger gated by the same flags.
3. **Given** logging flags off, **When** events fire, **Then** nothing is emitted
   (existing gate behavior preserved).

---

### User Story 2 - Callback and rollout contracts are pinned (Priority: P1)

Two behaviors previously flagged as defects are already correct in code but have no
test pinning them: TTL expiry reports through exactly one callback (the expiry
callback, not the eviction callback), and geolocation rollout evaluates through the
host-supplied region resolver (previously documented as always-false). Without tests,
either could silently regress again.

**Why this priority**: pinning correct behavior is cheap insurance; both were on the
review's open list and cannot be closed without tests.

**Independent Test**: Can be fully tested by driving an expired TTL entry and a
geolocation rollout with a resolver — delivers pinned contracts.

**Acceptance Scenarios**:

1. **Given** a TTL cache with expiry and eviction callbacks, **When** an entry expires,
   **Then** only the expiry callback fires for it (eviction callbacks fire for capacity
   and manual removal as before).
2. **Given** a geolocation rollout with a resolver returning an allowed region, **When**
   enabled is queried, **Then** it returns true; a disallowed region returns false; a
   missing resolver returns false (documented default).

---

### User Story 3 - Documentation matches the code it documents (Priority: P2)

A developer reading the status-mirror, global-actor, or throttle documentation must not
be pointed at types that do not exist or shown examples that would not compile — the
last stale-doc findings from the review.

**Why this priority**: misleading docs actively cost debugging time; small, safe fixes.

**Independent Test**: Can be fully tested by checking documented symbols exist and
examples compile conceptually — delivers truthful docs.

**Acceptance Scenarios**:

1. **Given** the status phase file, **When** its documentation names types, **Then**
   those types exist in the codebase.
2. **Given** the global actor documentation, **When** its examples reference the actor,
   **Then** they use its current name.
3. **Given** the throttled action documentation, **When** its example calls the action,
   **Then** the call form matches the actual signature.

---

### User Story 4 - The repository tracks what it should (Priority: P2)

A contributor cloning the repo must not receive machine-specific debugger state, and
the ignore rules must agree with what is actually tracked (no tracked file that
gitignore claims to exclude).

**Why this priority**: hygiene with real confusion cost; one-command fixes.

**Independent Test**: Can be fully tested by listing tracked-but-ignored files —
delivers a consistent tree.

**Acceptance Scenarios**:

1. **Given** the repository, **When** listing files that are both tracked and matched
   by ignore rules, **Then** the list is empty (user debugger state removed from the
   index; the resolved-dependencies source of truth agrees with the ignore rules).

---

### User Story 5 - Every shipped module has at least a smoke test (Priority: P2)

The test-support module (the largest untested one) must have its own test target with
tests for its core deterministic-time and helper APIs, and the support hooks module
must grow beyond its current minimal coverage — closing the review's biggest coverage
gaps in a bounded way.

**Why this priority**: untested test-infrastructure is untrustworthy infrastructure;
bounded additions, not exhaustive sweeps.

**Independent Test**: Can be fully tested by running the new target and additions —
delivers covered support modules.

**Acceptance Scenarios**:

1. **Given** a new test target for the testing-support module, **When** the suite runs,
   **Then** the deterministic time source and integration helpers' core contracts pass.
2. **Given** the support hooks module, **When** its least-covered public hooks run under
   new tests, **Then** happy-path and teardown behavior is pinned.

---

### User Story 6 - CI checks a second platform and the lint gate is proven green (Priority: P2)

The package declares five platforms but CI only builds macOS; a build check against the
iOS destination catches platform-specific breakage. Separately, the lint job became
blocking in the previous feature — its first real run must be proven green (and any
bounded violations fixed) rather than discovered red after a push.

**Why this priority**: closes the last two CI findings from the review.

**Independent Test**: Can be fully tested by running the new build destination locally
and the linter on the tree — delivers multi-platform CI and a verified lint gate.

**Acceptance Scenarios**:

1. **Given** CI config, **When** it runs, **Then** an iOS-destination build check
   executes alongside the macOS suite.
2. **Given** the local tree, **When** the linter runs with the CI configuration,
   **Then** it reports zero errors (bounded violations fixed if found).

---

### Edge Cases

- System logger unavailable (older runtimes): logging falls back gracefully without
  crashing (platform availability guard).
- TTL entry expiring during a manual remove: one event, one callback, no double-report.
- Region resolver returning an unknown region code: false (not in allowed set).
- Log flags toggled mid-run: gate checked at emission time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Production-path diagnostics (notifier composition, DevTools observers)
  MUST emit through the unified system logger, gated by the existing flags; the public
  printing hook API is explicitly excluded (it is the feature).
- **FR-002**: TTL expiry MUST report through the expiry callback only; eviction
  callback remains reserved for capacity/manual removal. Pinned by regression test.
- **FR-003**: Geolocation rollout MUST evaluate via its resolver (true for allowed
  region, false otherwise, false without resolver). Pinned by regression test.
- **FR-004**: Documentation in the status/actor/throttle files MUST reference only
  existing symbols and show signature-accurate examples.
- **FR-005**: No tracked file may be matched by ignore rules; machine-specific debugger
  state MUST be untracked.
- **FR-006**: The test-support module MUST get a test target covering its
  deterministic-time and integration-helper core contracts; the support hooks module
  MUST gain tests for its least-covered public hooks (bounded: happy path + teardown
  per hook chosen).
- **FR-007**: CI MUST include an iOS-destination build check.
- **FR-008**: The linter MUST run clean locally under the CI configuration (zero
  errors) before this feature's commits land.
- **FR-009**: Out of scope, with reasons recorded: mechanical sweep of fixed sleeps in
  tests (flakiness risk outweighs benefit; principle documented), `@unchecked Sendable`
  audit (dedicated spec), three-engine consolidation (product decision).

### Key Entities *(include if feature involves data)*

- **System logger**: unified logging façade with subsystem/category per module.
- **TTL expiry event**: one expired entry → one expiry callback invocation.
- **Region resolver**: host-supplied closure returning region code or nil.
- **Ignored-but-tracked set**: files both tracked and matched by ignore rules (must be
  empty after this feature).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Full test suite passes with zero failures including new regression and
  coverage tests; `print` count in production paths drops to zero (public printing
  hook excluded).
- **SC-002**: TTL and geolocation contracts pinned by tests that fail if either
  regresses.
- **SC-003**: Documented-symbol spot check in the three swept files finds no
  non-existent references.
- **SC-004**: Tracked-and-ignored file list is empty.
- **SC-005**: New testing-support target passes; support module test count increases
  from 8 to at least 12.
- **SC-006**: CI includes the iOS build check; local lint run reports zero errors.

## Assumptions

- The unified system logger is available on all declared deployment targets (guarded
  where availability requires).
- The existing DevTools logging flags keep their semantics (checked at emission).
- `usePrint` stays a `print`-based public API — it is the documented feature, not a
  stray diagnostic.
- Bounded coverage additions: 1 new test target (4-6 tests) + 1 support test file
  (4-6 tests); exhaustive coverage is a separate effort.
- The iOS build check builds the library only (no iOS test run — simulator tests are a
  separate, slower job if ever needed).
