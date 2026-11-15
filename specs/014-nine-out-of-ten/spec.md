# Feature Specification: Nine Out Of Ten — CI Truth, Concurrency Proof, Perf & Coverage

**Created**: 2026-11-15 | **Status**: Draft

**Input**: "From the 6.5/10 review to 9/10: make CI truthful (green on GitHub, not cancelled),
prove thread safety with TSan, add performance benchmarks, add coverage measurement,
and close with an independent re-score."

## User Scenarios & Testing

### US1 - CI runs green on GitHub (P1)
A maintainer pushes code and GitHub Actions actually completes green. Today: macos-14
runners lack Xcode 26 (tool selection step fails on all three jobs), and the lint job
failed on pre-013 violations. Fixes: run macOS jobs on an image with Xcode 26; the lint
gate is already clean locally. Any cancelled-run confusion is resolved by a fresh push
triggering a complete run.
**Acceptance**: latest push shows CI (all jobs) completed success; docs workflow succeeds
or its failure is explained and fixed.

### US2 - Thread safety proven, TSan promoted to blocking (P1)
The library sells concurrency; the TSan job must be shown clean locally first, then
promoted to a blocking CI job.
**Acceptance**: local `swift test --sanitize=thread` exits 0 (or every reported race is
fixed with a regression test); CI job loses `continue-on-error`.

### US3 - Performance regressions become visible (P2)
A benchmark suite pins the hot paths (LRU/TTL cache ops, atom read/write, provider
read/override) with measured baselines recorded in docs. A future regression is visible
by comparing benchmark output.
**Acceptance**: benchmark target runs green locally; baseline numbers published in
docs/engineering/PERFORMANCE.md.

### US4 - Coverage is measured and gated (P2)
Coverage is measured from the test suite and published; core engine modules get a
documented threshold gate in CI; worst uncovered hot paths get tests where cheap.
**Acceptance**: coverage report generated locally; CI uploads/reports coverage;
threshold documented in the rulebook.

### US5 - Independent re-score (P1)
A fresh reviewer (no memory of the fixes) re-scores the repository against the original
2026-11-05 review criteria; the delta from 6.5/10 is reported honestly, including
anything that did NOT improve.
**Acceptance**: re-review report committed under docs/ with a score and remaining gaps.

## Requirements
- FR-001: macOS CI jobs MUST run on an image that provides the declared toolchain
  (Xcode selection step must succeed).
- FR-002: TSan MUST be proven clean locally before promotion to blocking in CI.
- FR-003: Benchmarks MUST cover cache ops, atom read/write, provider read; baselines
  MUST be committed.
- FR-004: Coverage MUST be measured; core-module threshold documented and enforced or
  explicitly waived with reasoning.
- FR-005: The re-score MUST be produced by an independent reviewer process and committed.
- FR-006: No public API signature changes; no behavior changes except fixes surfaced by
  TSan.

## Success Criteria
- SC-001: Latest push → CI completed success (all jobs).
- SC-002: Local TSan run exit 0; CI TSan job blocking.
- SC-003: Benchmarks run green; PERFORMANCE.md committed with baselines.
- SC-004: Coverage report exists with per-module numbers; threshold documented.
- SC-005: Re-review committed with an explicit score; target ≥ 9/10 or gaps listed.

## Assumptions
- GitHub macos-15 hosted images provide Xcode 26.x (Swift 6.2) in 2026.
- TSan may surface warnings from dependencies; library-owned races are what we fix.
- Benchmarks are advisory baselines (no hard CI perf gate — machines vary).
