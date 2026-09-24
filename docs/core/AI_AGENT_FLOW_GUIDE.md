# StateKit — AI Agent Coding Flow Guide

> Tài liệu điều hướng cho AI agent khi code với StateKit. Cặp với `PUBLIC_API_INVENTORY.md` (danh mục đầy đủ symbol). Số liệu thống kê ngày 2026-09-22 từ nguồn `Sources/`.

## Thống kê nhanh

- **16 library products** trong `Package.swift` (Swift 6.2; iOS 17+/macOS 14+/tvOS 17+/watchOS 10+/visionOS 1+).
- **220 file Swift** trong `Sources/`.
- **1.422 public symbol** — 309 type (class/struct/enum/protocol/actor/typealias/extension) + 1.113 member (func/var/let/init/subscript), chưa tính `StateKitMacrosPlugin` (compiler plugin nội bộ, không bao giờ import trực tiếp).
- **48 public macro** trong `StateKitMacros` (README ghi "47" đã lỗi thời — đếm thực tế 48).

Phân bố symbol theo module:

| Module | Symbols | Thành phần chính |
|---|---|---|
| Riverpods | 271 | func 116, struct 23, class 15, protocol 7, typealias 14 |
| StateKitTesting | 136 | func 86, struct 16, class 6 |
| StateKitDevTools | 125 | func 42, var 28, let 22 |
| StateKitMacrosPlugin (nội bộ) | 121 | — không dùng trực tiếp |
| StateKitAtoms | 119 | func 73, protocol 11, class 8 |
| StateKitFeatureFlags | 118 | let 44, func 29, struct 12 |
| StateKitAnalytics | 103 | let 43, func 24, struct 11 |
| StateConcurrency | 101 | func 48, struct 12, actor 2 |
| StateKitPersistence | 108 | func 38, struct 16, class 4 |
| StateKitCache | 80 | func 35, struct 8, class 4 |
| StateKitSupport | 76 | var 19, struct 13, func 12 |
| StateKit | 58 | func 33, extension 11, enum 6 |
| StateKitMacros | 48 | macro 48 |
| StateKitUI | 36 | extension 9, struct 8, protocol 1 |
| StateKitCombine | 17 | func 6, extension 4, typealias 3 |
| StateKitCore | 26 | func 10, var 7, class 3 |

## Dependency graph (thứ tự import khi code)

```
StateKitCore
   └── StateKit  (re-export core; hooks API)
         ├── StateKitAtoms          (atom global state)
         │     ├── Riverpods        (provider global state; phụ thuộc cả StateKit)
         │     ├── StateKitSupport  (@SAtom/@Hook wrappers)
         │     ├── StateKitUI       (StateView, SKAtomRoot; phụ thuộc StateKit + Support)
         │     ├── StateKitCombine  (bridge Combine; phụ thuộc StateKit + Atoms)
         │     ├── StateKitPersistence (UserDefaults/Keychain/SwiftData)
         │     └── StateKitAnalytics / StateKitCache / StateKitDevTools (qua Riverpods)
         └── StateConcurrency       (Task helpers; phụ thuộc StateKit + TCA)
StateKitFeatureFlags (độc lập, không phụ thuộc)
StateKitTesting (StateKit + Riverpods)
```

Module độc lập: `StateKitFeatureFlags`. Module "lá" chỉ phụ thuộc Riverpods: `StateKitCache`, `StateKitAnalytics`.

## Flow 1 — Local UI state (hooks, kiểu React)

**Khi nào:** state chỉ phục vụ 1 view, không chia sẻ.

1. View conforms `StateView` (protocol ở `StateKitUI/ScopedState/StateView.swift`), implement `stateBody`.
2. Dùng hooks từ module `StateKit`:
   - `useState<T>(_ initial:) -> (T, (T) -> Void)` — state cơ bản.
   - `useBinding<T>(_ initial:) -> Binding<T>` — bridging sang SwiftUI `Binding`.
   - `useReducer<Action, State>(reducer:initial:)` — state phức tạp nhiều action.
   - `useEffect` / `useLayoutEffect` — side effect + cleanup, trả `(() -> Void)?`.
   - `useMemo`, `useCallback`, `useRef`, `useContext` (`HookContext<Value>`), `useEnvironment`.
   - Async: `useAsync`, `useAsyncPerform`, `useAsyncRefresh`, `useAsyncSequence`; Combine: `usePublisher`.
3. Async state có phase type sẵn: `AsyncPhase`, `AsyncSequencePhase`, `PublisherPhase` (enum: `.standby/.loading/.success/.failure`); status riêng: `SKStatus`, `AsyncSequenceStatus`, `PublisherStatus`.
4. Điều khiển re-render bằng `UpdateStrategy` (`.once`, dependency-based).

```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)
        Button("Count: \(count)") { setCount(count + 1) }
    }
}
```

**Lưu ý cho agent:** `StateView` tách `stateBody` khỏi `body` — hooks chỉ được gọi trong `stateBody`.

