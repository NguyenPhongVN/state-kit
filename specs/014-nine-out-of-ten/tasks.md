# Tasks: Nine Out Of Ten

- [X] T001 Switch CI macOS jobs to macos-15 (Xcode 26 available); trigger fresh CI run
- [X] T002 Local TSan run → fix library-owned races or document dep warnings; promote CI TSan job to blocking
- [X] T003 Benchmark suite (XCTest measure): cache ops, atom read/write, provider read/override; PERFORMANCE.md baselines
- [X] T004 Coverage: `swift test --enable-code-coverage` + llvm-cov per-module report; threshold documented in rulebook; CI step
- [X] T005 Independent re-review agent scores repo vs the 2026-11-05 criteria; report committed to docs/
- [X] T006 Full gate (test + Examples + lint) + commit/push + memory update
