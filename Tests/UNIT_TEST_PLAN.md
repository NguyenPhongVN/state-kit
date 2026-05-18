# StateKit Unit Test Plan

## 1) Goals

- Ensure correctness of all targets in `Package.swift`.
- Standardize test strategy into 3 layers: `core behavior`, `integration behavior`, `regression`.
- Accelerate feedback loop with fast per-target tests and full-package validation.

## 2) Scope

Current test targets:

| # | Target | Status |
| :--- | :--- | :--- |
| 1 | `StateKitTests` | Active |
| 2 | `StateKitCoreTests` | Active |
| 3 | `StateKitUITests` | Active |
| 4 | `StateKitSupportTests` | Active |
| 5 | `StateConcurrencyTests` | Active |
| 6 | `StateKitAtomsTests` | Active |
| 7 | `StateKitMacrosTests` | Active |
| 8 | `RiverpodsTests` | Active |
| 9 | `StateKitCacheTests` | Active |
| 10 | `StateKitFeatureFlagsTests` | Active |
| 11 | `StateKitAnalyticsTests` | Active |

**Out of scope**: Deep benchmark/profiling, end-to-end app tests.

## 3) Testing Principles

- Every important public API needs: **happy path** + **edge case** + **failure path**.
- Every bug fix must include at least 1 **regression test**.
- Tests must be **independent** and **order-independent**.
- Prefer assertions on **observable behavior** over implementation details.
- Naming convention: `when_<condition>_then_<expected>` (mappable to `@Test("...")`).

## 4) Execution Strategy

### Fast (pre-commit)

```bash
swift test --filter StateKitCoreTests
swift test --filter StateKitTests
swift test --filter RiverpodsTests
```

### Full (CI gate)

```bash
swift test
```

### By group (debug)

```bash
swift test --filter StateKitAtomsTests
swift test --filter StateKitMacrosTests
swift test --filter StateConcurrencyTests
```

## 5) Per-Target Test Plan

### A. `StateKitCoreTests`

**Current files**: `StateRuntimeTests`, `StateSignalRefTests`, `StateContextTests`.

#### 5.A.1 Runtime Lifecycle
- `when_context_initialized_then_readable()` — create context, read value returns default.
- `when_context_deinitialized_then_readers_notify()` — deinit triggers observer cleanup.
- `when_context_nested_then_parent_isolation()` — child context inherits parent scope.
- `when_reentry_occurs_then_protected()` — re-entrant write does not deadlock.

#### 5.A.2 Signal & Subscription
- `when_subscribed_then_receives_current_value()` — subscribe immediately gets current.
- `when_unsubscribed_then_no_further_updates()` — unsubscribe stops notifications.
- `when_duplicate_value_emitted_then_no_notification()` — identical values are deduplicated.
- `when_multiple_subscribers_then_all_notified_in_order()` — ordering guarantee holds.

#### 5.A.3 Context Propagation
- `when_value_written_then_readable_in_same_context()` — basic read-after-write.
- `when_value_overridden_in_scope_then_scope_reads_override()` — scoped override works.
- `when_value_read_across_actors_then_mainActor_enforced()` — `@MainActor` boundary check.

### B. `StateKitTests`

**Current files**: `HookTests`, `StateKitCombineTests`, `StateKitTests` (useEffect/useLayoutEffect/useContext, AsyncPhase).

#### 5.B.1 Hooks State Machine
- `when_useState_updated_then_component_renders()` — state change triggers re-render.
- `when_multiple_hooks_then_order_stable_across_renders()` — hook order is preserved.
- `when_stale_closure_captures_old_state_then_uses_latest()` — stale closure fix works.

#### 5.B.2 Effects
- `when_dependency_changes_then_cleanup_runs_before_recreate()` — cleanup timing correct.
- `when_dependencies_unchanged_then_effect_skipped()` — no-op when deps match.
- `when_component_unmounts_then_cleanup_executes()` — dispose on unmount.

