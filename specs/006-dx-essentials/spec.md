# Feature Specification: DX Essentials — DocC, focusAtom, fileAtom, ErrorBoundary

**Feature Branch**: `dx-essentials`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "DX essentials from the review: (1) DocC documentation publishing via GitHub Actions from the existing 100% doc comments, with NO new package dependency (CI-side action only) plus a documented local command; (2) focusAtom — a lens over a state atom: read/write a single field through a key path, writes propagate back to the base atom and its dependents (Jotai focusAtom idiom); (3) fileAtom — JSON-file-backed atom persistence mirroring userDefaultsAtom for values exceeding UserDefaults limits, same honest load/save semantics; (4) ErrorBoundary SwiftUI view wrapping a throwing content closure with a fallback view and optional onError hook, documented to catch synchronous errors from the content closure. All new APIs follow the coding conventions rulebook, ship with tests, and keep all gates green."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Public documentation site (Priority: P1)

An outsider evaluating the library clicks a docs link and lands on generated API documentation for every module (the project's 1,186 public symbols are already fully documented). Today those doc comments are only visible in source. After this story, documentation builds automatically on main and publishes to GitHub Pages, with zero new package dependencies (the publishing runs CI-side), and a contributor can build the same docs locally with one documented command.

**Why this priority**: Docs visibility is the biggest remaining outsider gap; all the content already exists.

**Independent Test**: The docs workflow runs on push and produces a browsable archive; the local command documented in the rulebook produces the same locally.

**Acceptance Scenarios**:

1. **Given** a push to `main`, **When** the docs workflow completes, **Then** the generated documentation is published and browsable at the Pages URL.
2. **Given** a contributor follows the rulebook's local command, **Then** they get the same documentation without installing anything beyond Xcode.

---

### User Story 2 - Focus atom: read/write one field (Priority: P1)

A developer stores a user profile struct in a state atom and wants a view that edits only the email field. Today they must read the whole struct, copy-modify it, and write it back by hand. After this story, a focus atom derived by key path exposes a single field as first-class state: reading it tracks the base atom, and writing it produces an updated base value that flows back into the base atom — so every other watcher of the base (and its dependents) updates. Reads stay live, writes stay single-sourced, and no struct copies appear in user code.

**Why this priority**: Removes the most common boilerplate in atom-heavy apps and completes the Jotai idiom set.

**Independent Test**: Write through the focus; assert the base atom changed AND other watchers of the base saw the update; read through the focus reflects external base changes.

**Acceptance Scenarios**:

1. **Given** a profile atom and a focus on `\.email`, **When** the focus is written, **Then** the base atom holds the new full profile with only the email changed.
2. **Given** another view watching the base atom, **When** the focus is written, **Then** that view re-renders with the updated profile.
3. **Given** the base atom changes externally (e.g. a settings screen rewrites the profile), **When** the focus is read, **Then** it reflects the new field value.

---

### User Story 3 - File-backed atom persistence (Priority: P2)

A developer persists state larger than UserDefaults' practical size limit (media metadata, caches of decoded models). Today only the keychain and UserDefaults patterns exist. After this story, a file-backed atom stores values as JSON in a named file: loads read the file (falling back to a default), saves write the file, and the storage is testable against a temporary directory. Semantics mirror the UserDefaults pattern documented in the examples: load at start, save on change — nothing magical.

**Why this priority**: Completes the persistence story for real data sizes.

**Independent Test**: Store a value, write a fresh instance reading the same file, verify it loads; corrupt/remove the file and verify the default is used without crashing.

**Acceptance Scenarios**:

1. **Given** a value saved to file storage, **When** a new storage instance loads it, **Then** the same value returns.
2. **Given** no file exists yet, **When** storage loads, **Then** the documented default returns.
3. **Given** a file containing invalid data, **When** storage loads, **Then** the default returns (no crash) and the next save repairs the state.

---

### User Story 4 - Error boundary view (Priority: P2)

A developer renders a subtree whose build depends on data that may be missing or invalid. Today a thrown error inside view construction has no landing place. After this story, an `ErrorBoundary` view wraps a throwing content closure: when the content throws, the boundary renders a fallback view (receiving the error) instead of crashing, and an optional onError hook reports the error (analytics/logging). The boundary is documented honestly: it catches synchronous errors thrown while evaluating its content closure — it is not a process-crash catcher.

**Why this priority**: The last missing rendering-safety piece compared to React's ErrorBoundary idiom.

**Independent Test**: Content that throws renders the fallback with the error; content that succeeds renders normally; onError fires exactly once per caught error.

**Acceptance Scenarios**:

1. **Given** content that throws, **When** the boundary renders, **Then** the fallback view appears and onError receives the error.
2. **Given** content that does not throw, **When** the boundary renders, **Then** the content appears and onError never fires.
3. **Given** the documentation, **Then** it states the boundary catches synchronous errors from its content closure only.

### Edge Cases

- What happens when two focus atoms target the same field? (Both derive from the same base — writes through either are just base writes; last write wins, no hidden state.)
- What happens when the base atom is reset/evicted while a focus exists? (The focus re-derives from the base's fresh/default value — no stale copy.)
- What happens when a file-backed value's type changes shape between app versions? (Decoding failure falls back to the default — same contract as userDefaultsAtom; migration helpers are out of scope.)
- What happens when the ErrorBoundary's fallback itself throws? (That error propagates — the boundary does not recurse into its own fallback.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-01**: A documentation-publish workflow MUST build DocC documentation on pushes to `main` and publish it to GitHub Pages, using CI-side actions only — no new package dependency; the rulebook MUST document the equivalent local command.
- **FR-02**: A focus atom MUST expose one field of a base state atom through a key path: reads track the base, writes produce the updated base value and MUST flow into the base atom (dependents notified).
- **FR-03**: Focus atoms MUST NOT keep hidden copies of the base value — every read/writes derives from the base at that moment.
- **FR-04**: A file-backed atom storage MUST persist values as JSON in a named file, MUST support a caller-provided directory (testable with temporary directories), MUST fall back to a documented default on missing/corrupt files, and MUST expose explicit load/save operations (honest pattern).
- **FR-05**: An `ErrorBoundary` view MUST render its content normally when it does not throw, MUST render a fallback with the caught error when it does, and MUST invoke an optional onError callback exactly once per caught error.
- **FR-06**: All new APIs MUST follow the conventions rulebook (naming/prefixes, doc comments with examples) and MUST ship with tests written first (red → green).
- **FR-07**: All gates hold: root build green, full test suite green, Examples build green; no existing public API changes.

### Key Entities *(include if feature involves data)*

- **Focus atom**: base state atom + key path to a field; read/write lens with no stored copy.
- **File atom storage**: named JSON file in a caller-provided directory; load-with-default and save operations; optional observation hook.
- **Error boundary**: throwing content closure, fallback builder receiving the error, optional onError hook.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-01**: Docs workflow publishes browsable documentation on push to `main`; the rulebook's local command produces the same result.
- **SC-02**: Focus reads reflect external base changes 100% of the time; focus writes land in the base with exactly one field changed and notify base dependents (test-verified).
- **SC-03**: File storage round-trips 100% of Codable values; missing/corrupt files fall back to defaults without crashes (test-verified, including the repair-on-save path).
- **SC-04**: ErrorBoundary renders content on success, fallback on throw, and fires onError exactly once per error (test-verified).
- **SC-05**: All gates green; new APIs fully documented per the conventions rulebook.

## Assumptions

- DocC publishing uses a CI-side GitHub Action; the rulebook documents `xcodebuild docbuild`-equivalent local generation. No dependency is added to `Package.swift`.
- The focus atom's write path may require a small write-translation extension in the atom store — final shape decided in planning; the public contract is "write through the focus updates the base".
- fileAtom values are `Codable & Sendable`; storage lives in a caller-provided directory so tests use temporary directories.
- ErrorBoundary lives in `StateKitUI`; it catches synchronous throws from its own content closure and explicitly does NOT catch SwiftUI internal render crashes.
