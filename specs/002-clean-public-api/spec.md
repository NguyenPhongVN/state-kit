# Feature Specification: Clean Public API Overhaul

**Feature Branch**: `clean-public-api`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Improve public API cleanliness across StateKit modules following the newly ratified constitution (v1.0.0, especially Principle V "Clean Public API"). The library exposes ~160 public declarations. Goals: (1) audit every public declaration against the constitution rules — naming, no ignored/misleading parameters, no force-casts reachable from public paths, no semantic counterfeits, no duplicate ways to do the same thing; (2) fix violations in priority order with semver discipline — deprecate before removal, changelog entries, examples updated; (3) keep React hooks / atom / riverpod flows idiomatic. Scope guard: this is not a rewrite — behavior stays, signatures evolve compatibly unless the constitution marks a counterfeit API as a defect."

## Clarifications

### Session 2026-09-25

- Q: ProviderContainer.watch() hiện giống hệt read() (không đăng ký reactivity) — sửa thế nào? → A: Làm watch() reactive thật — watch() đăng ký listener (đúng tên, idiom Riverpod: read = không reactive, watch = reactive); read() giữ nguyên thuần đọc. Hệ quả: addListener(for:) trở thành bản trùng lặp của watch() → deprecated trỏ sang watch(); caller cũ gọi watch() như read() cần biết họ giờ đăng ký listener (phải cân bằng bằng removeListener) — ghi rõ trong changelog.
- Q: UpdateStrategy có 8 overload preserved(by:) — gộp đến mức nào? → A: Giữ nguyên cả 8 overload, mỗi overload được docs phân biệt rõ trường hợp dùng (không deprecate overload nào); mục tiêu "một cách idiomatic mỗi intent" áp dụng cho các dạng trùng lặp khác (ví dụ addListener vs watch), không áp dụng cho bộ overload này.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every public API means what it says (Priority: P1)

A developer reading the library's reference finds that a method named "watch" behaves identically to "read" and registers no reactivity — the name promises one thing, the behavior delivers another. Today at least one such semantic counterfeit exists in the provider container, and any API whose name overpromises forces developers to read source code to learn the truth. After this story, every public declaration's observable behavior matches its name and documentation; anything that cannot honestly keep its name is either renamed (with a deprecation shim) or documented as a raw escape hatch with a non-misleading name.

**Why this priority**: Trust is the product. A state library whose names lie produces production bugs that no test in the host app can catch.

**Independent Test**: For each flagged counterfeit, a test (or documented compile-time demonstration) shows the name's promise holds: e.g. a reading API returns the current value without side effects; a watching API is the only path that registers for updates.

**Acceptance Scenarios**:

1. **Given** the provider container's value-reading entry points, **When** a developer calls the non-reactive read, **Then** no listener is registered and no lifecycle side effect occurs.
2. **Given** a developer who wants reactive updates, **When** they consult the docs, **Then** exactly one documented path establishes reactivity, and its name says so.
3. **Given** any public declaration flagged by the audit as a counterfeit, **When** the fix ships, **Then** the old name either behaves as named, or carries a deprecation note pointing to the honest replacement.

---

### User Story 2 - Bad input fails loudly, never crashes the host (Priority: P1)

A test writer passes a value override whose type does not match the provider's state, or configures a family with a colliding key. Today several public paths respond with an unrecoverable crash from a hidden type cast. After this story, every public path reachable with caller-supplied input either (a) validates and reports a precise, catchable error, or (b) documents an invariant-backed force-conversion with a written justification. Host apps must never crash in production from library input the compiler cannot check.

**Why this priority**: A crash in the host app is the worst failure class a library can cause; these paths are reachable from ordinary test and app code today.

**Independent Test**: Feed mismatched input through each public entry point that accepts it; observe a thrown error or a debug-time assertion with a precise message — never a runtime crash in release builds.

**Acceptance Scenarios**:

1. **Given** an override whose stored value type does not match the provider state type, **When** the element is created in a container, **Then** the failure is a precise error or debug assertion naming the mismatch — not a production crash.
2. **Given** any force-conversion that remains in the code, **When** a reviewer reads it, **Then** a justification comment ties it to an invariant the compiler enforces at the call site.
3. **Given** the audit's full list of unsafe conversions on public paths, **When** the story ships, **Then** every item is either fixed or justified, with zero unjustified entries remaining.

---

### User Story 3 - One idiomatic way per intent (Priority: P2)

A developer choosing between several near-identical entry points — or between hook functions and their macro counterparts — cannot tell which path is recommended; some entries duplicate each other's meaning exactly (a method that registers reactivity coexisting with a second name for the identical operation). After this story, each common intent has one clearly documented canonical path; exact duplicates are deprecated with messages pointing to the canonical form; variants that serve genuinely distinct input shapes stay and gain per-variant docs stating when each applies (per Clarifications: the full dependency-specification overload family is kept and documented, not consolidated). The API reads idiomatically against its reference ecosystems — hooks read like React hooks, atoms read like Recoil/Jotai, providers read like Riverpod.

**Why this priority**: Duplication dilutes documentation, examples, and onboarding, but does not produce wrong behavior.

**Independent Test**: For each intent (specify hook dependencies, declare global atom state, watch a provider), the docs name one canonical API; deprecated duplicates carry deprecation notes; the examples package compiles using only canonical paths.

**Acceptance Scenarios**:

1. **Given** the dependency-specification API, **When** a developer reads its docs, **Then** every overload states its distinct use case (kept per Clarifications — documentation, not deprecation).
2. **Given** an intent covered by both a function and a macro path, **When** the developer reads the guide, **Then** the docs state when each is appropriate rather than leaving both unexplained.
3. **Given** the examples package, **When** it builds, **Then** it uses canonical paths (no deprecated call sites remain in examples).