#### 5.B.3 AsyncPhase / Async APIs
- `when_async_starts_then_phase_idle_to_loading()` — transition idle → loading.
- `when_async_succeeds_then_phase_loading_to_success()` — transition loading → success.
- `when_async_fails_then_phase_loading_to_failure()` — transition loading → failure.
- `when_checking_terminal_then_success_and_failure_are_terminal()` — `isTerminal` semantics.
- `when_checking_pending_then_loading_is_pending()` — `isPending` semantics.

### C. `StateKitUITests`

**Current files**: `StateUITests`, `PlaceholderTests`.

**Action**: Replace `PlaceholderTests` with real tests.

#### 5.C.1 View Re-render Behavior
- `when_state_changes_then_view_renders()` — state mutation triggers body re-evaluation.
- `when_unrelated_state_changes_then_view_skips_render()` — no unnecessary re-render.

#### 5.C.2 Binding / Interaction
- `when_user_action_then_state_mutates_and_ui_updates()` — action → mutation → UI.
- `when_binding_writes_then_source_of_truth_updates()` — `Binding` writes propagate.

#### 5.C.3 Environment Integration
- `when_provider_injected_then_child_reads_provider_value()` — container injection.
- `when_no_provider_then_fallback_default_used()` — default environment behavior.

### D. `StateKitSupportTests`

**Current files**: `HookPropertyWrapperTests`, `PlaceholderTests`.

**Action**: Replace `PlaceholderTests` with real tests.

#### 5.D.1 Property Wrappers
- `when_wrapper_initialized_then_default_value_set()` — init with default.
- `when_wrapper_value_updated_then_propagation_fires()` — update propagates.
- `when_wrapper_reset_then_value_returns_to_default()` — reset semantics.

#### 5.D.2 Error Handling
- `when_invalid_used_then_diagnostic_emitted()` — invalid usage produces error.
- `when_assertion_fires_then_message_is_helpful()` — assertion messages are clear.

### E. `StateConcurrencyTests`

**Current files**: `SCTaskTests`, `AsyncStreamTests`.

#### 5.E.1 Cancellation Correctness
- `when_cancelled_before_start_then_task_never_runs()` — cancel before start.
- `when_cancelled_during_execution_then_task_stops()` — cancel mid-flight.
- `when_cancelled_multiple_times_then_idempotent()` — idempotent cancel.

#### 5.E.2 Stream Behavior
- `when_stream_completes_then_terminal_event_propagates()` — completion propagation.
- `when_stream_errors_then_error_propagates_to_subscriber()` — error propagation.
- `when_backpressure_applied_then_buffering_limits_honored()` — buffering assumption.

#### 5.E.3 Actor / Thread Safety
- `when_cross_actor_access_then_isolation_enforced()` — cross-actor access correct.
- `when_race_condition_possible_then_no_data_corruption()` — race-condition regression.

### F. `StateKitAtomsTests`

**Current files**: Large test suite (graph, family, environment, effect, publisher, eviction).

#### 5.F.1 Graph Invalidation
- `when_dependency_changes_then_dependents_recompute_in_order()` — deep chain ordering.
- `when_cycle_detected_then_error_or_break_cycle()` — cycle detection (if implemented).

#### 5.F.2 Family & Key Stability
- `when_same_key_used_then_same_atom_instance_returned()` — identity stability.
- `when_different_key_used_then_isolated_state()` — per-key isolation.

#### 5.F.3 Store Lifecycle
- `when_eviction_policy_set_then_old_atoms_disposed()` — eviction policy correct.
- `when_transaction_fails_then_rollback_restores_previous()` — transaction rollback.
- `when_store_reset_then_all_atoms_cleared()` — full store reset.

### G. `StateKitMacrosTests`

**Current files**: `AtomMacrosTests`, `ViewMacrosTests`, `HookMacrosTests`, `RiverpodMacrosTests`, `MacroTests`.

