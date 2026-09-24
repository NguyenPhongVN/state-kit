# Rename Map — StateKit 3.0.0

Feature: specs/004-coding-conventions · Date: 2026-09-25

Every public rename in this release. Applied as whole-word replacements across Sources/,
Tests/, Examples/, and docs/. No signature or behavior changes ride along.

## StateConcurrency (the `SC*` prefix family → `SK*`)

| Before | After | Usages |
|--------|-------|--------|
| `SCTaskDuration` | `SKTaskDuration` | 26 |
| `SCGlobalActor` | `SKGlobalActor` | 14 |
| `SCTimeoutError` | `SKTimeoutError` | 12 |
| `SCLocalActor` | `SKLocalActor` | 10 |
| `SCRetryPolicy` | `SKRetryPolicy` | 3 |
| `SCConcurrencyLimiter` | `SKConcurrencyLimiter` | 3 |

Also renamed for consistency (non-public or textual):
- test fixture type `SCTaskTests` suite/file naming → `SKTaskTests`
- folder `Sources/StateConcurrency/SCTask/` → `Sources/StateConcurrency/SKTask/`
- `SCM`/`SCOPE` grep hits are false positives — intentionally NOT touched.

## Non-renames (documented exceptions)

- `*Utils` / `*Manager` types (e.g. `HashUtils`, `RolloutManager`) — allowed by the rulebook
  where established; renaming them is churn without clarity gain. The rulebook records the
  exception so future passes stay consistent.
