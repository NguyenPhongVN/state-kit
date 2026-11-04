# Feature Specification: P2 Hardening + CI/Docs Batch

**Feature Branch**: `011-p2-hardening-ci`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "P2 hardening + CI/docs batch from quality review 2026-11-05: stable identity for named providers; useReducer re-entrancy; DebouncedAction race; FileAtomStorage value race; SwiftDataNotifier never loads persisted state; flushChanges unbounded loop; Stream event ordering; honest Notifier docs; CI hardening (lint gate, Xcode pin, SPM cache, experimental TSan); remove dead TCA dependency; regenerate API inventory; sync unit test plan; tag 1.0.0 after green. Engine consolidation out of scope."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Named providers keep one identity (Priority: P1)

A developer creates a named provider inside a view body or computed property (re-created
every render). The engine must recognize same-named instances as the same logical
provider so the container serves one element instead of accumulating a new element per
recreation.

**Why this priority**: unbounded element growth from inline providers is a memory leak
with user-visible symptoms on every screen that builds providers inline; all other
correctness work rides on identity being sane.

**Independent Test**: Can be fully tested by creating two instances of a provider with
the same explicit name in one container and asserting a single shared state — delivers
leak-free inline usage.

**Acceptance Scenarios**:

1. **Given** a provider created twice with the same explicit name, **When** both are
   read in one container, **Then** they resolve to one element (state shared, compute
   runs once).
2. **Given** two providers with distinct names, **When** both are read, **Then** they
   stay distinct elements.
3. **Given** unnamed providers created repeatedly, **When** each is read, **Then**
   behavior is unchanged (each instance is its own identity — documented limitation).

---

### User Story 2 - Concurrent primitives keep their contracts under contention (Priority: P1)

Developers rely on three contracts that break under contention: a reducer dispatching
again from inside a queued action must not lose that update; two concurrent debounced
calls must schedule exactly one trailing operation; and a listener side-effect that
invalidates another provider must terminate (bounded propagation), never spin the main
thread forever.

**Why this priority**: these are silent data-loss and hang bugs in the library's own
concurrency primitives — the part the library advertises.

**Independent Test**: Can be fully tested by driving re-entrant dispatch, racing two
debounce calls, and a listener that ping-pongs a bounded number of invalidations —
delivers contract-correct primitives.

**Acceptance Scenarios**:

1. **Given** a reducer that dispatches action C while the queue is draining actions
   A→B, **When** the drain completes, **Then** C's effect is included in the final
   state (no lost update).
2. **Given** two debounced calls launched in the same tick, **When** the debounce
   interval elapses, **Then** the operation ran exactly once with the latest input.
3. **Given** an update cycle where listeners trigger invalidations back and forth,
   **When** the flush loop runs, **Then** it terminates after a bounded number of
   propagation rounds and reports (debug) that it hit the bound.

---

### User Story 3 - Persistence survives restarts and cross-thread use (Priority: P1)

Developers persisting atom values to files must not hit data races when the storage is
used from multiple threads, and SwiftData-backed state must reload its previously saved
value when the backing provider is re-created.

**Why this priority**: silent divergence between memory and storage is data loss from
the user's perspective; the file store race can corrupt reads.

**Independent Test**: Can be fully tested by saving then re-creating the notifier
(storage-only) and asserting the persisted value loads — plus concurrent save/load
stress — delivers restart-safe persistence.

**Acceptance Scenarios**:

1. **Given** a file-backed storage holding a saved value, **When** save and load are
   invoked concurrently from multiple threads, **Then** no crash and loads return a
   valid stored or default value.
2. **Given** state persisted through the SwiftData-backed notifier, **When** the
   notifier is re-created from the same storage, **Then** the initial state is the
   persisted value, not the seed default.
3. **Given** a failed SwiftData save, **When** update-and-persist runs, **Then** the
   in-memory state does not commit (existing contract, no regression).

---

### User Story 4 - Stream values arrive in order (Priority: P2)

A developer listening to a stream provider must observe values in the publisher's
emission order; a slow handler on an earlier value must never let a later value be
overwritten by the stale one.

**Why this priority**: ordering violations surface as flickering UI with stale data —
less common than the P1 leaks but confusing when hit.

