# Data Model: Conventions Entities

Feature: specs/004-coding-conventions · Date: 2026-09-25

## Conventions rule
- Fields: category, statement, before/after example, origin (Swift guideline | constitution principle).
- Home: `docs/engineering/CODING_CONVENTIONS.md`.
- Validation: every FR-01 category present; no rule without an example.

## Rename entry
- Fields: before, after, module, usage count.
- Source of truth: `contracts/rename-map-3.0.0.md`; applied mechanically (whole-word) across
  Sources/Tests/Examples/docs; mirrored in MIGRATION_GUIDE.md.
- Constraint: renames only — no signature/behavior edits ride along.

## Coverage ledger
- Fields: module, MARK-skeleton status, documented/total public symbols, order completed.
- Home: tail of the conventions document ("Rollout & Coverage").
- Validation: re-running the review's doc-coverage scan reproduces the numbers.

## MARK skeleton (file standard)
1. Header `///` doc (what the file is)
2. `import`s
3. `// MARK: - [Main type]`
4. `// MARK: - Extensions/Helpers` sections as applicable
