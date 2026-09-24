# Feature Specification: Coding Conventions Standardization

**Feature Branch**: `coding-conventions`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Refactor the project's coding conventions to be standard so any outside developer can read and contribute, following official Swift style (Swift API Design Guidelines) plus the constitution and reference-ecosystem idioms (React hooks / Recoil / Jotai / Riverpod). Current state: 220 source files, ~58% of public declarations documented, 120 files without MARK organization, duplicated utility file, dead code, no enforced style. Deliverables: canonical conventions rulebook, machine-enforceable configs, a mechanical convention pass over source files, and safe internal cleanups from the deferred audit list. Semver guard: no public API renames or signature changes; behavior must not change; full test suite stays green."

## Clarifications

### Session 2026-09-25

- Q: Convention mới enforce bằng công cụ nào? → A: SwiftLint + SwiftFormat — thêm `.swiftlint.yml` + `.swiftformat.json` (config-only, không thêm dependency vào package), rulebook ghi cách chạy.
- Q: Refactor sâu đến đâu về API? → A: **Rename thẳng** (không deprecation shim). Kèm câu 3: rename **tất cả code** chưa đạt chuẩn trên toàn codebase, nhưng **tuyệt đối không được thay đổi logic** (behavior/passes giữ nguyên).
- Q: Phạm vi rename? → A: Toàn bộ code. Rename thẳng là breaking change → bắt buộc **MAJOR bump 3.0.0 + migration guide** (đường hợp lệ duy nhất theo constitution V.5).
- Q: Quét doc comment + MARK skeleton phủ đến đâu? → A: **Cả 16 module** — 100% public symbols được docs, mọi file có MARK skeleton.

## Scope redefinition (supersedes the semver guard above)

The original semver guard ("no public API renames") is **superseded by the clarification session**: this feature is a **breaking conventions release (MAJOR 3.0.0)**. Public renames ARE in scope across the whole codebase under three absolute constraints: (1) zero logic changes — behavior identical, tests pass with only renamed references updated; (2) MAJOR version bump with migration guide documenting every rename; (3) all quality gates still hold.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The rulebook: one document that defines "how we write StateKit" (Priority: P1)

An outside developer opens the project for the first time and asks: how are files organized, when do I write a doc comment, how do I name things, which prefixes apply, how is concurrency annotated, when is a force-unwrap acceptable? Today the answers exist only implicitly (and partly in the constitution). After this story, a single canonical conventions document answers them all — aligned with official Swift style (Swift API Design Guidelines, API conventions) and cross-linked to the constitution and the ecosystem references (React/Recoil/Jotai/Riverpod) — covering: file layout and MARK structure, naming (types, functions, prefixes `use*`/`SK*`/unprefixed Riverpod layer), documentation requirements per symbol kind, comment style, concurrency annotations, error/force-conversion policy, and testing conventions. The document includes short before/after examples for every rule.

**Why this priority**: The rulebook is the product of this feature; everything else applies it.

**Independent Test**: Hand the document to a developer unfamiliar with the project; they can correctly predict the required style for a new file, a new public function, and a new actor-isolated method using only the document.

**Acceptance Scenarios**:

