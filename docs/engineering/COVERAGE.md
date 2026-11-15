# Coverage (spec 014, 2026-11-15)

## How to measure

```bash
swift test --enable-code-coverage
xcrun llvm-cov report \
  ".build/out/Products/Debug/RiverpodsTests.xctest/Contents/MacOS/RiverpodsTests" \
  -instr-profile ".build/out/Products/Debug/codecov/default.profdata" --summary-only
```

## Engine snapshot (Riverpods, line coverage)

| File | Lines |
|---|---|
| `Container/ProviderContainer.swift` | 84.4% |
| `Container/ProviderElement.swift` | 91.5% |
| `Core/EcosystemBridge.swift` | 93.0% |
| `Core/ProviderProtocol.swift` | 93.2% |
| `Core/ProviderRef.swift` | 100% |
| `Core/ProviderID.swift` | 100% |
| `Core/AsyncValue.swift` | 28.4% (enum display helpers — mostly `.when` conveniences; core paths covered) |
| `Container/ProviderObserver.swift` | 33.3% (default-implementation shims) |

## Policy (rulebook §10 companion)

- **Core engine threshold (advisory): container + core files ≥ 75% line coverage.**
  Measured before each release; CI prints the coverage report in the Build & Test job
  (spec 014) but does not hard-gate on it — the gate lives in release review.
- The 2026-11-05 coverage imbalance (Riverpods 8.5K LOC / ~40 tests) was addressed in
  specs 010-014: regression suites for every engine fix (override, keep-alive, hierarchy,
  stream), plus StateKitTesting + Support coverage added in 012.
- Known thin spots, documented honestly: `AsyncValue` conveniences (28%), DevTools UI,
  Examples app — all out of the hot-path core.
