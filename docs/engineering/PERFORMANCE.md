# Performance Baselines (spec 014, 2026-11-15)

Benchmarks chạy bằng XCTest `measure` (wall-clock, 10 iterations). Machines vary —
these are **advisory baselines**: compare across runs on the same machine to spot
regressions; do not treat absolute numbers as contracts.

Environment: Apple Silicon Mac mini, macOS 27.2, Swift 6.2, Debug build.

| Benchmark | Workload per iteration | Baseline (avg) | Source |
|---|---|---|---|
| LRU mixed ops | 10k `set` + 10k `get` (hit-heavy), capacity 10k | **~8 ms** | `Tests/StateKitCacheTests/CacheBenchmarks.swift` |
| TTL set/get | 10k `set` + 10k `get`, ttl 300s | **~8 ms** | same |
| Atom read/write | 1k write + 1k read via `SKAtomBox` | **~2 ms** | `Tests/RiverpodsTests/EngineBenchmarks.swift` |
| Provider read | 1k cached `container.read` | **~8 ms** | same |

## Notes

- LRU is the O(1) rewrite from spec 005 (dict + doubly linked list) — ~0.8 µs/op.
- Atom box access pays an Observation registrar round-trip per read/write
  (SwiftUI integration) — that is the cost being measured.
- Provider read on a cached element is one dict lookup + Observation access.
- Rerun any benchmark with: `swift test --filter CacheBenchmarks` /
  `swift test --filter EngineBenchmarks` (no pipes).
