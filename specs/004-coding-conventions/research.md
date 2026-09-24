# Research: Coding Conventions Standardization

Feature: specs/004-coding-conventions · Date: 2026-09-25

## D1 — The rename map (measured, not guessed)

Scan `\bSC[A-Z][A-Za-z]*\b` across Sources/Tests/Examples found exactly six real public
deviations, all in `StateConcurrency`:

| Before | After | Usages |
|--------|-------|--------|
| `SCTaskDuration` | `SKTaskDuration` | 26 |
| `SCTimeoutError` | `SKTimeoutError` | 12 |
| `SCGlobalActor` | `SKGlobalActor` | 14 |
| `SCLocalActor` | `SKLocalActor` | 10 |
| `SCRetryPolicy` | `SKRetryPolicy` | 3 |
| `SCConcurrencyLimiter` | `SKConcurrencyLimiter` | 3 |

`SCM`/`SCOPE` matches are false positives (substrings/strings). The `SCTask/` folder name and
`SCTaskTests` fixture are renamed for consistency (folder move + internal test type). Docs
(`PUBLIC_API_INVENTORY.md`, migration guide) updated in the same pass. No other public naming
deviations surfaced in the audit; the rulebook records the documented exceptions
(`*Utils`, `*Manager` retained where established) so future passes don't churn them.

**Decision**: whole-word sed across Sources/Tests/Examples/docs, then build + test. Zero logic
edits in the same commits as renames keeps the diff auditable.

## D2 — Rulebook structure (docs/engineering/CODING_CONVENTIONS.md)

Sections: (1) File layout & MARK skeleton; (2) Naming (types/functions/casing, prefixes
`use*`/`SK*`/unprefixed Riverpod layer, documented exceptions `*Utils`/`*Manager`); (3) Doc
comments (required per symbol kind, `///` markup, Parameter/Throws/Returns); (4) Comment style
(WHY over WHAT, no noise comments); (5) Concurrency annotations (MainActor confinement default,
@unchecked Sendable justification rule); (6) Error & force-conversion policy (constitution V.3);
(7) Testing conventions (naming, red→green, flake policy); (8) Tool setup (SwiftLint/SwiftFormat
one-command usage). Each rule: before/after example + origin (Swift API Design Guidelines URL or
constitution principle).

## D3 — Enforcement config policy

`.swiftlint.yml`: enable naming rules, `force_unwrapping`/`force_try` as **warning** on legacy
code with `fatalError`-style allowances where the constitution requires loud failure; todo
discipline (`todo` warning); line length 120. `.swiftformat.json`: conservative (4-space,
self-insert none, wrap off) — readability over churn. Both configs ship with a "run it" section
in the rulebook; nothing is wired into Package.swift (consumer builds unaffected).

## D4 — Doc/MARK sweep mechanics

Per module, ordered core-outward (StateKitCore → StateKit → StateKitAtoms → Riverpods →
StateConcurrency → Persistence → Cache → Analytics → FeatureFlags → UI → Combine → Support →
Testing → DevTools → Macros → MacrosPlugin header docs): re-run the review's doc-coverage scan
to list undocumented symbols; write `///` docs (one-liners for obvious accessors, full
Parameter/Throws/Returns for functions with contracts); add MARK skeleton where missing
(`// MARK: -` over types/sections). StateKit's duplicate `Internal/Function.swift` becomes a
small internal file that re-exports nothing — the single definition moves to StateKitCore and
StateKit's copy is deleted with its usages pointed at the core one.

## D5 — Release mechanics

CHANGELOG gains a `3.0.0` section (renames table + cleanups + link to guide);
MIGRATION_GUIDE.md gains the rename table with find/replace pairs; version references in
README/docs that name "2.0.0 current" are updated. Tests/Examples are updated in the same
rename commit so every gate runs against the renamed world.