#### 5.G.1 Expansion Snapshot Tests
- `when_valid_atom_input_then_expanded_code_matches_expected()` — `@StateAtom`, `@ValueAtom`, etc.
- `when_valid_hook_input_then_expanded_code_matches_expected()` — `@HookState`, `@HookRef`, etc.
- `when_valid_riverpod_input_then_expanded_code_matches_expected()` — `@Provider`, `@RiverpodNotifier`, etc.
- `when_valid_view_input_then_expanded_code_matches_expected()` — `@HookView`, `@ObservableState`, etc.

#### 5.G.2 Diagnostics Tests
- `when_applied_to_class_instead_of_struct_then_diagnostic_emitted()` — type mismatch.
- `when_missing_required_method_then_helpful_error()` — missing `value(context:)`.
- `when_opaque_return_type_used_then_error_mentions_opaque()` — `some` type rejection.
- `when_duplicate_parameter_then_diagnostic_points_to_duplicate()` — parameter clash.

#### 5.G.3 Edge Case / Robustness
- `when_public_access_level_then_generated_code_also_public()` — access level propagation.
- `when_private_access_level_then_generated_code_also_private()` — access level propagation.
- `when_generic_struct_annotated_then_generics_preserved_in_output()` — generic parameter pass-through.
- `when_typealias_in_signature_then_typealias_resolved_correctly()` — typealias handling.
- `when_nested_in_other_type_then_expansion_does_not_break()` — nested type support.
- `when_unconventional_whitespace_then_parser_still_handles()` — formatting resilience.

#### 5.G.4 Regression Suite
- `when_fixed_bug_regression_input_then_output_no_longer_incorrect()` — each prior bug has a test.

### H. `RiverpodsTests`

**Current files**: `ProviderTests`, `NotifierTests`, `AdvancedTests`, `LifecycleTests`, `NewFeaturesTests`.

#### 5.H.1 Provider Semantics
- `when_provider_read_then_returns_current_value()` — basic read.
- `when_provider_watched_then_subscriber_notified_on_change()` — watch notification.
- `when_provider_parameterized_then_different_params_isolated()` — parameter isolation.
- `when_provider_result_cached_then_recomputed_only_on_dep_change()` — memoization.

#### 5.H.2 Notifier Semantics
- `when_notifier_builds_then_state_initialized()` — `build()` lifecycle.
- `when_notifier_state_updated_then_watchers_notified()` — state update notification.
- `when_notifier_disposed_then_cleanup_runs()` — dispose lifecycle.

#### 5.H.3 Family / Selectors / Advanced
- `when_family_same_key_then_same_instance()` — key-based identity.
- `when_family_different_key_then_isolated_state()` — per-key isolation.
- `when_selector_dependency_changes_then_selector_recomputes()` — derived recompute.
- `when_selector_dependency_unchanged_then_cached_value_used()` — no unnecessary recompute.

#### 5.H.4 Lifecycle
- `when_autoDispose_enabled_then_provider_disposed_when_unused()` — autoDispose.
- `when_keepAlive_set_then_provider_survives_unused_period()` — keepAlive.
- `when_provider_overridden_then_override_takes_precedence()` — provider override.

### I. `StateKitCacheTests`

**Current files**: `CacheTests`.

#### 5.I.1 TTL / Expiration
- `when_entry_expired_then_lookup_returns_nil()` — TTL expiration.
- `when_entry_not_expired_then_lookup_returns_value()` — within TTL.

#### 5.I.2 Eviction Policy (LRU / FIFO)
- `when_cache_full_then_oldest_entry_evicted()` — eviction under capacity.
- `when_lru_enabled_then_least_recently_used_evicted_first()` — LRU ordering.

#### 5.I.3 Concurrent Access Safety
- `when_multiple_threads_read_write_then_no_crash()` — concurrent safety.
- `when_racy_access_sequence_then_invariant_preserved()` — race regression.