---

### User Story 4 - The audit is complete, ranked, and repeatable (Priority: P2)

A maintainer needs more than one-shot fixes: they need the full ranked inventory of every public declaration assessed against the constitution rules, so future API work starts from the same list. After this story, the audit exists as a versioned document in the feature directory, each finding carries a severity and a disposition (fixed here / justified / deferred with a tracking note), and re-running the audit method reproduces the document's structure.

**Why this priority**: Without the complete inventory, "clean API" decays back to spot fixes; with it, cleanliness becomes an auditable state.

**Independent Test**: Pick any public declaration at random; the audit document contains an assessment for it (clean, or a finding with a disposition).

**Acceptance Scenarios**:

1. **Given** the audit document, **When** any public declaration is checked, **Then** it appears with a verdict or is covered by a module-level "clean" entry.
2. **Given** every finding, **When** its disposition is read, **Then** it is one of: fixed in this feature, justified with a written rationale, or deferred with a priority for a later feature.
3. **Given** all P1 findings, **When** this feature ships, **Then** none remain in deferred state.

### Edge Cases

- What happens when a rename would break a documented example in docs/? (Examples and docs update in the same change; the deprecation shim keeps old call sites compiling.)
- What happens when two rules conflict — e.g. an honest name would break ecosystem idiom? (Constitution Principle V wins; the ecosystem-idiom reading is kept via documentation, not by keeping a misleading name.)
- What happens when a deprecated API has zero usage in the repo and no external adopters are known? (It may be removed directly with a changelog entry — deprecation period exists for adopters, not for dead code.)
- What happens when an audit finding is itself ambiguous (two defensible readings)? (Record both readings in the audit; resolve via clarify session rather than guessing silently.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-01**: A complete audit document MUST cover every public declaration in every shipped module, with a verdict (clean / finding) and, for findings, a severity and disposition (fixed / justified / deferred).
- **FR-02**: All P1 findings (counterfeit names, crash-reachable paths, ignored parameters, contract lies) MUST be fixed or covered by a deprecation shim in this feature; none may be deferred.
- **FR-03**: Public paths that can receive caller-supplied input MUST fail with a precise error or debug assertion instead of crashing in release builds; any remaining force-conversion MUST carry a written invariant justification.
- **FR-04**: Non-reactive accessors MUST be pure reads (no listener registration, no lifecycle side effects); reactive registration is owned by the accessor named for it (watch) — the former addListener duplicate is deprecated pointing at watch, and watch's new reactive behavior (with the caller's obligation to balance removeListener) is changelog-documented.
- **FR-05**: Redundant API variants (same intent, same input shape) MUST be deprecated with messages naming the canonical replacement; variants serving genuinely distinct input shapes (e.g. the full preserved(by:) overload family) are retained, each with docs that state its distinct use case — per Clarifications, no overload in that family is deprecated.
- **FR-06**: All renames/replacements MUST ship as deprecations that keep existing call sites compiling (no signature removal in this feature), except APIs with zero usage inside the repo which MAY be removed directly with a changelog entry.
- **FR-07**: The examples package and doc examples MUST use canonical paths only after this feature ships.
- **FR-08**: Every change in this feature MUST land with a changelog entry; behavior-affecting entries follow the constitution's documentation rules.
- **FR-09**: The full automated test suite MUST pass with no regressions after every story; new tests MUST be written first (red → green) for each behavior change.
- **FR-10**: Module naming conventions MUST follow the constitution: `use*` hooks, `SK*` atom machinery, unprefixed Riverpod layer; deviations found by the audit are findings with dispositions.

### Key Entities *(include if feature involves data)*

- **Public declaration**: any symbol exported by a shipped module; the unit of audit. Attributes: module, name, kind, verdict, finding severity, disposition.
- **Audit document**: the ranked, versioned inventory of assessments; lives with the feature's artifacts and is reproducible by its stated method.
- **Deprecation shim**: a keeping-compiling path from an old name to a canonical replacement, carrying a replacement-pointing note.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-01**: 100% of public declarations across all shipped modules have an audit verdict; the count of assessed declarations is stated in the audit document.
- **SC-02**: 0 unjustified force-conversions remain on caller-input-reachable public paths (audit lists each with justification or fix).
- **SC-03**: 0 semantic counterfeits remain: for each flagged name, tests or compile-time demonstrations confirm name-behavior alignment.
- **SC-04**: 100% of deprecated variants carry replacement-pointing deprecation notes; 0 deprecated call sites remain in `Examples/` and doc examples.
- **SC-05**: All P1 findings are closed in this feature (fixed or shimmed); deferred findings are exclusively P2/P3 with recorded priorities.
- **SC-06**: Full test suite passes with zero regressions; every behavior change has a red→green test pair.

## Assumptions

- "Public declaration" means symbols exported by the package's products (libs under Sources/, excluding test targets and the macro plugin's internals).
- The audit method is source-level review per module against constitution Principles II–V and X-style naming rules, documented per module with a stable structure so it can be re-run.
- This feature does NOT redesign macro-generated API surfaces (hook functions vs `@Hook*` macros are both first-class; the deliverable is documentation of when each is appropriate, not consolidation).
- Deprecation annotations use the platform's availability-based deprecation with replacement pointers; no runtime behavior change for deprecated paths in this feature.
- The provider container's internal element machinery (type-erased element handling) may keep force-conversions where the generic call sites guarantee types; each such site needs the justification comment to survive the audit (reference: User Story 2).
- Family key collision handling, if flagged, is treated as a P2 finding (robustness) unless it can crash, in which case P1 applies.
