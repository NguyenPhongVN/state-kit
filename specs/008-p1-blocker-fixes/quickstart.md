# Quickstart: Validating P1 Blocker Fixes

Prerequisites: Swift 6.2 toolchain, repo root. All validation is automated — run the per-module
regression suites, then the full package.

## Run the new regression suites

```bash
# US1: hook teardown cancels in-flight work + deallocates (leak fixes, weak-ref assertions)
swift test --filter HookTeardownRegressionTests

# US2: publisher hooks write phase state on the main actor only
swift test --filter PublisherHookMainThreadTests

# US3: interceptor removal + bridge cleanup (baseline count after dispose)
swift test --filter InterceptorRemovalTests
swift test --filter BridgeInterceptorCleanupTests

# US4: DevToolsObserver records provider updates through a real container
swift test --filter DevToolsObserverRecordingTests

# US5: provider elements do not self-retain through onDispose
swift test --filter ProviderElementDeallocationTests

# US6: ABTest with empty variants returns nil (no crash)
swift test --filter ABTestEmptyVariantsTests

# US7: StateDevScope render counting is DEBUG-only
swift test --filter StateDevScopeRenderCountTests

# US8: EventTracker retention is bounded
swift test --filter EventTrackerRetentionTests

# US9: Keychain never destroys the previous secret; state commits only after success
swift test --filter KeychainWriteOrderingTests

# US10: DeterministicTimeProvider.advance mutates time
swift test --filter DeterministicTimeAdvanceTests
```

## Full quality gates (constitution: Development Workflow & Quality Gates)

```bash
swift build          # must succeed
swift test           # zero failures, zero unexpected skips
```

Expected outcomes:

- All pre-existing suites keep passing (no behavior regressions outside the fixed defects).
- Each new suite fails when reverted to the old implementation (red→green discipline; each task in
  `tasks.md` records its red observation).
- No new warnings related to deprecated `addInterceptor` inside the package (the bridge uses the new
  API; the deprecated path forwards internally with `@available(*, deprecated)` silence where needed).

## Manual spot checks (optional, host-dependent)

- DevTools: register `DevToolsObserver` on `ProviderContainer(observers:)`, update a state provider,
  observe history entries appearing (previously: nothing).
- Keychain (real device/simulator with entitlement): store a secret via `KeychainBatch`, force a
  failure on the second item, confirm the first item's previous value still reads back.
