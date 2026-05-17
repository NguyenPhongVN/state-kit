# State-Kit Unit Test Plan

## 1) Muc tieu

- Dam bao tinh dung dan cua cac target trong `Package.swift`.
- Chuan hoa test strategy theo 3 lop: `core behavior`, `integration behavior`, `regression`.
- Day nhanh feedback loop voi test nhanh theo target va test tong hop toan bo package.

## 2) Pham vi

Test targets hien co:

- `StateKitTests`
- `StateKitCoreTests`
- `StateKitUITests`
- `StateKitSupportTests`
- `StateConcurrencyTests`
- `StateKitAtomsTests`
- `StateKitMacrosTests`
- `RiverpodsTests`
- `StateKitCacheTests`
- `StateKitFeatureFlagsTests`
- `StateKitAnalyticsTests`

Khong bao gom benchmark/perf chuyen sau va end-to-end app tests.

## 3) Nguyen tac test

- Moi API public quan trong can co test happy path + edge case + failure path.
- Moi bug fix phai kem it nhat 1 regression test.
- Test doc lap, khong phu thuoc thu tu chay.
- Uu tien assertion hanh vi observable thay vi implementation detail.
- Dat ten test theo format: `when_<condition>_then_<expected>` (co the map vao `@Test("...")`).

## 4) Execution strategy

### Nhanh (pre-commit)

- `swift test --filter StateKitCoreTests`
- `swift test --filter StateKitTests`
- `swift test --filter RiverpodsTests`

### Day du (CI gate)

- `swift test`

### Theo nhom de debug

- `swift test --filter StateKitAtomsTests`
- `swift test --filter StateKitMacrosTests`
- `swift test --filter StateConcurrencyTests`

## 5) Test plan theo target

### A. `StateKitCoreTests`

Trang thai hien tai: da co `StateRuntimeTests`, `StateSignalRefTests`, `StateContextTests`.

Can bao phu:

1. Runtime lifecycle
   - init/teardown context
   - nested context isolation
   - re-entrancy protection
2. Signal & subscription
   - subscribe/unsubscribe
   - duplicate notification prevention
   - ordering guarantee
3. Context propagation
   - read/write value
   - override theo scope
   - thread/main actor expectation neu co

### B. `StateKitTests`

Trang thai hien tai: da co `HookTests`, `StateKitCombineTests`, `StateKitTests` (useEffect/useLayoutEffect/useContext, AsyncPhase).

Can bao phu bo sung:

1. Hooks state machine
   - `useState` update sequencing
   - multiple hooks order stability
   - stale closure scenarios
2. Effects
   - cleanup timing khi dependency doi
   - no-op khi dependency khong doi
   - dispose cleanup khi unmount
3. AsyncPhase/Async APIs
   - transitions idle -> loading -> success/failure
   - terminal semantics (`isTerminal`, `isPending`)

### C. `StateKitUITests`

Trang thai hien tai: co `StateUITests` + `PlaceholderTests`.

Can thay `PlaceholderTests` bang test that su:

1. View re-render behavior
   - state change trigger render
   - no unnecessary re-render
2. Binding/interaction
   - user action -> state mutation -> UI update
3. Environment integration
   - provider/container injection
   - fallback/default environment behavior

### D. `StateKitSupportTests`

Trang thai hien tai: co `HookPropertyWrapperTests` + `PlaceholderTests`.

Can thay `PlaceholderTests` bang test that su:

1. Property wrappers
   - init default values
   - update propagation
   - reset semantics
2. Error handling
   - invalid usage diagnostics
   - assertion/failure expectation (neu API co)

### E. `StateConcurrencyTests`

Trang thai hien tai: `SCTaskTests`, `AsyncStreamTests`.

Can bao phu:

1. Cancellation correctness
   - cancel truoc khi start
   - cancel trong luc dang chay
   - idempotent cancel
2. Stream behavior
   - completion propagation
   - error propagation
   - backpressure/basic buffering assumption
3. Actor/thread safety
   - cross-actor access expectation
   - race-condition regression cases

### F. `StateKitAtomsTests`

Trang thai hien tai: da co bo test lon (graph, family, environment, effect, publisher, eviction...).

Can duy tri va bo sung:

1. Graph invalidation
   - deep dependency chain recompute dung thu tu
   - cycle detection/handling (neu co)
2. Family & key stability
   - same input -> same identity
   - different input -> isolated state
3. Store lifecycle
   - eviction policy correctness
   - transaction rollback/consistency

### G. `StateKitMacrosTests`

Trang thai hien tai: `MacroTests`.

Can bao phu:

1. Expansion snapshot tests
   - valid input -> expected expanded source
2. Diagnostics tests
   - invalid syntax -> expected compiler diagnostics
   - wrong target kind (class/struct/function mismatch)
3. Regression suite
   - moi macro bug da fix phai co test input nho gon

### H. `RiverpodsTests`

Trang thai hien tai: `ProviderTests`, `NotifierTests`, `AdvancedTests`, `LifecycleTests`, `NewFeaturesTests`.

Can bao phu:

1. Provider semantics
   - read/watch/listen behavior
   - memoization/cache correctness
2. Notifier semantics
   - `build()` lifecycle
   - state update notification
3. Family/selectors/advanced
   - parameterized provider isolation
   - derived providers recompute only when needed
4. Lifecycle
   - disposal/autoDispose behavior
   - keepAlive expectations

### I. `StateKitCacheTests`

Trang thai hien tai: `CacheTests`.

Can bao phu:

1. TTL/expiration
2. Eviction policy (LRU/FIFO neu co)
3. Concurrent access safety
4. Serialization/deserialization neu cache support persistence

### J. `StateKitFeatureFlagsTests`

Trang thai hien tai: `FeatureFlagsTests`.

Can bao phu:

1. Default flag values
2. Remote/local override precedence
3. Unknown flag fallback
4. Runtime update propagation

### K. `StateKitAnalyticsTests`

Trang thai hien tai: `AnalyticsTests`.

Can bao phu:

1. Event validation (name, payload schema)
2. Batching/flush behavior
3. Failure-retry policy
4. Privacy guardrails (masking/sensitive fields)

## 6) Priority rollout

### P0 (tuan 1)

- Xoa `PlaceholderTests` o `StateKitUITests` va `StateKitSupportTests`, thay bang test that su.
- Bo sung regression tests cho bug da tung gap trong `RiverpodsTests` va `StateKitAtomsTests`.

### P1 (tuan 2)

- Tang do bao phu concurrency + lifecycle (`StateConcurrencyTests`, `StateKitCoreTests`).
- Hoan thien diagnostics tests cho macros.

### P2 (tuan 3)

- Bo sung test sau cho cache/analytics/feature-flags theo production scenarios.

## 7) Exit criteria

- Tat ca test target chay pass tren local va CI (`swift test`).
- Khong con `PlaceholderTests`.
- Moi module co it nhat:
  - 1 test happy path
  - 1 test edge case
  - 1 test failure/regression cho API quan trong
- Bug moi duoc fix deu co regression test di kem.

## 8) Quy uoc review cho unit tests

- Tranh sleep khong can thiet; uu tien deterministic scheduler/clock neu co.
- Tranh assertion qua chung chung (vi du chi check `true`).
- Test message ro nghia, de trace khi fail.
- PR nao thay doi public API phai cap nhat test lien quan trong cung PR.

## 9) De xuat tiep theo

1. Tao file tracking theo target (checklist) va danh dau completion theo sprint.
2. Chon 2 target placeholder (`StateKitUI`, `StateKitSupport`) de implement ngay bo test dau tien.
3. Bat buoc CI check `swift test` cho moi PR.
