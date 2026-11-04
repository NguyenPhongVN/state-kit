# Feature Specification: P0/P1 Review Fixes (Riverpods Engine + CI Docs)

**Feature Branch**: `010-p0-p1-review-fixes`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Fix P0 + P1 bugs from quality review 2026-11-05: overrideWithProvider always crashes; KeepAliveLink.close() not idempotent; onResume double-fire; hierarchy auto-dispose/edge cleanup on wrong container; ProviderScope(overrides:) loses parent; container.listen() misses async completion events; docs.yml searches .build for doccarchive; two meaningless #expect(true) assertions. Each fix needs a regression test."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Swap provider implementation via override (Priority: P1)

A developer testing a feature builds a real provider container, then swaps one
provider's implementation for a mock via the documented override API
("Swap real API for mock API in tests"). Today the call always crashes; it must
complete without crashing and the mock value must be served.

**Why this priority**: a public API that crashes 100% of the time on its only
documented use case is a hard blocker; nothing else in the container can be
trusted until identity handling is correct.

**Independent Test**: Can be fully tested by creating a container, registering
a provider, calling the override API with a replacement provider, and reading
the provider — delivers a working override path (crash → correct value).

**Acceptance Scenarios**:

1. **Given** a container with a live provider element created by the library's
   standard providers, **When** the override API is invoked with a replacement
   provider, **Then** no crash occurs and reads return the replacement value.
2. **Given** a value-based override (existing path), **When** the override is
   applied, **Then** existing behavior is unchanged (no regression).

---

### User Story 2 - Listeners see every provider update exactly once (Priority: P1)

A developer listens to a provider through the container listener API. Two
today-broken paths must behave per contract: (a) listening with
fire-immediately to a provider that has never computed must deliver the resume
signal once, not twice; (b) listening to an async provider (future/stream) must
deliver the completion value/error when the async work finishes.

**Why this priority**: listener APIs are the integration surface for UI and
devtools; missed or duplicated lifecycle events produce stuck or double-firing
views, which users perceive as random.

**Independent Test**: Can be fully tested by registering a listener on a fresh
async provider, awaiting completion, and recording all events — delivers a
complete, non-duplicated event stream.

**Acceptance Scenarios**:

1. **Given** a provider that has never computed, **When** a listener subscribes
   with fire-immediately, **Then** the resume signal fires exactly once during
   the first compute.
2. **Given** a listener subscribed to an async provider before its work
   completes, **When** the async work finishes successfully, **Then** the
   listener receives the completion event with the final value.
3. **Given** a listener subscribed to an async provider, **When** the async
   work fails, **Then** the listener receives a failure event.
4. **Given** listeners on synchronous providers, **When** values change, **Then**
   existing event behavior is unchanged (no regression).

---

### User Story 3 - Container hierarchy disposes in the right container (Priority: P1)

A developer uses nested containers with a parent fallback (override scopes,
preview vs production containers). Removing a listener from a child container
must dispose the element in the container that owns it, and dependency edges
must be cleaned in the owning container so auto-dispose still works.

**Why this priority**: hierarchy is the documented pattern for scoping state;
dispose bookkeeping in the wrong dict leaves disposed elements reachable and
pins auto-dispose providers forever — a leak with visible symptoms.

**Independent Test**: Can be fully tested by creating a parent/child container
pair, listening from the child to a parent-owned auto-dispose provider,
removing the listener, and asserting the parent-owned element is released —
delivers correct cross-container disposal.

**Acceptance Scenarios**:

1. **Given** a child container listening to a parent-owned auto-dispose
   provider, **When** the child removes its listener, **Then** the element is
   removed from the owning (parent) container's registry.
2. **Given** a child container reading a parent-owned provider, **When** the
   child's dependency edges are rebuilt or cleared, **Then** the parent's
   back-edges no longer reference the child's elements.
3. **Given** a provider override scope created from a view, **When** providers
   not overridden are read inside the scope, **Then** they resolve against the
   parent (shared) container instead of being recreated from scratch.

---

### User Story 4 - Keep-alive close is repeatable (Priority: P2)

A developer holds a keep-alive link and closes it defensively (common in
deinit paths where double-close happens). The second close must be a no-op and
the provider must remain alive exactly as long as other open links require.

**Why this priority**: documented contract says repeat-close is safe; violating
it corrupts the keep-alive counter and can dispose providers out from under
live listeners. Real crash risk, but narrower exposure than US1-US3.

**Independent Test**: Can be fully tested by opening two keep-alive links,
closing one twice, and asserting the provider stays alive until the second
link closes — delivers contract-accurate keep-alive accounting.

**Acceptance Scenarios**:

1. **Given** two open keep-alive links, **When** one link's close is invoked
   twice, **Then** the provider remains alive (second close is a no-op).
2. **Given** all keep-alive links closed once each, **When** auto-dispose
   evaluation runs, **Then** the provider is disposed (no over-count).

---

### User Story 5 - Documentation site publishes (Priority: P2)