## Flow 2 — Global state kiểu Atom (Recoil/Jotai)

**Khi nào:** state chia sẻ nhiều view, cần graph computed/derived.

1. Định nghĩa atom — nhanh nhất dùng macro `@StateAtom` / `@ValueAtom` / `@TaskAtom` / `@ThrowingTaskAtom` / `@PublisherAtom` / tổng quát `@Atom` (module `StateKitMacros`):

```swift
import StateKitMacros

@StateAtom
struct CounterAtom {
    func defaultValue(context: Context) -> Int { 0 }
}
```

2. Hoặc conform protocol thủ công: `SKStateAtom`, `SKValueAtom`, `SKTaskAtom`, `SKThrowingTaskAtom`, `SKPublisherAtom`, `SKAsyncPhaseAtom` (module `StateKitAtoms/Protocol/`).
3. derived/selector: macro `@Computed`, `@SelectorAtom`, `@FilteredAtom`, `@MappedAtom`, `@DistinctAtom`, `@FlatMapAtom`, `@CombineAtom`; ref types `SKAtomRef`, `SKAsyncAtomRef`, `SKSelectorRef`, `SKSelectors`.
4. Family: `@AtomFamily`, `@SelectorFamily`, `@AsyncTaskFamily` + `SKAtomFamily`.
5. Đọc/ghi trong hook: `useAtomState(_:) -> (Value, (Value) -> Void)`, `useAtomRefresher(_:)` (cho task atom).
6. Cấp store: bọc view trong `SKAtomRoot { ... }` (store mặc định) hoặc `SKAtomScopeView(store:content:)` (store riêng); store là `SKAtomStore`, truy cập qua `EnvironmentValues.skAtomStore`. Effect/transaction: `SKAtomEffect`, `SKAtomTransactionContext`, `SKAtomViewContext`.

## Flow 3 — Global state + logic kiểu Riverpod

**Khi nào:** cần notifier/DI/lifecycle như Riverpod, family, override, test.

1. Định nghĩa notifier + provider:

```swift
final class CounterNotifier: Notifier<Int> {
    override func build() -> Int { 0 }
    func increment() { state += 1 }
}
let counterProvider = NotifierProvider { CounterNotifier() }
```

2. Hoặc macro rút gọn: `@RiverpodNotifier`, `@RiverpodFamily`, `@RiverpodAsync`, `@RiverpodSelector`, `@FutureProvider`, `@StreamProvider`, `@StateProvider`, `@Provider`, `@ProviderFamily`, `@RiverpodFutureFamily`, `@RiverpodStreamFamily`.
3. Chọn provider struct theo nguồn dữ liệu (`Riverpods/Providers/`):
   - `NotifierProvider<N, T>` — state đồng bộ + mutation qua notifier.
   - `FutureProvider<T>` — async one-shot.
   - `StreamProvider<T>` / `AsyncSequenceProvider<T>` — dữ liệu dòng chảy liên tục.
   - `StateProvider<T>` + `StateController<T>` — mutable state controller.
   - Family: `Family` + các instance provider (`NotifierInstanceProvider`, ...).
4. Đọc trong SwiftUI (`Riverpods/SwiftUI/`): property wrapper `@Watch<P>(_ provider:)` (re-render khi thay đổi) hoặc `@Read<P>` (đọc không subscribe); bọc app trong `ProviderScope`. Mutate: gọi method trên notifier lấy từ provider.
5. Test/override: `ProviderOverride`, `ProviderContainer`, observer `ProviderObserver`; composition: `StateComposer`, `ScopeComposable`, `ActionRoutable`, `CompositionStrategy`.
6. Helper sync giữa 2 thế giới: `RiverpodAtom<P>` (bridge atom → provider).

## Flow 4 — Async / side effects (StateConcurrency)

- Wrap task: `Task.throwingTimeout(.minutes(1)) { ... }` (ném `SKTimeoutError`), `Task.retrying(...)` (retry policy `SKRetryPolicy`), `Task.gather`/`gatherThrowing`/`gatherValues` (chạy song song), `Task.race` (ai xong trước dùng trước), `Task.sleep(seconds:duration:)`.
- Streams: `AsyncCurrentValueStream`, `AsyncPassthroughStream`, `AsyncValueStream`, `AnyAsyncSequence` + extension trên `AsyncSequence`.
- UI action: `DebouncedAction(interval:operation:)`, `ThrottledAction(interval:operation:)` — call bằng `callAsFunction`.
- Hạ tầng: `ObservableTask`, `SKConcurrencyLimiter`, `SKGlobalActor`, `SKLocalActor`, `CheckedContinuationWrapper`, `SKTaskDuration`.

Lưu ý: timeout API public là `Task.throwingTimeout` (không có bản non-throwing public); `StateConcurrency` phụ thuộc cả `StateKit` và `ComposableArchitecture` (TCA có sẵn trong dependency nếu cần).