#### 5.I.4 Serialization (if supported)
- `when_cache_serialized_then_deserialization_restores_entries()` — persistence round-trip.

### J. `StateKitFeatureFlagsTests`

**Current files**: `FeatureFlagsTests`.

#### 5.J.1 Default Flag Values
- `when_flag_not_configured_then_default_returned()` — unconfigured flag fallback.
- `when_default_provided_then_default_value_used()` — explicit default.

#### 5.J.2 Remote / Local Override Precedence
- `when_local_override_set_then_local_takes_precedence()` — local override.
- `when_remote_override_set_then_remote_overrides_default()` — remote override.
- `when_both_set_then_highest_priority_wins()` — precedence chain.

#### 5.J.3 Unknown Flag Fallback
- `when_unknown_flag_queried_then_no_crash_and_default_returned()` — graceful degradation.

#### 5.J.4 Runtime Update Propagation
- `when_flag_updated_at_runtime_then_observers_notified()` — live update.
- `when_flag_updated_then_new_reads_return_new_value()` — eventual consistency.

### K. `StateKitAnalyticsTests`

**Current files**: `AnalyticsTests`.

#### 5.K.1 Event Validation
- `when_event_sent_then_name_and_payload_match_schema()` — event structure.
- `when_payload_missing_required_field_then_validation_error()` — schema enforcement.

#### 5.K.2 Batching / Flush Behavior
- `when_events_batched_then_flushed_on_threshold()` — batch size flush.
- `when_events_batched_then_flushed_on_interval()` — time-based flush.
- `when_flush_called_manually_then_all_pending_events_sent()` — manual flush.

#### 5.K.3 Failure / Retry Policy
- `when_network_failure_then_events_retried()` — retry on failure.
- `when_max_retries_exceeded_then_events_dropped_and_callback_fires()` — max retry limit.

#### 5.K.4 Privacy Guardrails
- `when_sensitive_field_in_payload_then_field_masked()` — PII masking.
- `when_event_marked_sensitive_then_not_sent_to_third_parties()` — privacy routing.

## 6) Priority Rollout

### P0 (Week 1)

- Remove all `PlaceholderTests` from `StateKitUITests` and `StateKitSupportTests`; replace with real tests.
- Add regression tests for previously fixed bugs in `RiverpodsTests` and `StateKitAtomsTests`.

### P1 (Week 2)

- Increase concurrency + lifecycle coverage (`StateConcurrencyTests`, `StateKitCoreTests`).
- Complete diagnostics tests for all macro groups (Atom, View, Hook, Riverpod).
- Add edge-case / robustness tests for macros (access levels, generics, nested types).

### P2 (Week 3)

- Add in-depth test suites for cache/analytics/feature-flags based on production scenarios.
- Add snapshot/regression harness for macros if not already present.

## 7) Exit Criteria

- All test targets pass on local and CI (`swift test`).
- Zero `PlaceholderTests` remaining.
- Each module has at minimum:
  - 1 happy-path test
  - 1 edge-case test
  - 1 failure/regression test for every important public API
- Every new bug fix includes a companion regression test.

## 8) Review Conventions for Unit Tests

- Avoid unnecessary `sleep`; prefer deterministic scheduler/clock where available.
- Avoid overly generic assertions (e.g. asserting `true`).
- Test messages must be descriptive and easy to trace on failure.
- Any PR changing public API must update the relevant tests in the same PR.

## 9) Next Steps

1. Create per-target tracking (checklist) and mark completion per sprint.
2. Pick 2 placeholder targets (`StateKitUI`, `StateKitSupport`) and implement first real tests.
3. Enforce `swift test` CI check on every PR.

## 10) Macro Test Strategy

Macro testing follows 4 tiers (52 expansion/diagnostic tests currently passing).

### Tier 1: Macro Expansion & Diagnostic Testing

**Goal**: Verify macros generate the exact Swift code intended and provide helpful error messages for misuse.