A maintainer pushes to main; the documentation publishing pipeline must
produce and upload the built documentation archive instead of failing because
it looks in a directory the build never writes to.

**Why this priority**: the docs pipeline is currently expected to fail on its
first real run; it blocks external visibility of docs but not library users.

**Independent Test**: Can be fully tested by triggering the pipeline and
asserting the archive is found and uploaded — delivers a working docs publish.

**Acceptance Scenarios**:

1. **Given** a push to main, **When** the docs pipeline builds documentation,
   **Then** the archive is located at a deterministic path and the upload step
   receives a non-empty artifact.

---

### User Story 6 - Test assertions that pin behavior (Priority: P3)

A maintainer runs the regression suites; two tests currently assert a constant
truth and therefore pin nothing. They must be rewritten to observe real
behavior (callback invocation records, returned token usability) so they can
fail when the behavior breaks.

**Why this priority**: no user-facing impact; removes false confidence only.

**Independent Test**: Can be fully tested by reading the rewritten assertions
and verifying they would fail if the observed behavior regressed — delivers
tests that guard real behavior.

**Acceptance Scenarios**:

1. **Given** the cache lifecycle test, **When** provider add/dispose callbacks
   are recorded, **Then** the test asserts on the recorded callbacks instead of
   a constant.
2. **Given** the devtools wiring test, **When** unsubscribe returns, **Then**
   the test verifies the token is usable (subsequent events no longer
   recorded) instead of asserting `true`.

---

### Edge Cases

- Override applied to a provider that already has listeners: override must
  re-resolve dependents rather than crash or serve stale values.
- Double-close of a keep-alive link concurrently with listener removal: no
  negative counters.
- Async provider completing synchronously before listener registration
  completes: listener still receives current state (fire-immediately path).
- Child container removed while still holding edges to parent elements: parent
  back-edges must not dangle.
- Docs pipeline on a clean machine (no cached build): must locate the archive
  without relying on a pre-existing build directory.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The provider override-by-provider API MUST successfully replace
  the element for any provider created by the library (all provider kinds),
  serving the replacement's value on subsequent reads.
- **FR-002**: The value-override path MUST keep its current behavior.
- **FR-003**: The first-compute listener path MUST emit the resume signal at
  most once per subscription.
- **FR-004**: Container listeners MUST receive update events when an async
  provider's work completes (success and failure).
- **FR-005**: Cross-container listener removal MUST dispose the element in the
  container that owns it, and dependency edge cleanup MUST operate on the
  owning container's registries.
- **FR-006**: View-created override scopes MUST consult a parent container for
  providers that are not overridden, preserving shared state across the scope.
- **FR-007**: Keep-alive link close MUST be idempotent: repeated close of the
  same link MUST have no further effect, and the keep-alive count MUST NOT go
  negative.
- **FR-008**: The documentation build pipeline MUST locate its produced archive
  deterministically (no dependence on default build directories).
- **FR-009**: Every fix in this feature MUST include at least one regression
  test that fails without the fix.
- **FR-010**: Existing public API signatures MUST NOT change (bug-behavior-only
  release; the deprecated duplicate listener API is out of scope).

### Key Entities *(include if feature involves data)*

- **Provider element registry**: per-container mapping of provider identity to
  its element; ownership determines where lifecycle bookkeeping happens.
- **Keep-alive link**: a handle representing one external claim on a provider's
  lifetime; close decrements its claim exactly once.
- **Container listener**: an external observer of provider updates; must
  observe completion of async resolution.
- **Dependency edge**: directional "provider depends on / depended-on by"
  record between containers' elements.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The full test suite passes with zero failures, including the new
  regression tests for all six fixes.
- **SC-002**: The documented override API runs without crashing in 100% of
  provider kinds covered by tests (previously 0%).
- **SC-003**: A listener registered before an async provider's first completion
  receives exactly one resume signal and exactly one completion event per
  lifecycle (verified by event recording).
- **SC-004**: Cross-container dispose bookkeeping leaves zero disposed elements
  reachable in owner registries and zero pinned auto-dispose providers after
  listener removal (verified by weak-reference regression tests).
- **SC-005**: Keep-alive accounting never produces a negative count under
  repeated close (verified by counter assertions).
- **SC-006**: The docs pipeline completes and uploads a non-empty artifact on
  its next real run (verified in CI).

## Assumptions

- Fixes preserve existing public API signatures; no deprecations are added in
  this batch.
- The documented contracts (keep-alive close idempotency, listener contract,
  override contract) are the source of truth — code is brought in line with
  docs, not the reverse.
- Event-recording test doubles already available in the test targets are
  sufficient for regression tests; no new test infrastructure is required.
- The docs pipeline runs on the repository's existing CI runner; no new
  infrastructure is introduced.
- Out of scope: P2 engine consolidation (three-engine question), CI hardening
  beyond docs.yml, dead-dependency removal, API inventory regeneration — each
  tracked as separate follow-ups.
