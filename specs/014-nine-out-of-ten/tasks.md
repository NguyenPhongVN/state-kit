# Tasks: Nine Out Of Ten

- [ ] T001 Switch CI macOS jobs to macos-15 (Xcode 26 available); trigger fresh CI run
- [ ] T002 Local TSan run → fix library-owned races or document dep warnings; promote CI TSan job to blocking
- [ ] T003 Benchmark suite (XCTest measure): cache ops, atom read/write, provider read/override; PERFORMANCE.md baselines
- [ ] T004 Coverage: `swift test --enable-code-coverage` + llvm-cov per-module report; threshold documented in rulebook; CI step
- [ ] T005 Independent re-review agent scores repo vs the 2026-11-05 criteria; report committed to docs/
- [ ] T006 Full gate (test + Examples + lint) + commit/push + memory update
