# Implementation Plan: Hardening Completion

**Branch**: straight to `main` (repo convention) | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md)

## Summary

Close the last four open items: publish the 3-engine architecture decision (hooks /
atoms / providers as intentional paradigms), drive the linter from 965 warnings to
zero-or-documented, convert fixed-sleep test waits to deterministic deadline polling
(3-run stability proof), and audit all 38 `@unchecked Sendable` sites with a published
justification table.

## Research (decisions)

- **R1 Lint distribution (measured at tip 261e6a9)**: identifier_name 194, trailing_whitespace 143,
  line_length 77, switch_case_alignment 43 (safe targeted autofix), force_cast 34 +
  force_unwrapping 26, orphaned_doc_comment 28, file_length 17, nesting 13, for_where 7,
  type_name 6, superfluous_disable_command 6 (stale disables from spec 012 edits).
- **R2 Strategy**: fix mechanical categories by hand (whitespace outside strings, orphaned
  comments → plain comments, wrap long lines, rename offenders); targeted
  `swiftlint --fix --only switch_case_alignment` (pure formatting, verify suite);
  identifier_name in tests = 1-char locals (h, p, n) — rename where cheap, otherwise
  config `excluded` regex for 1-2 char test locals documented; force_cast/unwrap in
  Sources fixed with safe patterns, test usage documented in rulebook; residuals land in
  the rulebook with counts. Macro expected-source strings + codegen templates stay
  excluded (spec 012 lesson: fixers corrupt string bytes).
- **R3 Sleep sweep (84 sites)**: pattern classes — (a) fixed sleep + assert → bounded
  polling (`waitFor` helpers already in RiverpodsTests; add shared helper where missing);
  (b) `try?`-swallowed cancellation on assertion paths → `try await`; (c) intentional
  time modeling → keep + `// sleep justification: …`. Proof: 3 consecutive full-suite runs.
- **R4 Sendable audit (38 sites)**: per site — isolation story (MainActor confinement /
  NSLock / immutable state / actor handoff); fix only observable confinement errors;
  comment `// Sendable audit 013: <story>` at each type + table in
  docs/engineering/SENDABLE_AUDIT.md.

## Constitution Check

All 8 principles PASS — docs-truth (US1/US4), loud failures (US2 removes noise),
test-first (US3 stability proof), no API changes.

## Structure

```text
docs/engineering/ARCHITECTURE.md   # NEW: 3-engine map (US1)
docs/engineering/SENDABLE_AUDIT.md # NEW: 38-row audit table (US4)
README.md                          # architecture pointer
.swiftlint.yml                     # documented config decisions
Sources/** + Tests/**              # lint fixes, sleep sweep, audit comments
```

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