- **Tools**: `SwiftSyntaxMacrosTestSupport`, `assertMacroExpansion`.
- **Status**: 100% Covered (52 Test Cases).
- **Key Files**:
  - `AtomMacrosTests.swift`: 17 tests (Core & Derived Atoms)
  - `ViewMacrosTests.swift`: 5 tests (UI & Observation)
  - `HookMacrosTests.swift`: 16 tests (Hooks & Side Effects)
  - `RiverpodMacrosTests.swift`: 11 tests (Providers & Families)
  - `MacroTests.swift`: Infrastructure checks

### Tier 2: Integration & Runtime Testing

**Goal**: Ensure generated code compiles against the full library and behaves at runtime.

- Target: `StateKitMacroIntegrationTests`
- Verification points:
  - `@StateAtom` extensions satisfy protocol requirements
  - `@Provider` generates accessible properties on `ProviderContainer`
  - `@HookView` wraps body in `StateScope` at runtime

### Tier 3: Edge Case & Robustness

- Access levels (`public`, `internal`, `private`, `fileprivate`).
- Generic types (`@ValueAtom struct MyAtom<T>`).
- Typealiases in method signatures.
- Nested type declarations.
- Unconventional whitespace/formatting.

### Tier 4: Tooling & IDE Compatibility

- Manual Xcode audit: generated members (`Value`, `Provider`, `useHook`) appear in autocomplete.
- No red squigglies in editor after macro expansion.

### Macro Audit Registry

| Macro Group | Macros | Test File | Expansion | Diagnostics | Conformances |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **Atom Core** | @StateAtom, @ValueAtom, @TaskAtom, @ThrowingTaskAtom, @PublisherAtom, @Atom | `AtomMacrosTests` | ✅ | ✅ | ✅ |
| **Atom Family** | @AtomFamily, @SelectorFamily, @AsyncTaskFamily | `AtomMacrosTests` | ✅ | ✅ | N/A |
| **Derived Atoms** | @Computed, @SelectorAtom, @FilteredAtom, @MappedAtom, @CombineAtom, @DistinctAtom, @FlatMapAtom | `AtomMacrosTests` | ✅ | ✅ | ✅ |
| **Atom Reducer** | @AtomReducer | `AtomMacrosTests` | ✅ | ✅ | ✅ |
| **View Infrastructure** | @HookView, @StateView, @AsyncView, @ObservableState | `ViewMacrosTests` | ✅ | ✅ | ✅ |
| **Hook Basics** | @HookState, @HookRef, @HookToggle, @Hook (validation), @CustomHook (validation) | `HookMacrosTests` | ✅ | ✅ | N/A |
| **Hook Effects** | @HookEffect, @AsyncHook, @Debounce, @Throttle, @HookInterval | `HookMacrosTests` | ✅ | ✅ | N/A |
| **Hook Logic** | @HookMemo, @HookCallback, @HookReducer, @HookPrevious, @HookContext, @HookForm | `HookMacrosTests` | ✅ | ✅ | N/A |
| **Riverpod Core** | @RiverpodNotifier, @StateProvider, @FutureProvider, @StreamProvider, @Provider | `RiverpodMacrosTests` | ✅ | ✅ | N/A |
| **Riverpod Family** | @ProviderFamily, @RiverpodFamily, @RiverpodFutureFamily, @RiverpodStreamFamily | `RiverpodMacrosTests` | ✅ | ✅ | N/A |
| **Riverpod Misc** | @RiverpodSelector, @RiverpodAsync | `RiverpodMacrosTests` | ✅ | ✅ | N/A |

### Macro Future Maintenance

1. **Macro Regression Suite**: Run Tier 1 tests on every CI build.
2. **Swift Version Tracking**: Verify compatibility with every major Swift/SwiftSyntax release.
3. **Documentation Sync**: Ensure `README.md` and `docs/` reflect tested behavioral patterns.
