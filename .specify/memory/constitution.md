<!--
Sync Impact Report
- Version change: (unratified template) → 1.0.0
- Modified principles: none (initial ratification — all placeholders filled)
- Added sections: I–VIII principles; Technology & Platform Constraints;
  Development Workflow & Quality Gates; Governance
- Removed sections: none (template comment scaffolding removed)
- Templates requiring updates:
  - .specify/templates/plan-template.md — ✅ no change needed (Constitution Check gate already present)
  - .specify/templates/spec-template.md — ✅ no change needed (mandatory sections compatible)
  - .specify/templates/tasks-template.md — ✅ no change needed (test-first task pattern compatible)
  - speckit command/skill files — ✅ generic, no agent-specific references
  - README.md / docs — ✅ no principle references to update
- Follow-up TODOs: none
-->

# StateKit Constitution

## Core Principles

### I. Modular Layering (Library-First)

StateKit is a set of independently consumable Swift libraries, not an app framework.
Every capability ships as an SPM product with a single clear purpose and an explicit
dependency direction that MUST NOT gain cycles:

`StateKitCore` → `StateKit` (hooks) → `StateKitAtoms` / `Riverpods` → feature modules
(`StateKitUI`, `StateKitCombine`, `StateKitPersistence`, `StateKitCache`,
`StateKitAnalytics`, `StateKitFeatureFlags`, `StateKitDevTools`, `StateConcurrency`,
`StateKitTesting`) → `StateKitMacros` (facade) / `StateKitMacrosPlugin` (compiler side).

- Feature modules MUST depend on the core they extend and MUST NOT depend on each other.
- Consumers add only the products they use; no module may force-include another.
- Shared internals duplicated across modules (e.g. copied utility files) MUST be
  consolidated into `StateKitCore` rather than copy-pasted.

**Rationale**: the library's value proposition is pick-what-you-need; cross-module
coupling or duplication silently destroys it.

### II. React-Hooks Parity (Local State)

Local state lives in `StateKit` hooks (`useState`, `useEffect`, `useReducer`,
`useMemo`, `useBinding`, …) and MUST preserve the contract that makes React hooks
predictable:

- Hooks MUST be called in a stable order across renders — never inside conditionals
  or loops. Hook identity is positional (`nextIndex()`); the runtime MUST fail loudly
  (`fatalError` with a clear message) when a hook runs outside `StateRuntime`.
- The first render initializes slot state; later renders MUST ignore initial values.
- Effects (`useEffect`, `useLayoutEffect`) MUST run after the render pass completes
  (layout effects before post-render effects), MUST clean up before re-running, and
  MUST clean up on scope teardown. Dependency comparison MUST treat "no dependency"
  as run-once.
- `useOnChange` MUST NOT fire on the first render unless explicitly requested
  (`initial: true`).

**Rationale**: users arrive with React mental models; any deviation from hook
semantics becomes a subtle data-loss or infinite-loop bug.

### III. Unidirectional Data Flow with Loud Cycles

State changes propagate only along declared dependency edges — atom graph edges in
`StateKitAtoms`, watcher/dependent links in `Riverpods`. There are no hidden side
channels.

- Writes MUST invalidate dependents, which recompute in topological order; batching
  MUST coalesce propagation so a derived value recomputes at most once per batch.
- Derived state MUST be derived, never duplicated: a computed value MUST have exactly
  one upstream definition, and caches MUST be evictable (`evictWhenUnused`,
  `evict(_:)-style APIs`).
- Dependency cycles MUST be detected and surfaced as an assertion/failure with the
  cycle path — never an infinite loop or a silently frozen value.
- Eviction MUST only remove state that can be rebuilt on demand; live subscribers
  and dependents keep atoms/providers alive.

**Rationale**: silent staleness and silent loops are the two failure modes that
make state libraries untrustworthy; the library must make both impossible or loud.

### IV. Provider & Atom Lifecycle Fidelity (Global State)

Global state follows the established semantics of its inspiration models —
Recoil/Jotai atoms and Riverpod providers — and MUST NOT approximate them:

- Providers/atoms declare their lifecycle: `autoDispose` + `cacheTime`,
  `keepAlive()` links, and family parameters keyed without collisions.
- Listener counts are refcounted; increments and decrements MUST be balanced and
  idempotence-safe (double-close of a subscription MUST NOT double-decrement).
- Delayed disposal windows MUST re-check liveness before disposing.
- Overrides (test containers) MUST take precedence over parent lookup and MUST NOT
  leak between containers.
- Async providers (`FutureProvider`, `StreamProvider`, `AsyncNotifierProvider`)
  MUST cancel in-flight work on invalidation/disposal and MUST NOT deliver results
  after cancellation.

**Rationale**: half-faithful lifecycle semantics are worse than none — callers
build on `autoDispose`/`keepAlive` guarantees, and money-data (auth, sessions)
leaks when disposal windows are wrong.

### V. Clean Public API (NON-NEGOTIABLE)

Public API is the product. Every public symbol MUST satisfy all of the following:

