# Quickstart: Verify Conventions Standardization

Feature: specs/004-coding-conventions · Date: 2026-09-25

## 1. Gates

```bash
swift build && swift test        # zero failures — assertions unchanged except renames
cd Examples && swift build       # green
```

## 2. Rename completeness (SC-05)

```bash
grep -rnE "\bSC(After|Concurrency|Global|Local|Retry|Task|Timeout)[A-Za-z]*\b" Sources/ Tests/ Examples/ --include="*.swift"
```

Expected: no hits (docs may mention "SCTaskDuration (renamed)" only inside the migration table).

## 3. Doc/MARK coverage (SC-03)

Re-run the coverage scan (doc-comment ratio per module). Expected: every module reports
100% of public symbols documented; files carry the MARK skeleton (spot-check 3 files/module).

## 4. Tooling (SC-02)

```bash
swiftlint lint --quiet | head        # rules load; violations (if any) named with file/line
swiftformat --lint . 2>&1 | head     # formatting check
```

Deliberate-violation check: add `let x = forceTry()` style break, see it reported, revert.

## 5. Cleanups (SC-04)

- `grep -rn "func guardFunction" Sources/` — exactly one home (StateKitCore).
- `grep -rn "defaultHasher" Sources/` — no hits.

## 6. Release docs (FR-09)

- `CHANGELOG.md` has a 3.0.0 section; `MIGRATION_GUIDE.md` lists the rename table.
- Rulebook linked from README + DOCS.md.
