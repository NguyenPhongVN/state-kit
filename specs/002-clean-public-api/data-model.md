# Data Model: Clean Public API Overhaul

Feature: specs/002-clean-public-api · Date: 2026-09-25

No persistent data changes. Entities are audit/code-level:

## AuditFinding

- Fields: id (F1…), severity (P1 crash/counterfeit · P2 confusion · P3 polish), location,
  rule violated (constitution Principle), disposition (fixed / justified / deferred), note.
- Rules: P1 findings cannot be deferred (FR-02); every justified force-conversion carries a
  written invariant comment at the site (FR-03).
- Storage: [audit.md](./audit.md) — findings index + module verdicts; stable structure = re-run method.

## Container accessor semantics (post-fix)

| Accessor | Registers listener? | Returns | Balance |
|----------|--------------------|---------|---------|
| `read(_:)` | No — pure | current state | — |
| `watch(_:)` | **Yes** (post-fix) | current state | pair with `removeListener(for:)` |
| `addListener(for:)` | Yes | current state | **deprecated** → use `watch(_:)` |
| `removeListener(for:)` | Removes | Void | closes a watch/addListener |
| `refresh(_:)` | No | recomputed state | — |
| `listen(_:fireImmediately:listener:)` | Yes (callback) | subscription | `subscription.close()` |

Lifecycle transitions: first `watch` on an element fires add/resume callbacks; last removal
schedules auto-dispose per provider policy (unchanged semantics — watch now participates in
the same refcount addListener used).

## Deprecation shim

- `addListener(for:)` body becomes `watch(_:)` (same behavior), annotated deprecated with a
  replacement message; compiles for all existing callers until removal at next MAJOR.