1. **Given** the rulebook, **When** a developer creates a new source file, **Then** the document prescribes its header style, MARK sections, and doc-comment requirements unambiguously.
2. **Given** any rule in the document, **Then** it carries a before/after code example and cites its origin (Swift API Design Guidelines or this project's constitution).
3. **Given** a rule that conflicts with the user's requested ecosystem idioms, **Then** the document resolves the conflict explicitly (Swift style wins for syntax; ecosystem idiom wins for naming concepts already established, e.g. `watch`/`read`).

---

### User Story 2 - The rules are machine-checked, not just written down (Priority: P1)

A contributor accidentally violates a naming or documentation rule. Today nothing catches it until a human review. After this story, the project ships lint/format configuration files that encode the conventions (naming rules, force-unwrap restrictions, doc-comment presence, line discipline, todo/timeouts in tests) so violations surface automatically when the tool runs, with a documented one-command setup for contributors.

**Why this priority**: A convention nobody enforces decays within weeks; enforcement is what makes the rulebook real for outsiders.

**Independent Test**: Introduce a deliberate violation (misnamed type, undocumented public symbol, force-unwrap outside policy); the lint run reports it with file/line.

**Acceptance Scenarios**:

1. **Given** the lint configuration, **When** a file contains a style violation covered by a rule, **Then** the lint output names the file, line, and rule.
2. **Given** a contributor clones the project, **Then** the conventions document explains in one section how to run the checks locally.

---

### User Story 3 - Any file can be navigated predictably (Priority: P1)

A developer jumps into an arbitrary source file. Today 120 of 220 files have no MARK organization and ~42% of public declarations lack doc comments, so navigation is guesswork. After this story, every source file follows the same skeleton (header doc, imports, MARK-ordered sections), and every public symbol in the modules covered by this pass carries a doc comment stating purpose and contract — with priority given to the code outsiders touch first (core runtime, hooks, atoms store, provider container/providers).

**Why this priority**: This is the "anyone can read it" requirement made concrete, where the cost is highest and the benefit most visible.

**Independent Test**: For a sample of files in covered modules: MARK skeleton present, public symbols documented; builds stay green.

**Acceptance Scenarios**:

1. **Given** any file in a covered module, **When** opened, **Then** its sections appear in the standard MARK order (header doc → imports → main type → extensions → helpers).
2. **Given** a public symbol in a covered module, **When** its documentation is opened, **Then** a doc comment describes purpose and any contract (throws, thread/isolation requirements, lifecycle).
3. **Given** the full automated test suite, **Then** it passes with zero behavior changes.

---

### User Story 4 - Safe internal cleanups from the deferred audit list (Priority: P2)

The previous audit deferred small internal hygiene items. This story closes the safe ones: the byte-identical duplicated `Function.swift` (consolidated into one home), dead code (`CanaryRollout.defaultHasher`), and documentation of remaining deferrals. Items requiring public renames (the `SC*` prefix) stay deferred with a documented plan for the next major version.

**Why this priority**: Demonstrates the rulebook being applied, cheaply and safely.

**Independent Test**: Diff shows the duplication removed with both modules building; dead code gone; tests green.

**Acceptance Scenarios**:

1. **Given** the two copies of `Function.swift`, **When** the cleanup ships, **Then** exactly one definition remains and both modules compile.
2. **Given** the dead hasher property, **When** removed, **Then** no references break and tests pass.

### Edge Cases

- What happens when a lint rule would require a public API change (e.g. renaming for naming rules)? (The rule is configured as warning/disabled for existing surface; conventions doc records the deferral per the semver guard.)
- What happens when auto-format would touch hundreds of lines at once? (Formatting changes are grouped and verified by build+tests; review readability beats maximal automation — the config stays conservative.)
- What happens when documenting a symbol reveals its behavior is wrong or confusing? (That is an audit finding: record it, don't silently "document" wrong behavior.)
- What happens when two style guides disagree (Swift vs ecosystem)? (Documented resolution order: Swift syntax rules first; ecosystem naming only where the project already established it.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-01**: A single canonical conventions document MUST exist, covering file layout, MARK structure, naming and prefixes, documentation requirements per symbol kind, comment style, concurrency annotations, force-conversion policy, testing conventions, and the tool setup guide — each rule with a before/after example and origin citation.
- **FR-02**: The conventions MUST align with official Swift style (Swift API Design Guidelines) for syntax and naming grammar; ecosystem idioms (React/Recoil/Jotai/Riverpod) apply only where the project already established them (hook verbs, read/watch, atom/provider vocabulary).
- **FR-03**: Machine-enforceable configuration MUST encode at minimum: force-unwrap/try restrictions consistent with the constitution, naming-case rules, todo discipline, and documented-symbol requirements for new code (grandfathering existing gaps is acceptable and recorded).
- **FR-04**: The mechanical pass MUST give every source file (all 16 modules) the standard MARK skeleton and MUST document every public symbol (purpose + contract: throws/isolation/lifecycle where applicable).
- **FR-05**: **Zero logic changes** — behavior must be identical after the refactor; test assertions change only in renamed references. **Public renames are in scope** (whole codebase, per Clarifications) and ship as breaking change **MAJOR 3.0.0** with a migration guide listing every renamed symbol; the audit's F9 deferral is thereby resolved in this feature.
- **FR-06**: The duplicated utility file MUST be consolidated to a single definition; dead code identified in the audit MUST be removed.
- **FR-07**: The coverage ledger records per-module completion; any symbol genuinely not finishable MUST be listed there with a reason (the target is 100% of all 16 modules).
- **FR-08**: All quality gates hold: root build green, full test suite green, Examples build green.
- **FR-09**: The version is bumped to MAJOR 3.0.0 in the changelog with a migration guide (`docs/release/MIGRATION_GUIDE.md`) enumerating every rename before/after.

### Key Entities *(include if feature involves data)*

- **Conventions rule**: one enforceable statement with example and origin (Swift guideline or project constitution).
- **Coverage ledger**: per-module record of convention-pass status (done / deferred with order) so outsiders see what is held to which standard.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-01**: The rulebook covers 100% of the rule categories in FR-01, each with an example and origin.
- **SC-02**: A deliberate convention violation is reported by the tooling with file/line/rule (verified by an intentional break-then-fix check).
- **SC-03**: Across all 16 modules, 100% of public symbols carry doc comments and files follow the MARK skeleton (verified by re-running the scan used in the review).
- **SC-04**: Exactly one definition of the previously duplicated utility remains; dead audit-listed code removed; zero test failures.
- **SC-05**: 0 logic changes: the full test suite passes with assertions unchanged except renamed references; renamed symbols are all listed in the migration guide; version bumped to 3.0.0.
- **SC-06**: Deferred items (if any symbol slips) are recorded in the coverage ledger with explicit next steps.

## Assumptions

- Per the clarification session, scope is ALL 16 modules for the doc/MARK sweep and whole-codebase renames with zero logic changes, shipped as MAJOR 3.0.0.
- Lint/format tooling is contributor-facing configuration only (config files + setup docs); it introduces no library dependencies and no build-time requirement for consumers.
- Doc comments follow Swift's documentation markup (/// with Parameter/Throws/Returns sections where applicable), matching the style already used by the best-documented files in the project.
- The conventions document lives with the engineering docs and is linked from the README so outsiders find it first.
- Renames target convention deviations only (e.g. the `SC*` prefix family); names already conforming to the rulebook stay.