1. **Swift API Design Guidelines naming** — clarity at the call site, omitted
   needless words, `use*` prefix for hooks, `SK*` prefix for atom-layer machinery,
   unprefixed Riverpod-layer types.
2. **No ignored parameters.** A parameter that appears to do something MUST do it
   (reference incident: `KeychainBatch.deleteAll(matching:)` silently ignored its
   pattern and wiped the keychain).
3. **No force-unwraps or force-casts at API boundaries** where caller input can
   reach them; internal invariants may use them only with a written justification
   comment.
4. **Behavior-level completeness**: every public API has docs stating what it does,
   what it throws, and its lifecycle/thread requirements; doc examples compile.
5. **Versioned evolution**: breaking changes require a deprecation period and a
   changelog entry, or a MAJOR version bump. Behavior fixes that change observable
   outcomes (hash bucketing, accessibility values) MUST be changelog-documented.
6. **No API counterfeits**: a type claiming Sendable or a protocol conformance MUST
   actually uphold it (`@unchecked Sendable` requires a written invariant note).

Violations found in review are defects, not style preferences, and are fixed
through the standard speckit flow.

**Rationale**: every critical bug found in the 2026-09 review was an API-contract
violation visible at the public surface — ignored parameters, invalid enum values,
immortal objects. Clean API is correctness, not cosmetics.

### VI. Concurrency Discipline

- State stores are `@MainActor`-confined by default; a non-isolated mutable store
  requires explicit justification in the type's documentation.
- Long-lived background work (cleanup loops, auto-flush, timers) MUST capture its
  owner weakly, MUST exit when the owner is released, and MUST NOT keep the owner
  alive (reference incident: TTL caches and `EventTracker` leaked forever).
- Cancellation MUST propagate: child work checks `Task.isCancelled` after awaits,
  and sleep/interval derivations MUST remain valid for the smallest supported
  non-zero duration (no busy-looping).
- `deinit`-side cleanup that jumps actors (e.g. `Task { @MainActor … }`) MUST be
  safe against use-after-release by design (weak references, idempotent teardown).

**Rationale**: a state library runs inside every screen of a host app; one leaked
timer per screen is an app-wide energy and memory bug.

### VII. Test-First Regression Coverage

- Every bug fix MUST ship with a test that fails before the fix and passes after
  (red → green), committed in the same change.
- Every shipped module has a test target mirroring the module name; a module
  without tests is a defect (reference incident: `StateKitPersistence` shipped
  with no test target).
- Behavior-level success criteria in specs MUST be verifiable by automated tests
  on the host; anything not host-verifiable is stated as an assumption, not a
  criterion.
- Leak fixes MUST be verified by deallocation assertions (weak-reference tests),
  not just by behavior tests.

**Rationale**: the review process caught what the suite did not; the suite must
learn from every finding, or findings will recur.

### VIII. Documentation Matches Reality

- Any stated count, claim, or guarantee in `README.md`/`docs/` MUST equal reality
  at merge time (reference incident: README claimed 47 macros, actual 48).
- `Examples/` MUST compile against the current public API.
- Every accepted behavior break MUST land in `docs/release/CHANGELOG.md` in the
  same change, with migration notes in `docs/release/MIGRATION_GUIDE.md` when the
  break touches persisted data or stable user identifiers.

**Rationale**: adopters evaluate and trust the library through its docs; one
wrong claim poisons all of them.

## Technology & Platform Constraints

- Language: Swift 6.2 (strict concurrency ready), `swift-tools-version: 6.2`.
- Platforms: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+.
- External dependencies require written justification in the spec that introduces
  them; the default is zero new dependencies. Allowed today: `swift-syntax`
  (macros only), `swift-composable-architecture` (bridging in `StateConcurrency`).
- State stores are MainActor-confined; background-capable adapters must isolate at
  their own boundary before touching store state.

## Development Workflow & Quality Gates

- Every development task runs the speckit flow end-to-end:
  specify → clarify → plan → tasks → analyze → implement, without pausing between
  stages unless a decision genuinely requires the human.
- `speckit-constitution` runs only when principles need creating or amending —
  amendments follow Governance below.
- Quality gates (all MUST pass before completion is reported):
  1. `swift build` succeeds.
  2. `swift test` passes with zero failures and zero unexpected skips.
  3. `Examples/` builds when public API or examples changed.
  4. Docs parity: stated counts/claims verified (greppable where possible).
- Tests for behavior changes are written first and observed to fail (red) before
  implementation (green).

## Governance

- This constitution supersedes ad-hoc practices; conflicts resolve in favor of the
  constitution until formally amended.
- Amendments: propose in a speckit task, update this file with a Sync Impact
  Report, bump the version (MAJOR: principle removal/redefinition; MINOR: new
  principle or material expansion; PATCH: wording), and note the change in the
  changelog.
- Compliance is checked in `/speckit-analyze` (constitution gate) and during
  review of every change touching public API.
- Principle violations found late are still defects: fix through the standard
  flow, do not dilute the principle.

**Version**: 1.0.0 | **Ratified**: 2026-09-25 | **Last Amended**: 2026-09-25