**Independent Test**: Can be fully tested by emitting a fast sequence of values and
asserting the recorded state transitions follow emission order — delivers ordered
stream state.

**Acceptance Scenarios**:

1. **Given** a stream emitting values 1→2→3 rapidly, **When** the provider settles,
   **Then** the final state is 3 and recorded transitions are in emission order.

---

### User Story 5 - Documentation tells the truth about observability (Priority: P3)

A developer reading the notifier API docs must not be told a type is observable when
its state is excluded from observation tracking; the docs must describe how updates
actually propagate.

**Why this priority**: doc-only fix; removes a trap that costs debugging time.

**Independent Test**: Can be fully tested by reviewing the corrected docs against the
actual behavior — delivers truthful documentation.

**Acceptance Scenarios**:

1. **Given** the notifier type docs, **When** a developer reads them, **Then** no
   "Observable" claim contradicts the actual propagation path, and the supported update
   path is stated.

---

### User Story 6 - CI gates quality instead of observing it (Priority: P2)

A maintainer pushes code; lint violations fail CI (no silent override), the toolchain
matches the package's declared language version, dependency resolution is cached, and
an experimental thread-safety job reports races without blocking merges until clean.

**Why this priority**: the review found CI to be "a layer of paper" — gates that
observe but do not block. Fixing this makes every future fix trustworthy.

**Independent Test**: Can be fully tested by reading the pipeline definition and
pushing once — delivers enforced gates.

**Acceptance Scenarios**:

1. **Given** a lint violation, **When** CI runs, **Then** the job fails the build.
2. **Given** a push, **When** CI runs, **Then** the toolchain matches the declared
   language version (explicit selection, not runner default) and dependency caches
   are reused across runs.
3. **Given** the thread-safety job, **When** it runs, **Then** it executes the test
   suite under a race detector and is explicitly marked experimental (non-blocking)
   until proven clean.

---

### User Story 7 - Dependency footprint tells the truth (Priority: P2)

Consumers of the concurrency primitives module must not download a heavyweight
framework the module never imports.

**Why this priority**: pure win — smaller checkout, faster resolution, no behavioral
change.

**Independent Test**: Can be fully tested by resolving dependencies after removal and
running the suite — delivers a trimmed dependency graph.

**Acceptance Scenarios**:

1. **Given** the package manifest, **When** dependencies resolve, **Then** the
   heavyweight framework previously declared by the concurrency module is absent from
   the lockfile and the full suite passes unchanged.

---

### User Story 8 - Maps match the territory (Priority: P3)

A maintainer (or AI agent) consulting the public API inventory and unit test plan must
see the current state: APIs shipped through recent remediation features present, test
targets matching the manifest.

**Why this priority**: stale maps actively mislead agents and contributors.

**Independent Test**: Can be fully tested by cross-checking inventory entries and plan
target lists against the manifest and changelog — delivers accurate reference docs.

**Acceptance Scenarios**:

1. **Given** the API inventory, **When** cross-checked against recent changelog
   entries, **Then** the interceptor-removal APIs and analytics configuration APIs are
   present with current metadata.
2. **Given** the unit test plan, **When** compared with the package manifest, **Then**
   the target list matches (no missing or phantom targets) and unmet exit criteria are
   marked as such.

---

### User Story 9 - A real release exists (Priority: P2)

A consumer installing the package must be able to pin to a real tagged version,
fulfilling the documented installation guidance and stability policy.

**Why this priority**: closes the loop on SemVer promises; requires everything green.

**Independent Test**: Can be fully tested by listing repository tags after release —
delivers an installable version.

**Acceptance Scenarios**:

1. **Given** the full suite green after all stories, **When** the release is cut,
   **Then** a `1.0.0` tag exists on the release commit and matches the documented
   install guidance.

---

### Edge Cases

- Two named providers with the same name but different value types: identity must
  remain distinct (name alone must not collide across types).
- Reducer dispatching itself recursively (action → same action): bounded by the same
  drain contract; must not hang.
- Concurrent saves of different values to file storage: last-writer-wins, no
  interleaved corruption.
- Stream finishing immediately after emitting: final state must be the last emitted
  value, not an error.
- Cache restore on a dependency graph rebuilt after dependency removal: lockfile
  regeneration must keep resolution stable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Two provider instances carrying the same explicit name and value type
  MUST resolve to a single element within one container.
