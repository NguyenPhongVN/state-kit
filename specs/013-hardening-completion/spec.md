# Feature Specification: Hardening Completion (Architecture Doc, Lint Zero, Sleep Sweep, Sendable Audit)

**Feature Branch**: `013-hardening-completion`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "Close the four remaining intentionally-open items: (1) 3-engine architecture documentation (user decision: keep all three paradigms, document boundaries); (2) lint warnings from 965 toward zero with documented residue; (3) fixed-sleep sweep across 84 test sites with stability verification; (4) @unchecked Sendable audit across 38 sites with published justification table."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The architecture answers "which engine do I use?" (Priority: P1)

A developer (or AI agent) landing on the repository must find an authoritative
document explaining that the three state engines are intentional paradigms —
hooks (local React-style state), atoms (Recoil-style global graph), providers
(Riverpod-style DI graph) — with clear boundaries, when-to-use guidance, and the
dependency map, plus a pointer from the README. Today the duplication reads as
accident; after this story it reads as design.

**Why this priority**: the user-approved product decision is only real once it is
written down where contributors and agents actually look.

**Independent Test**: Can be fully tested by reading the architecture document and
README against the manifest — delivers an authoritative engine map.

**Acceptance Scenarios**:

1. **Given** the architecture document, **When** a reader asks "which engine for
   X?", **Then** each engine's scope, ownership, and non-goals are stated.
2. **Given** the README, **When** it is read top-down, **Then** it links the
   architecture document near the module overview.

---

### User Story 2 - The linter reports zero findings or deliberate exceptions (Priority: P1)

A maintainer running the linter must see a signal, not noise: every remaining
warning is either fixed or covered by a written, deliberate configuration choice
(the rulebook). Categories: trailing whitespace (143), identifier names (194),
line length (77), switch-case alignment (43, safely auto-fixable), orphaned doc
comments (28), stale disable commands (6), force casts/unwraps in production code
(60 — fixed where safe; test-target usage documented as deliberate), plus small
counts of file length, nesting, for-where, and type-name findings.

**Why this priority**: a zero-or-documented linter makes the CI gate meaningful;
noise trains people to ignore it.

**Independent Test**: Can be fully tested by running the linter — delivers a clean
or fully-accounted report.

**Acceptance Scenarios**:

1. **Given** the tree, **When** the linter runs, **Then** every warning is either
   gone or covered by a documented configuration decision (recorded in the
   rulebook and config comments).
2. **Given** the safe auto-fixable rule (case alignment), **When** the targeted
   fix runs, **Then** the full suite still passes.

---

### User Story 3 - Tests wait deterministically (Priority: P2)

A contributor running the suite must not see flakes from fixed sleeps, and a
cancelled test must not silently skip its waits. Of the 84 sleep sites: fixed
sleep followed by an assertion becomes bounded deadline polling; sleeps that
genuinely model elapsed time keep their semantics with a justification comment;
`try?`-swallowed cancellation becomes propagated cancellation where the wait is
part of the assertion path.

**Why this priority**: removes the largest documented flakiness risk without
touching production behavior.

**Independent Test**: Can be fully tested by running the suite three consecutive
times — delivers stable, deterministic waits.

**Acceptance Scenarios**:

1. **Given** a test that slept a fixed duration before asserting, **When** the
   wait is converted to deadline polling, **Then** the assertion is reached as
   soon as the condition holds and the suite passes.
2. **Given** the full suite, **When** it runs three times consecutively, **Then**
   all runs pass with zero failures.
3. **Given** remaining intentional sleeps, **When** the tree is reviewed, **Then**
   each carries a justification comment.

---

### User Story 4 - Every unchecked-Sendable type can defend itself (Priority: P2)

A reviewer auditing the concurrency surface must find, for each of the 38
`@unchecked Sendable` sites, either a fix (real isolation) or an explicit
justification comment stating the confinement story, published as an audit table
in the engineering docs. Genuinely unsafe sites found during the audit get fixed
with regression tests where behavior is observable.

**Why this priority**: the library sells concurrency safety; the audit converts
an implicit promise into a verified one.

**Independent Test**: Can be fully tested by cross-checking the audit table
against the code — delivers a published, complete audit.

**Acceptance Scenarios**:

1. **Given** the audit document, **When** each listed site is opened, **Then** the
   code carries a justification comment matching the table's story.
2. **Given** the audit, **When** unsafe sites are identified, **Then** they are
   fixed and covered by tests (or, if unobservable, by the audit's reasoning).

---

### Edge Cases

- Expected-source strings in macro tests must keep their exact bytes: whitespace
  fixes must not touch string contents (inline disables where needed).
- Safe autofix for case alignment must not alter codegen templates (excluded).
- Sleep conversions must not change what a test asserts — only how it waits.
- The audit may find types whose safety depends on actor confinement — the
  comment must name the actor.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An architecture document MUST state the three-engine decision,
  per-engine scope and non-goals, selection guidance, and the module dependency
  map; the README MUST link it.
- **FR-002**: The linter run MUST end with zero findings, or with each remaining
  rule covered by a documented deliberate configuration choice in the rulebook
  and config comments.
- **FR-003**: Whitespace and alignment fixes MUST NOT alter string-literal
  contents (macro expected sources) or codegen templates.
- **FR-004**: Production-path force casts/unwraps MUST be replaced with safe
  patterns where behavior is preserved; test-path usage MUST be documented as
  deliberate in the rulebook.
- **FR-005**: Fixed-sleep-then-assert test sites MUST become bounded deadline
  polling; cancellation MUST propagate where the wait is on the assertion path;
  intentional time-modeling sleeps MUST carry justification comments.
- **FR-006**: The full suite MUST pass three consecutive runs after the sleep
  sweep.
- **FR-007**: Every `@unchecked Sendable` site MUST carry a justification comment
  naming its confinement story, and the audit table MUST be published in the
  engineering docs with one row per site.
- **FR-008**: Sites found unsafe during the audit MUST be fixed with regression
  tests where behavior is observable.
- **FR-009**: No public API signature changes; no production behavior changes
  except fixes surfaced by the audit.

### Key Entities *(include if feature involves data)*

- **Engine map**: hooks / atoms / providers — scope, non-goals, dependency edges.
- **Residual-warning ledger**: rule → decision (fixed / config choice) with
  counts before and after.
- **Wait policy**: deadline polling helper, cancellation propagation, justified
  sleeps.
- **Sendable audit table**: file, type, isolation story, verdict (fixed /
  accepted).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Architecture document exists, README links it, and the manifest
  agrees with the module map.
- **SC-002**: Linter reports zero warnings or every residual rule is documented
  in the rulebook with before/after counts in the tasks log.
- **SC-003**: Three consecutive full-suite runs pass with zero failures.
- **SC-004**: The Sendable audit table covers all 38 sites; every site's code
  carries its justification comment.
- **SC-005**: Remaining fixed sleeps all carry justification comments; none sit
  on an assertion path without polling.

## Assumptions

- The linter's remaining findings after this feature are acceptable only when
  documented in the rulebook — silence is not a valid state.
- Sleep conversions target test determinism only; no production timing changes.
- The audit works top-down by module; fixes limited to confinement errors with
  observable behavior (no speculative redesign).
- Macro expected-source strings and codegen templates remain excluded from
  formatting rules (established in spec 012).
- Out of scope: engine consolidation (decided: keep all three, documented),
  production timing behavior, new features.
