# Research: Clean Public API Overhaul

Feature: specs/002-clean-public-api · Date: 2026-09-25

## D1 — How `ProviderContainer.watch()` becomes honest (Clarified decision)

**Decision**: `watch()` registers reactivity — it increments the element's listener count and
returns the current state, exactly balancing the existing public `removeListener(for:)`.
`read()` remains a pure non-reactive read. The duplicate `addListener(for:)` is deprecated with a
replacement note pointing at `watch()`; `@Watch` internally migrates to `watch()`.

**Rationale**: user decision (clarify session 2026-09-25): fix the behavior, not the name — this
matches Riverpod idiom where watch = reactive, read = one-shot. It preserves every existing
signature (FR-06) while making the name true. The listener-leak risk for former watch-as-read
callers is real and is handled by an explicit changelog warning plus the deprecation-era docs.

**Alternatives considered**: deprecate `watch` toward `read` (rejected by user — renames away the
idiomatic Riverpod verb); delete `watch` outright (rejected — breaks API without deprecation).

## D2 — Caller-input force-conversions in `ProviderContainer.ensureElement`

**Decision**: the three override-path casts (override-created element, override value) become
checked conversions that fail with a precise `fatalError`-grade debug diagnostic naming the
provider and the mismatched type (release behavior: abort with message rather than undefined
state; production input reaching here is a programming error, but the message must name it).
The remaining container casts (`read/watch/refresh/listen/removeListener` element lookups) are
invariant-backed — `ensureElement(for:)` creates the element for exactly that provider/type — and
gain a written justification comment at each site (Principle V.3).

**Rationale**: overrides are built from caller-supplied values (test code); a type mismatch there
is plausible and today crashes with an unexplained cast message. Diagnosing precisely converts a
mystery crash into a pointed error. Element-lookup casts are guaranteed by construction and only
need the justification to survive audit.

**Alternatives considered**: throwing errors (changes signatures — breaks FR-06); silently
ignoring mismatched overrides (violates "no ignored input" harder than the cast does).

## D3 — Hook-slot force-casts (`Sources/StateKit/Use/*`, 20 sites)

**Decision**: keep the casts; add/verify the invariant justification comment at each site
("positional slot protocol: states[index] was created by this hook on first render; type is
guaranteed unless the caller violates stable hook order — a documented programming error").
P2 polish, folded into the audit bookkeeping.

**Rationale**: these are unreachable with correct hook usage; the stable-order contract is already
fatalError-guarded at the runtime level. Throwing here would poison every hook signature for a
case the docs already forbid.

## D4 — `preserved(by:)` overload family

**Decision** (Clarified): keep all 8 overloads; write per-overload docs that state the distinct
input shape and when to choose it. No deprecations in this family.

**Rationale**: user decision — the family maps distinct input shapes (Equatable, Hashable,
variadic, arrays, closures); consolidating would remove expressiveness, pure docs remove the
confusion at zero compatibility cost.

## D5 — Hooks vs `@Hook*` macros

**Decision**: document both paths as first-class with selection guidance (functions = full
control/verbatim hooks; macros = declarative, compile-time-checked view wiring). No
consolidation work in this feature (spec assumption).

**Rationale**: consolidating macro-generated and hand-written hooks is an architecture change
out of scope for a cleanliness pass; guidance docs deliver US3's intent for this axis.

## D6 — Audit method

**Decision**: module-by-module source review (public declaration scan + reading of each
declaration's docs/behavior), recorded in [audit.md](./audit.md) with stable per-module sections;
findings carry IDs (F1…), severity (P1/P2/P3), and disposition (fixed / justified / deferred).
The document's structure is the re-run method.

**Rationale**: satisfies US4's completeness and repeatability requirements without building
tooling; grep-based enumeration (`^public …`) plus reading is sufficient at ~160 declarations.