- **FR-002**: Provider instances with distinct names or distinct value types MUST
  remain distinct elements.
- **FR-003**: Unnamed provider instances MUST keep current per-instance identity
  (documented limitation, no behavior change).
- **FR-004**: Re-entrant dispatch during queue drain MUST be captured by the queue and
  applied once, with its effect visible in the final state.
- **FR-005**: Concurrent debounce invocations within one interval MUST schedule exactly
  one operation with the latest input.
- **FR-006**: Update propagation triggered by listeners MUST be bounded (a fixed
  maximum number of rounds per flush) and MUST report reaching the bound in debug
  builds.
- **FR-007**: File-backed atom storage MUST be safe for concurrent save/load from
  multiple threads (no torn reads/writes, no crash).
- **FR-008**: The SwiftData-backed notifier MUST load the previously persisted value
  when built, falling back to the seed default when nothing (valid) is stored.
- **FR-009**: Stream provider state writes MUST preserve publisher emission order.
- **FR-010**: Documentation of the notifier's observability MUST match actual
  propagation behavior.
- **FR-011**: CI MUST fail on lint violations (no permissive override), MUST select the
  toolchain matching the declared language version explicitly, MUST reuse dependency
  caches, and MUST include an explicitly non-blocking race-detector job.
- **FR-012**: The heavyweight unused framework dependency MUST be removed from the
  concurrency module with the full suite still green.
- **FR-013**: The public API inventory MUST include the APIs shipped in the last three
  remediation features; the unit test plan MUST match the actual manifest targets.
- **FR-014**: After all stories pass the full suite, a `1.0.0` version tag MUST be cut
  on the release commit.
- **FR-015**: Every code fix in this feature MUST include a regression test that fails
  without the fix; public API signatures MUST NOT change except where identity
  semantics require it (FR-001/FR-003 document the exact contract).

### Key Entities *(include if feature involves data)*

- **Provider identity**: the key a container uses to deduplicate providers — derived
  from explicit name + value type when named, per-instance otherwise.
- **Dispatch queue (reducer)**: the pending-action drain whose invariants guarantee
  captured re-entrancy.
- **Debounce schedule**: the single trailing operation per interval.
- **Propagation round**: one pass of the update flush; bounded by a maximum count.
- **Persisted record**: the stored file/SwiftData payload with its load fallback.
- **Dependency cache**: the CI-cached resolution products keyed by manifest digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Full test suite passes with zero failures including all new regression
  tests; suite runtime unchanged within noise.
- **SC-002**: Two same-named provider instances resolve to one element (verified by
  compute-count assertion); distinct names/types stay distinct.
- **SC-003**: Re-entrant dispatch, debounce contention, and bounded propagation tests
  all pass; a listener ping-pong scenario terminates in a fixed number of rounds.
- **SC-004**: Concurrent file-storage stress test (multi-thread save/load) completes
  without crashes; SwiftData re-create loads the persisted value.
- **SC-005**: Stream ordering test records transitions in emission order for a rapid
  burst.
- **SC-006**: CI config shows: lint job blocking, explicit toolchain selection, cache
  steps, race-detector job marked experimental.
- **SC-007**: Dependency lockfile no longer contains the removed framework; suite green.
- **SC-008**: API inventory contains the interceptor and analytics APIs from recent
  remediations; unit test plan matches the manifest target list exactly.
- **SC-009**: `1.0.0` tag exists at the release commit; `swift test` green at that commit.

## Assumptions

- Named-provider identity is an additive contract: providers WITHOUT a name keep
  per-instance identity (current behavior) — no silent global rename semantics.
- The propagation bound is a fixed internal constant (documented in code), generous
  enough that legitimate graphs never hit it; hitting it is a debug-level signal, not
  a crash.
- The race-detector job starts non-blocking (mirrors how lint started per user choice
  in spec 005) and is promoted to blocking once stable — recorded in the CI file.
- Removing the unused dependency is behavior-neutral: verified by zero imports in the
  module before removal.
- Release tag follows the repository's V1 versioning convention (`1.0.0`, matching the
  documented install guidance).
- Engine consolidation (three parallel state engines) remains OUT of scope — it needs a
  product decision, tracked separately.