## Flow 5 — Persistence / Cache / Flags / Analytics (feature modules)

- **Persistence:** atom/provider gắn storage — `UserDefaultsAtom`, `KeychainStateProvider`, `SwiftDataIntegration`.
- **Cache:** `CachePolicy`, `LRUCache`, `TTLCache`, entry point `StateKitCache`.
- **Feature flags:** `Rollout`, `ABTestFramework`, entry `StateKitFeatureFlags` (module độc lập dependency).
- **Analytics:** `EventTracker`, `UserJourney`, entry `StateKitAnalytics`.

## Flow 6 — Testing & DevTools

- **StateKitTesting:** deterministic testing (`DeterministicTesting`, fixtures `StateTestFixtures`, integration helpers `IntegrationTestHelpers`, entry `Testing.swift`). Cho phép render StateView với context ảo, assert state từng bước.
- **StateKitDevTools:** `StateHistory`, `DebugProviderObserver`, `DevToolsObserver`, `PerformanceMetrics`, UI `DevToolsView` + `DevToolsHandle`.

## Flow 7 — Macro (giảm boilerplate)

48 macro, 4 nhóm (module `StateKitMacros` — import 1 dòng duy nhất):

- **Atoms (16):** `StateAtom`, `ValueAtom`, `TaskAtom`, `ThrowingTaskAtom`, `PublisherAtom`, `Atom`, `AtomFamily`, `SelectorFamily`, `AsyncTaskFamily`, `AtomReducer`, `Computed`, `SelectorAtom`, `FilteredAtom`, `MappedAtom`, `CombineAtom`, `DistinctAtom`, `FlatMapAtom`.
- **Riverpods (12):** `RiverpodNotifier`, `RiverpodFamily`, `StateProvider`, `Provider`, `FutureProvider`, `StreamProvider`, `ProviderFamily`, `RiverpodSelector`, `RiverpodAsync`, `RiverpodFutureFamily`, `RiverpodStreamFamily`.
- **Views (4):** `HookView`, `StateView`, `AsyncView(atom:)`, `ObservableState`.
- **Hooks (14) + Utility (2):** `Hook`, `HookState`, `HookRef`, `HookToggle`, `HookEffect`, `HookLayoutEffect`, `AsyncHook`, `HookPrevious`, `HookInterval`, `HookMemo`, `HookCallback`, `HookReducer`, `HookContext`, `HookForm`, `Debounce(milliseconds:)`, `Throttle(milliseconds:)`.

Quy tắc: macro là "đường tắt" sinh code tương đương protocol/manual API — khi macro không đủ, dùng protocol thô ở Flow 2/3. Không import `StateKitMacrosPlugin`.

## Flow 8 — Combine bridge (StateKitCombine)

- `SKCombineAtom`, `SKCombinePublisherAtom` — atom nhận `Publisher`.
- `CancellableStore` — túi giữ `AnyCancellable` kiểu bag.
- Entry `StateKitCombine` + re-export.

## Quy ắc chọn state model (decision cho agent)

| Tình huống | Dùng | Module |
|---|---|---|
| State cục bộ 1 view | `useState`/`useReducer` + `StateView` | StateKit + StateKitUI |
| State chia sẻ, derived graph | `@StateAtom` + `useAtomState` + `SKAtomRoot` | StateKitAtoms |
| Business logic, DI, async data | `NotifierProvider`/`FutureProvider` + `@Watch` + `ProviderScope` | Riverpods |
| Cần debounce/timeout/retry | `DebouncedAction`, `Task.throwingTimeout`, `Task.retrying` | StateConcurrency |
| Lưu bền | `UserDefaultsAtom`/`KeychainStateProvider` | StateKitPersistence |
| A/B, rollout | `Rollout`, `ABTestFramework` | StateKitFeatureFlags |
| Test | `StateKitTesting` | StateKitTesting |

## Lưu ý tổng cho AI agent

1. **Chỉ import library products** liệt kê trong `Package.swift`; tránh `StateKitMacrosPlugin`.
2. `StateKit` re-export `StateKitCore` — thường chỉ cần `import StateKit` cho hooks cơ bản.
3. Cùng 1 tính năng có thể làm bằng hooks HOẶC atom HOẶC provider — hỏi hoặc theo convention project hiện có; docs tham khảo: `docs/core/GUIDE.md`, `docs/core/RIVERPOD_GUIDE.md`, `docs/macros/STATEKIT_V1_REFERENCE.md`.
4. `API_STABILITY.md` ghi trạng thái ổn định từng module — kiểm tra trước khi pin version.
5. Tests theo từng module trong `Tests/` — mẫu viết test mới nên tham khảo `Tests/StateKitTests` và `StateKitTesting`.
6. Tài liệu này sinh từ quét tĩnh declaration `public` — chữ ký member đã rút gọn; khi dùng API cụ thể, đọc file nguồn tại đường dẫn ghi trong `PUBLIC_API_INVENTORY.md` để thấy đầy đủ generics/params.
