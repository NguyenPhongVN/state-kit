# StateKit — Public API Inventory (cho AI agent code theo flow)

> Sinh tự động từ nguồn `Sources/` ngày 2026-09-22. Trừ `StateKitMacrosPlugin` (compiler plugin nội bộ, không import trực tiếp), mọi module khác đều là library product trong `Package.swift`.
> Mục đích: bản đồ API để AI agent điều hướng nhanh — "muốn X thì vào module Y, dùng symbol Z".

## Cách đọc tài liệu này

- **Type declaration** (class/struct/enum/protocol/actor/typealias): khối xây dựng chính, agent nên ưu tiên đọc file nguồn khi dùng.
- **Member declaration** (func/var/let/init): liệt kê tên + chữ ký rút gọn để tra nhanh.
- Chữ ký đã rút gọn (cắt generics/params dài), đường dẫn file relative tới `Sources/` giúp nhảy tới nguồn ngay.

## Module map (flow code thực tế)

| Module | Vai trò trong flow | Loại chính |
|---|---|---|
| `StateKitCore` | Nền runtime: mọi state chảy qua đây | class×3, enum×1 |
| `StateKit` | Hooks API — viết UI state như React | extension×11, enum×6, struct×1 |
| `StateKitUI` | Gắn hooks vào SwiftUI View | extension×9, struct×8, protocol×1 |
| `StateKitAtoms` | Global state dạng atom graph | protocol×11, class×8, struct×5 |
| `Riverpods` | Global logic + DI dạng provider | struct×23, class×15, typealias×14 |
| `StateConcurrency` | Side effects: async, retry, timeout, stream | struct×12, typealias×4, class×3 |
| `StateKitSupport` | Property wrappers & tiện ích hook | struct×13, extension×1 |
| `StateKitCombine` | Bridge sang hệ Combine cũ | extension×4, typealias×3, struct×2 |
| `StateKitPersistence` | Lưu/đọc state ra storage | struct×16, class×4, enum×3 |
| `StateKitCache` | Memoize/bộ nhớ đệm cho provider | struct×8, class×4, enum×3 |
| `StateKitAnalytics` | Theo dõi event & hành trình người dùng | struct×11, enum×4, class×3 |
| `StateKitFeatureFlags` | Bật/tắt tính năng, A/B test | struct×12, class×4, enum×3 |
| `StateKitTesting` | Test state deterministic | struct×16, class×6, actor×1 |
| `StateKitDevTools` | Debug, history, profiling | struct×10, enum×3, protocol×3 |
| `StateKitMacros` | Macro rút gọn boilerplate | macro×48 |

**Tổng: 1422 public symbol (không tính macro plugin nội bộ).**

---

## `StateKitCore`

Runtime primitives: StateContext, StateRuntime, StateSignal, StateRef — nền cho mọi module khác.

### Types

- **class `StateContext`** — `StateKitCore/ScopedState/StateContext.swift`
- **class `StateRef<T>`** — `StateKitCore/ScopedState/StateRef.swift`
- **enum `StateRuntime`** — `StateKitCore/ScopedState/StateRuntime.swift`
- **class `StateSignal<T>`** — `StateKitCore/ScopedState/StateSignal.swift`

### Members (func/var/init)

- `var states: [Any] = []` — `StateKitCore/ScopedState/StateContext.swift:30`
- `var context: [Any] = []` — `StateKitCore/ScopedState/StateContext.swift:34`
- `var injectedEnvironment: Any?` — `StateKitCore/ScopedState/StateContext.swift:44`
- `init(states: [Any] = [], index: Int = 0)` — `StateKitCore/ScopedState/StateContext.swift:71`
- `func nextIndex() -> Int` — `StateKitCore/ScopedState/StateContext.swift:82`
- `func reset()` — `StateKitCore/ScopedState/StateContext.swift:92`
- `func enqueueLayoutEffect(_ effect: @escaping () -> Void)` — `StateKitCore/ScopedState/StateContext.swift:97`
- `func enqueuePostRenderEffect(_ effect: @escaping () -> Void)` — `StateKitCore/ScopedState/StateContext.swift:102`
- `func flushLayoutEffects()` — `StateKitCore/ScopedState/StateContext.swift:107`
- `func flushPostRenderEffects()` — `StateKitCore/ScopedState/StateContext.swift:116`
- `var value: T` — `StateKitCore/ScopedState/StateRef.swift:36`
- `init(_ value: T)` — `StateKitCore/ScopedState/StateRef.swift:41`
- `subscript<Member>(dynamicMember keyPath: WritableKeyPath<T, Member>) -> Member` — `StateKitCore/ScopedState/StateRef.swift:49`
- `subscript<Member>(dynamicMember keyPath: KeyPath<T, Member>) -> Member` — `StateKitCore/ScopedState/StateRef.swift:55`
- `static var current: StateContext?` — `StateKitCore/ScopedState/StateRuntime.swift:32`
- `static func begin(_ context: StateContext)` — `StateKitCore/ScopedState/StateRuntime.swift:42`
- `static var context: StateContext` — `StateKitCore/ScopedState/StateRuntime.swift:52`
- `static func end()` — `StateKitCore/ScopedState/StateRuntime.swift:63`
- `static func stateRun<T>( context: StateContext, environment: Any? = nil, body: @MainActor () -> T` — `StateKitCore/ScopedState/StateRuntime.swift:86`
- `var value: T` — `StateKitCore/ScopedState/StateSignal.swift:35`
- `init(_ value: T)` — `StateKitCore/ScopedState/StateSignal.swift:40`
- `func _safeUpdate(to newValue: T)` — `StateKitCore/ScopedState/StateSignal.swift:48`

---

## `StateKit`

Hooks-style local state API (useState, useReducer, useEffect, useAsync...) dùng trong StateView.

### Types

- **enum `AsyncPhase<Value>`** — `StateKit/Core/StatePhases/AsyncPhase.swift`
- **extension `AsyncPhase`** — `StateKit/Core/StatePhases/AsyncPhase.swift`
- **enum `AsyncSequencePhase<Element>`** — `StateKit/Core/StatePhases/AsyncSequencePhase.swift`
- **extension `AsyncSequencePhase`** — `StateKit/Core/StatePhases/AsyncSequencePhase.swift`
- **enum `PublisherPhase<Output>`** — `StateKit/Core/StatePhases/PublisherPhase.swift`
- **extension `PublisherPhase`** — `StateKit/Core/StatePhases/PublisherPhase.swift`
- **enum `SKStatus`** — `StateKit/Core/StatePhases/SKStatus.swift`
- **enum `AsyncSequenceStatus`** — `StateKit/Core/StatePhases/SKStatus.swift`
- **enum `PublisherStatus`** — `StateKit/Core/StatePhases/SKStatus.swift`
- **extension `AsyncPhase`** — `StateKit/Core/StatePhases/StatePhase.swift`
- **extension `AsyncSequencePhase`** — `StateKit/Core/StatePhases/StatePhase.swift`
- **extension `PublisherPhase`** — `StateKit/Core/StatePhases/StatePhase.swift`
- **struct `UpdateStrategy`** — `StateKit/Core/UpdateStrategy.swift`
- **extension `UpdateStrategy`** — `StateKit/Core/UpdateStrategy.swift`
- **class `HookContext<Value>`** — `StateKit/Use/useContext.swift`

### Members (func/var/init)

- `init(_ value: any Equatable)` — `StateKit/Core/AnyEquatable.swift:30`
- `static func == (lhs: Self, rhs: Self) -> Bool` — `StateKit/Core/AnyEquatable.swift:43`
- `static func == (lhs: Self, rhs: Self) -> Bool` — `StateKit/Core/StatePhases/AsyncPhase.swift:51`
- `func hash(into hasher: inout Hasher)` — `StateKit/Core/StatePhases/AsyncPhase.swift:69`
- `static func == (lhs: Self, rhs: Self) -> Bool` — `StateKit/Core/StatePhases/AsyncSequencePhase.swift:28`
- `func hash(into hasher: inout Hasher)` — `StateKit/Core/StatePhases/AsyncSequencePhase.swift:43`
- `static func == (lhs: Self, rhs: Self) -> Bool` — `StateKit/Core/StatePhases/PublisherPhase.swift:167`
- `func hash(into hasher: inout Hasher)` — `StateKit/Core/StatePhases/PublisherPhase.swift:181`
- `let dependency: Dependency` — `StateKit/Core/UpdateStrategy.swift:19`
- `init(dependency: any Equatable)` — `StateKit/Core/UpdateStrategy.swift:30`
- `init(_ value: any Equatable)` — `StateKit/Core/UpdateStrategy.swift:181`
- `static func == (lhs: Self, rhs: Self) -> Bool` — `StateKit/Core/UpdateStrategy.swift:194`
- `func useAsync<Value>( updateStrategy: UpdateStrategy = .once, _ operation: @escaping () async throws -> Value` — `StateKit/Use/UseAsync/useAsync.swift:128`
- `func useAsyncPerform<Value>( updateStrategy: UpdateStrategy? = .once, priority: TaskPriority? = nil, _ operation: @escaping @Sendable () async throws…` — `StateKit/Use/UseAsync/useAsyncPerform.swift:81`
- `func useAsyncPerform<Value>( updateStrategy: UpdateStrategy? = .once, priority: TaskPriority? = nil, _ operation: @escaping @Sendable () async -> Val…` — `StateKit/Use/UseAsync/useAsyncPerform.swift:134`
- `func useAsyncRefresh<Value>( updateStrategy: UpdateStrategy? = .once, priority: TaskPriority? = nil, _ operation: @escaping @Sendable () async throws…` — `StateKit/Use/UseAsync/useAsyncRefresh.swift:86`
- `func useAsyncRefresh<Value>( updateStrategy: UpdateStrategy? = .once, priority: TaskPriority? = nil, _ operation: @escaping @Sendable () async -> Val…` — `StateKit/Use/UseAsync/useAsyncRefresh.swift:145`
- `func useAsyncSequence<S: AsyncSequence>( updateStrategy: UpdateStrategy = .once, _ sequence: @escaping () -> S` — `StateKit/Use/UseAsyncSequence/useAsyncSequence.swift:143`
- `func useCallback<T>( updateStrategy: UpdateStrategy? = .once, _ callback: T ) -> T` — `StateKit/Use/useCallback.swift:78`
- `var value: Value` — `StateKit/Use/useContext.swift:38`
- `init(_ value: Value)` — `StateKit/Use/useContext.swift:50`
- `func update(_ body: (inout Value) -> Void)` — `StateKit/Use/useContext.swift:56`
- `func useContext<T>( _ context: HookContext<T> ) -> T` — `StateKit/Use/useContext.swift:81`
- `@MainActor public func useEffect( updateStrategy: UpdateStrategy? = nil, _ effect: @escaping () -> (() -> Void)?` — `StateKit/Use/useEffect.swift:84`
- `@MainActor public func useEffect( updateStrategy: UpdateStrategy? = nil, effect: (() -> Void)? = nil` — `StateKit/Use/useEffect.swift:113`
- `func useEnvironment<Value>(_ keyPath: KeyPath<EnvironmentValues, Value>) -> Value` — `StateKit/Use/useEnvironment.swift:31`
- `@MainActor public func useLayoutEffect( updateStrategy: UpdateStrategy? = nil, _ effect: @escaping () -> (() -> Void)?` — `StateKit/Use/useLayoutEffect.swift:87`
- `@MainActor public func useLayoutEffect( updateStrategy: UpdateStrategy? = nil, effect: (() -> Void)? = nil` — `StateKit/Use/useLayoutEffect.swift:116`
- `func useMemo<T>( updateStrategy: UpdateStrategy? = .once, _ compute: () -> T` — `StateKit/Use/useMemo.swift:79`
- `func useOnChange<T: Equatable>( _ value: T, perform action: (T) -> Void` — `StateKit/Use/useOnChange.swift:58`
- `func useOnChange<T: Equatable>( _ value: T, perform action: (T, T) -> Void` — `StateKit/Use/useOnChange.swift:112`
- `func useOnChange<T: Equatable>( _ value: T, initial: Bool = false, perform action: (T) -> Void` — `StateKit/Use/useOnChange.swift:167`
- `func usePublisher<P: Publisher>( updateStrategy: UpdateStrategy?, _ publisher: @escaping () -> P` — `StateKit/Use/usePublisher/usePublisher.swift:125`
- `func usePublisherPerform<P: Publisher>( updateStrategy: UpdateStrategy? = .once, _ publisher: @escaping () -> P` — `StateKit/Use/usePublisher/usePublisherPerform.swift:80`
- `func usePublisherRefresh<P: Publisher>( updateStrategy: UpdateStrategy? = .once, _ publisher: @escaping () -> P` — `StateKit/Use/usePublisher/usePublisherRefresh.swift:88`
- `func useReducer<Action, State>( _ initial: State, _ reduce: @escaping (inout State, Action) -> Void` — `StateKit/Use/useReducer.swift:80`
- `func useRef<T>(_ initial: T) -> StateRef<T>` — `StateKit/Use/useRef.swift:44`
- `func useState<T>(_ initial: T) -> (T, ((T) -> Void))` — `StateKit/Use/useState.swift:80`
- `func useBinding<T>(_ initial: T) -> Binding<T>` — `StateKit/Use/useState.swift:122`

---

## `StateKitUI`

Tích hợp SwiftUI: StateScope, StateView, SKAtomRoot, phase views.

### Types

- **struct `AsyncPhaseView<Value, Success: View, Idle: View, Loading: View, Failure: View>`** — `StateKitUI/SKPhaseView/AsyncPhaseView.swift`
- **extension `AsyncPhaseView`** — `StateKitUI/SKPhaseView/AsyncPhaseView.swift`
- **struct `_DefaultLoadingView`** — `StateKitUI/SKPhaseView/AsyncPhaseView.swift`
- **struct `_DefaultFailureView`** — `StateKitUI/SKPhaseView/AsyncPhaseView.swift`
- **struct `SKStatusView<Value, Idle: View, Loading: View, Success: View, Failure: View>`** — `StateKitUI/SKPhaseView/PhaseStatusView.swift`
- **extension `SKStatusView`** — `StateKitUI/SKPhaseView/PhaseStatusView.swift`
- **struct `_DefaultStatusFailureView`** — `StateKitUI/SKPhaseView/PhaseStatusView.swift`
- **struct `StateScope<Content: View>`** — `StateKitUI/ScopedState/StateScope.swift`
- **protocol `StateView`** — `StateKitUI/ScopedState/StateView.swift`
- **extension `StateView`** — `StateKitUI/ScopedState/StateView.swift`
- **struct `SKAtomRoot<Content: View>`** — `StateKitUI/SharedState/SKAtomRoot.swift`
- **struct `SKAtomScopeView<Content: View>`** — `StateKitUI/SharedState/SKAtomScope.swift`

### Members (func/var/init)

- `init( _ phase: AsyncPhase<Value>, @ViewBuilder success: @escaping (Value) -> Success, @ViewBuilder idle: @escaping () -> Idle, @ViewBuilder loading: …` — `StateKitUI/SKPhaseView/AsyncPhaseView.swift:35`
- `var body: some View` — `StateKitUI/SKPhaseView/AsyncPhaseView.swift:49`
- `var body: some View` — `StateKitUI/SKPhaseView/AsyncPhaseView.swift:151`
- `var body: some View` — `StateKitUI/SKPhaseView/AsyncPhaseView.swift:160`
- `init( _ status: SKStatus, @ViewBuilder success: @escaping () -> Success, @ViewBuilder idle: @escaping () -> Idle, @ViewBuilder loading: @escaping () …` — `StateKitUI/SKPhaseView/PhaseStatusView.swift:38`
- `var body: some View` — `StateKitUI/SKPhaseView/PhaseStatusView.swift:52`
- `init()` — `StateKitUI/SKPhaseView/PhaseStatusView.swift:150`
- `var body: some View` — `StateKitUI/SKPhaseView/PhaseStatusView.swift:152`
- `init(@ViewBuilder content: @escaping @MainActor () -> Content)` — `StateKitUI/ScopedState/StateScope.swift:11`
- `var body: some View` — `StateKitUI/ScopedState/StateScope.swift:16`
- `init(@ViewBuilder content: () -> Content)` — `StateKitUI/SharedState/SKAtomRoot.swift:49`
- `var body: some View` — `StateKitUI/SharedState/SKAtomRoot.swift:55`
- `func atomRoot() -> some View` — `StateKitUI/SharedState/SKAtomRoot.swift:73`
- `init(@ViewBuilder content: () -> Content)` — `StateKitUI/SharedState/SKAtomScope.swift:48`
- `init(store: SKAtomStore, @ViewBuilder content: () -> Content)` — `StateKitUI/SharedState/SKAtomScope.swift:60`
- `var body: some View` — `StateKitUI/SharedState/SKAtomScope.swift:68`
- `func atomScope() -> some View` — `StateKitUI/SharedState/SKAtomScope.swift:86`
- `func atomScope(store: SKAtomStore) -> some View` — `StateKitUI/SharedState/SKAtomScope.swift:98`

---

## `StateKitAtoms`

Atom global state graph: atom protocols, store, selectors, atom hooks.

### Types

- **struct `SKAtomTransactionContext`** — `StateKitAtoms/Context/SKAtomTransactionContext.swift`
- **struct `SKAtomViewContext`** — `StateKitAtoms/Context/SKAtomViewContext.swift`
- **class `SKAtomBox<Value>`** — `StateKitAtoms/Core/SKAtomBox.swift`
- **struct `SKAtomKey`** — `StateKitAtoms/Core/SKAtomKey.swift`
- **class `SKAtomStore`** — `StateKitAtoms/Core/SKAtomStore.swift`
- **typealias `Interceptor`** — `StateKitAtoms/Core/SKAtomStore.swift`
- **class `SKSubscriberToken`** — `StateKitAtoms/Core/SKAtomStore.swift`
- **class `Box`** — `StateKitAtoms/Core/SKAtomStore.swift`
- **protocol `SKAtomEffect`** — `StateKitAtoms/Effect/SKAtomEffect.swift`
- **protocol `SKAtomWithEffect`** — `StateKitAtoms/Effect/SKAtomEffect.swift`
- **protocol `SKStateAtomWithEffect`** — `StateKitAtoms/Effect/SKAtomEffect.swift`
- **protocol `SKValueAtomWithEffect`** — `StateKitAtoms/Effect/SKAtomEffect.swift`
- **struct `SKAtomFamilyMember<ID: Hashable & Sendable, Value: Sendable>`** — `StateKitAtoms/Family/SKAtomFamily.swift`
- **struct `SKSelectorFamilyMember<ID: Hashable & Sendable, Value: Sendable>`** — `StateKitAtoms/Family/SKAtomFamily.swift`
- **protocol `SKAsyncPhaseAtom`** — `StateKitAtoms/Protocol/SKAsyncPhaseAtom.swift`
- **protocol `SKAtom`** — `StateKitAtoms/Protocol/SKAtom.swift`
- **enum `SKAtomEvictionPolicy`** — `StateKitAtoms/Protocol/SKAtom.swift`
- **protocol `SKPublisherAtom`** — `StateKitAtoms/Protocol/SKPublisherAtom.swift`
- **protocol `SKStateAtom`** — `StateKitAtoms/Protocol/SKStateAtom.swift`
- **protocol `SKTaskAtom`** — `StateKitAtoms/Protocol/SKTaskAtom.swift`
- **protocol `SKThrowingTaskAtom`** — `StateKitAtoms/Protocol/SKThrowingTaskAtom.swift`
- **protocol `SKValueAtom`** — `StateKitAtoms/Protocol/SKValueAtom.swift`
- **class `SKAsyncAtomRef<Success>`** — `StateKitAtoms/Selector/SKAsyncAtomRef.swift`
- **typealias `TaskSuccess`** — `StateKitAtoms/Selector/SKAsyncAtomRef.swift`
- **class `SKThrowingAsyncAtomRef<Success>`** — `StateKitAtoms/Selector/SKAsyncAtomRef.swift`
- **class `SKAtomRef<Value>`** — `StateKitAtoms/Selector/SKAtomRef.swift`
- **class `SKSelectorRef<Value>`** — `StateKitAtoms/Selector/SKSelectorRef.swift`
- **extension `EnvironmentValues`** — `StateKitAtoms/View/EnvironmentValues+SKAtomStore.swift`

### Members (func/var/init)

- `func watch<A: SKAtom>(_ atom: A) -> A.Value` — `StateKitAtoms/Context/SKAtomTransactionContext.swift:47`
- `func read<A: SKAtom>(_ atom: A) -> A.Value` — `StateKitAtoms/Context/SKAtomTransactionContext.swift:63`
- `func set<A: SKStateAtom>(_ value: A.Value, for atom: A)` — `StateKitAtoms/Context/SKAtomTransactionContext.swift:74`
- `func reset<A: SKStateAtom>(_ atom: A)` — `StateKitAtoms/Context/SKAtomTransactionContext.swift:81`
- `init(store: SKAtomStore)` — `StateKitAtoms/Context/SKAtomViewContext.swift:33`
- `func read<A: SKAtom>(_ atom: A) -> A.Value` — `StateKitAtoms/Context/SKAtomViewContext.swift:49`
- `func set<A: SKStateAtom>(_ value: A.Value, for atom: A)` — `StateKitAtoms/Context/SKAtomViewContext.swift:60`
- `func reset<A: SKStateAtom>(_ atom: A)` — `StateKitAtoms/Context/SKAtomViewContext.swift:67`
- `func binding<A: SKStateAtom>(for atom: A) -> Binding<A.Value>` — `StateKitAtoms/Context/SKAtomViewContext.swift:82`
- `func refresh<A: SKTaskAtom>(_ atom: A) async` — `StateKitAtoms/Context/SKAtomViewContext.swift:102`
- `func refresh<A: SKThrowingTaskAtom>(_ atom: A) async` — `StateKitAtoms/Context/SKAtomViewContext.swift:110`
- `func evict<A: SKAtom>(_ atom: A)` — `StateKitAtoms/Context/SKAtomViewContext.swift:125`
- `var value: Value` — `StateKitAtoms/Core/SKAtomBox.swift:24`
- `init(_ value: Value)` — `StateKitAtoms/Core/SKAtomBox.swift:36`
- `init<A: SKAtom>(_ atom: A)` — `StateKitAtoms/Core/SKAtomKey.swift:25`
- `static let shared = SKAtomStore()` — `StateKitAtoms/Core/SKAtomStore.swift:33`
- `func batch(_ body: () -> Void)` — `StateKitAtoms/Core/SKAtomStore.swift:82`
- `func addInterceptor(_ interceptor: @escaping Interceptor)` — `StateKitAtoms/Core/SKAtomStore.swift:101`
- `init()` — `StateKitAtoms/Core/SKAtomStore.swift:114`
- `func existingBox<Value>(for key: SKAtomKey) -> SKAtomBox<Value>?` — `StateKitAtoms/Core/SKAtomStore.swift:119`
- `func storeBox<Value>(_ box: SKAtomBox<Value>, for key: SKAtomKey)` — `StateKitAtoms/Core/SKAtomStore.swift:124`
- `func addExternalSubscriber(for key: SKAtomKey)` — `StateKitAtoms/Core/SKAtomStore.swift:151`
- `func removeExternalSubscriber(for key: SKAtomKey)` — `StateKitAtoms/Core/SKAtomStore.swift:158`
- `func addGraphDependency(from dependent: SKAtomKey, to dependency: SKAtomKey)` — `StateKitAtoms/Core/SKAtomStore.swift:196`
- `func clearGraphDependencies(of key: SKAtomKey)` — `StateKitAtoms/Core/SKAtomStore.swift:201`
- `func registerRecomputer(for key: SKAtomKey, _ body: @escaping @MainActor () -> Void)` — `StateKitAtoms/Core/SKAtomStore.swift:218`
- `func stateBox<A: SKStateAtom>(for atom: A) -> SKAtomBox<A.Value>` — `StateKitAtoms/Core/SKAtomStore.swift:239`
- `func setStateValue<A: SKStateAtom>(_ value: A.Value, for atom: A)` — `StateKitAtoms/Core/SKAtomStore.swift:255`
- `func resetStateValue<A: SKStateAtom>(for atom: A)` — `StateKitAtoms/Core/SKAtomStore.swift:264`
- `func valueBox<A: SKValueAtom>(for atom: A) -> SKAtomBox<A.Value>` — `StateKitAtoms/Core/SKAtomStore.swift:274`
- `func taskBox<A: SKTaskAtom>(for atom: A) -> SKAtomBox<A.Value>` — `StateKitAtoms/Core/SKAtomStore.swift:301`
- `func restartTask<A: SKTaskAtom>(for atom: A)` — `StateKitAtoms/Core/SKAtomStore.swift:336`
- `func refreshTask<A: SKTaskAtom>(for atom: A) async` — `StateKitAtoms/Core/SKAtomStore.swift:346`
- `func refreshThrowingTask<A: SKThrowingTaskAtom>(for atom: A) async` — `StateKitAtoms/Core/SKAtomStore.swift:408`
- `func publisherBox<A: SKPublisherAtom>(for atom: A) -> SKAtomBox<A.Value>` — `StateKitAtoms/Core/SKAtomStore.swift:421`
- `func restartPublisher<A: SKPublisherAtom>(for atom: A)` — `StateKitAtoms/Core/SKAtomStore.swift:483`
- `func evict<A: SKAtom>(_ atom: A)` — `StateKitAtoms/Core/SKAtomStore.swift:548`
- `var atomCount: Int` — `StateKitAtoms/Core/SKAtomStore.swift:566`
- `func contains<A: SKAtom>(_ atom: A) -> Bool` — `StateKitAtoms/Core/SKAtomStore.swift:570`
- `var token: SKSubscriberToken?` — `StateKitAtoms/Core/SKAtomStore.swift:588`
- `init()` — `StateKitAtoms/Core/SKAtomStore.swift:589`
- `init(store: SKAtomStore, key: SKAtomKey)` — `StateKitAtoms/Core/SKAtomStore.swift:596`
- `@MainActor public func initialized(value: Value, context: SKAtomViewContext)` — `StateKitAtoms/Effect/SKAtomEffect.swift:71`
- `@MainActor public func updated(oldValue: Value, newValue: Value, context: SKAtomViewContext)` — `StateKitAtoms/Effect/SKAtomEffect.swift:72`
- `@MainActor public func released()` — `StateKitAtoms/Effect/SKAtomEffect.swift:73`
- `func _registerEffect(in store: SKAtomStore, key: SKAtomKey)` — `StateKitAtoms/Effect/SKAtomEffect.swift:100`
- `func _registerEffect(in store: SKAtomStore, key: SKAtomKey)` — `StateKitAtoms/Effect/SKAtomEffect.swift:110`
- `func _registerEffect(in store: SKAtomStore, key: SKAtomKey)` — `StateKitAtoms/Effect/SKAtomEffect.swift:123`
- `let id: ID` — `StateKitAtoms/Family/SKAtomFamily.swift:44`
- `func defaultValue(context: SKAtomTransactionContext) -> Value` — `StateKitAtoms/Family/SKAtomFamily.swift:48`
- `static func == (lhs: Self, rhs: Self) -> Bool` — `StateKitAtoms/Family/SKAtomFamily.swift:54`
- `func hash(into hasher: inout Hasher)` — `StateKitAtoms/Family/SKAtomFamily.swift:58`
- `let id: ID` — `StateKitAtoms/Family/SKAtomFamily.swift:78`
- `func value(context: SKAtomTransactionContext) -> Value` — `StateKitAtoms/Family/SKAtomFamily.swift:82`
- `static func == (lhs: Self, rhs: Self) -> Bool` — `StateKitAtoms/Family/SKAtomFamily.swift:88`
- `func hash(into hasher: inout Hasher)` — `StateKitAtoms/Family/SKAtomFamily.swift:92`
- `func atomFamily<ID: Hashable & Sendable, Value: Sendable>( _ producer: @escaping (ID) -> Value` — `StateKitAtoms/Family/SKAtomFamily.swift:112`
- `func selectorFamily<ID: Hashable & Sendable, Value: Sendable>( _ compute: @escaping @MainActor (ID, SKAtomTransactionContext) -> Value` — `StateKitAtoms/Family/SKAtomFamily.swift:132`
- `func useAtomRefresher<A: SKTaskAtom>(_ atom: A) -> @MainActor () async -> Void` — `StateKitAtoms/Hooks/useAtomRefresher.swift:38`
- `func useAtomRefresher<A: SKThrowingTaskAtom>(_ atom: A) -> @MainActor () async -> Void` — `StateKitAtoms/Hooks/useAtomRefresher.swift:73`
- `func useAtomValue<A: SKAtom>(_ atom: A) -> A.Value` — `StateKitAtoms/Hooks/useAtomState.swift:35`
- `func useAtomState<A: SKStateAtom>(_ atom: A) -> (A.Value, (A.Value) -> Void)` — `StateKitAtoms/Hooks/useAtomState.swift:84`
- `func useAtomBinding<A: SKStateAtom>(_ atom: A) -> Binding<A.Value>` — `StateKitAtoms/Hooks/useAtomState.swift:126`
- `func useAtomReset<A: SKStateAtom>(_ atom: A) -> @MainActor () -> Void` — `StateKitAtoms/Hooks/useAtomState.swift:163`
- `var evictionPolicy: SKAtomEvictionPolicy` — `StateKitAtoms/Protocol/SKAtom.swift:93`
- `func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value>` — `StateKitAtoms/Protocol/SKPublisherAtom.swift:96`
- `func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value>` — `StateKitAtoms/Protocol/SKStateAtom.swift:46`
- `func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value>` — `StateKitAtoms/Protocol/SKTaskAtom.swift:55`
- `func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value>` — `StateKitAtoms/Protocol/SKThrowingTaskAtom.swift:50`
- `func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value>` — `StateKitAtoms/Protocol/SKValueAtom.swift:51`
- `init(_ task: @escaping @MainActor (SKAtomTransactionContext) async -> Success)` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:45`
- `func task(context: SKAtomTransactionContext) async -> Success` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:51`
- `static func == (lhs: SKAsyncAtomRef, rhs: SKAsyncAtomRef) -> Bool` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:57`
- `func hash(into hasher: inout Hasher)` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:61`
- `init(_ task: @escaping @MainActor (SKAtomTransactionContext) async throws -> Success)` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:84`
- `func task(context: SKAtomTransactionContext) async throws -> Success` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:90`
- `static func == (lhs: SKThrowingAsyncAtomRef, rhs: SKThrowingAsyncAtomRef) -> Bool` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:96`
- `func hash(into hasher: inout Hasher)` — `StateKitAtoms/Selector/SKAsyncAtomRef.swift:100`
- `init(_ defaultValue: @escaping @MainActor () -> Value)` — `StateKitAtoms/Selector/SKAtomRef.swift:40`
- `func defaultValue(context: SKAtomTransactionContext) -> Value` — `StateKitAtoms/Selector/SKAtomRef.swift:46`
- `static func == (lhs: SKAtomRef, rhs: SKAtomRef) -> Bool` — `StateKitAtoms/Selector/SKAtomRef.swift:52`
- `func hash(into hasher: inout Hasher)` — `StateKitAtoms/Selector/SKAtomRef.swift:56`
- `init(_ compute: @escaping @MainActor (SKAtomTransactionContext) -> Value)` — `StateKitAtoms/Selector/SKSelectorRef.swift:36`
- `func value(context: SKAtomTransactionContext) -> Value` — `StateKitAtoms/Selector/SKSelectorRef.swift:42`
- `static func == (lhs: SKSelectorRef, rhs: SKSelectorRef) -> Bool` — `StateKitAtoms/Selector/SKSelectorRef.swift:48`
- `func hash(into hasher: inout Hasher)` — `StateKitAtoms/Selector/SKSelectorRef.swift:52`
- `func atom<Value>( _ defaultValue: @escaping @autoclosure @MainActor () -> Value` — `StateKitAtoms/Selector/SKSelectors.swift:39`
- `func selector<Value>( _ compute: @escaping @MainActor (SKAtomTransactionContext) -> Value` — `StateKitAtoms/Selector/SKSelectors.swift:60`
- `func asyncAtom<Success>( _ task: @escaping @MainActor (SKAtomTransactionContext) async -> Success` — `StateKitAtoms/Selector/SKSelectors.swift:82`
- `func throwingAsyncAtom<Success>( _ task: @escaping @MainActor (SKAtomTransactionContext) async throws -> Success` — `StateKitAtoms/Selector/SKSelectors.swift:103`

---

## `Riverpods`

Provider container kiểu Riverpod: Notifier/Provider, families, overrides, SwiftUI wrappers.

### Types

- **protocol `ComposableNotifier`** — `Riverpods/Composition/NotifierComposition.swift`
- **struct `StateComposer<Root: Sendable>`** — `Riverpods/Composition/NotifierComposition.swift`
- **struct `StateMutationHelper`** — `Riverpods/Composition/NotifierComposition.swift`
- **protocol `ScopeComposable`** — `Riverpods/Composition/NotifierComposition.swift`
- **protocol `ActionRoutable`** — `Riverpods/Composition/NotifierComposition.swift`
- **struct `CompositionDebugger`** — `Riverpods/Composition/NotifierComposition.swift`
- **struct `CompositionMetadata`** — `Riverpods/Composition/NotifierComposition.swift`
- **enum `CompositionStrategy`** — `Riverpods/Composition/NotifierComposition.swift`
- **class `ProviderContainer`** — `Riverpods/Container/ProviderContainer.swift`
- **class `ProviderSubscription`** — `Riverpods/Container/ProviderContainer.swift`
- **class `StateBox<T>`** — `Riverpods/Container/ProviderElement.swift`
- **protocol `ProviderObserver`** — `Riverpods/Container/ProviderObserver.swift`
- **protocol `AnyProviderElement`** — `Riverpods/Core/AnyProviderElement.swift`
- **enum `AsyncValue<T: Sendable>`** — `Riverpods/Core/AsyncValue.swift`
- **struct `RiverpodAtom<P: ProviderProtocol>`** — `Riverpods/Core/EcosystemBridge.swift`
- **typealias `Value`** — `Riverpods/Core/EcosystemBridge.swift`
- **struct `ProviderID`** — `Riverpods/Core/ProviderID.swift`
- **protocol `ProviderProtocol`** — `Riverpods/Core/ProviderProtocol.swift`
- **struct `ProviderOverride`** — `Riverpods/Core/ProviderProtocol.swift`
- **struct `SelectorProvider<P: ProviderProtocol, Selected: Sendable & Hashable>`** — `Riverpods/Core/ProviderProtocol.swift`
- **typealias `State`** — `Riverpods/Core/ProviderProtocol.swift`
- **class `SelectorProviderElement<P: ProviderProtocol, Selected: Sendable & Hashable>`** — `Riverpods/Core/ProviderProtocol.swift`
- **protocol `ProviderRef`** — `Riverpods/Core/ProviderRef.swift`
- **class `KeepAliveLink`** — `Riverpods/Core/ProviderRef.swift`
- **enum `RProvider`** — `Riverpods/Core/RProvider.swift`
- **class `AsyncNotifierProviderElement<N: AsyncNotifier<T>`** — `Riverpods/Providers/AsyncNotifierProvider.swift`
- **struct `AsyncNotifierProvider<N: AsyncNotifier<T>`** — `Riverpods/Providers/AsyncNotifierProvider.swift`
- **typealias `State`** — `Riverpods/Providers/AsyncNotifierProvider.swift`
- **struct `AsyncNotifierInstanceProvider<N: AsyncNotifier<T>`** — `Riverpods/Providers/AsyncNotifierProvider.swift`
- **class `AsyncNotifierInstanceElement<N: AsyncNotifier<T>`** — `Riverpods/Providers/AsyncNotifierProvider.swift`
- **struct `AsyncNotifierFutureProvider<N: AsyncNotifier<T>`** — `Riverpods/Providers/AsyncNotifierProvider.swift`
- **class `AsyncSequenceProviderElement<T: Sendable, S: AsyncSequence>`** — `Riverpods/Providers/AsyncSequenceProvider.swift`
- **struct `AsyncSequenceProvider<T: Sendable, S: AsyncSequence>`** — `Riverpods/Providers/AsyncSequenceProvider.swift`
- **typealias `State`** — `Riverpods/Providers/AsyncSequenceProvider.swift`
- **class `FutureProviderElement<T: Sendable>`** — `Riverpods/Providers/FutureProvider.swift`
- **struct `FutureProvider<T: Sendable>`** — `Riverpods/Providers/FutureProvider.swift`
- **typealias `State`** — `Riverpods/Providers/FutureProvider.swift`
- **struct `FutureFutureProvider<T: Sendable>`** — `Riverpods/Providers/FutureProvider.swift`
- **class `NotifierProviderElement<N: Notifier<T>`** — `Riverpods/Providers/NotifierProvider.swift`
- **class `NotifierInstanceElement<N: Notifier<T>`** — `Riverpods/Providers/NotifierProvider.swift`
- **struct `NotifierProvider<N: Notifier<T>`** — `Riverpods/Providers/NotifierProvider.swift`
- **typealias `State`** — `Riverpods/Providers/NotifierProvider.swift`
- **struct `NotifierInstanceProvider<N: Notifier<T>`** — `Riverpods/Providers/NotifierProvider.swift`
- **class `SimpleProviderElement<P: ProviderProtocol>`** — `Riverpods/Providers/Provider.swift`
- **struct `Provider<T: Sendable>`** — `Riverpods/Providers/Provider.swift`
- **typealias `State`** — `Riverpods/Providers/Provider.swift`
- **class `StateProviderElement<T: Sendable>`** — `Riverpods/Providers/StateProvider.swift`
- **struct `StateProvider<T: Sendable>`** — `Riverpods/Providers/StateProvider.swift`
- **typealias `State`** — `Riverpods/Providers/StateProvider.swift`
- **struct `StateProviderNotifier<T: Sendable>`** — `Riverpods/Providers/StateProvider.swift`
- **class `StateController<T: Sendable>`** — `Riverpods/Providers/StateProvider.swift`
- **class `StreamProviderElement<T: Sendable>`** — `Riverpods/Providers/StreamProvider.swift`
- **struct `StreamProvider<T: Sendable>`** — `Riverpods/Providers/StreamProvider.swift`
- **typealias `State`** — `Riverpods/Providers/StreamProvider.swift`
- **struct `ProviderScope<Content: View>`** — `Riverpods/SwiftUI/ProviderScope.swift`
- **struct `Read<P: ProviderProtocol>`** — `Riverpods/SwiftUI/Read.swift`
- **struct `Watch<P: ProviderProtocol>`** — `Riverpods/SwiftUI/Watch.swift`
- **extension `EnvironmentValues`** — `Riverpods/SwiftUI/Watch.swift`

### Members (func/var/init)

- `init(_ root: Root)` — `Riverpods/Composition/NotifierComposition.swift:73`
- `func set<Value: Sendable>(_ keyPath: WritableKeyPath<Root, Value>, to value: Value) -> Self` — `Riverpods/Composition/NotifierComposition.swift:83`
- `func build() -> Root` — `Riverpods/Composition/NotifierComposition.swift:90`
- `static func compose<P1: ProviderProtocol, P2: ProviderProtocol, Result: Sendable>( _ p1: P1, _ p2: P2, transform: @escaping @Sendable (P1.State, P2.S…` — `Riverpods/Composition/NotifierComposition.swift:115`
- `static func compose< P1: ProviderProtocol, P2: ProviderProtocol, P3: ProviderProtocol, Result: Sendable >(` — `Riverpods/Composition/NotifierComposition.swift:128`
- `static func compose< P1: ProviderProtocol, P2: ProviderProtocol, P3: ProviderProtocol, P4: ProviderProtocol, Result: Sendable` — `Riverpods/Composition/NotifierComposition.swift:148`
- `static func compose< P1: ProviderProtocol, P2: ProviderProtocol, P3: ProviderProtocol, P4: ProviderProtocol, P5: ProviderProtocol,` — `Riverpods/Composition/NotifierComposition.swift:171`
- `static func update<Root: Sendable, Value: Sendable>( _ state: inout Root, _ keyPath: WritableKeyPath<Root, Value>, _ transform: (inout Value) -> Void` — `Riverpods/Composition/NotifierComposition.swift:216`
- `static func updateIf<Root: Sendable, Value: Sendable>( _ state: inout Root, _ keyPath: WritableKeyPath<Root, Value>, when predicate: (Value) -> Bool,…` — `Riverpods/Composition/NotifierComposition.swift:237`
- `static func batch<Root: Sendable>( _ state: inout Root, _ updates: (inout Root) -> Void` — `Riverpods/Composition/NotifierComposition.swift:263`
- `static func logStateChange<State: CustomStringConvertible>( scope: String, oldState: State, newState: State, action: String? = nil )` — `Riverpods/Composition/NotifierComposition.swift:366`
- `static func logActionRoute( from: String, to: String, action: String )` — `Riverpods/Composition/NotifierComposition.swift:388`
- `static func logLifecycleEvent( scope: String, event: String )` — `Riverpods/Composition/NotifierComposition.swift:401`
- `let domains: [String]` — `Riverpods/Composition/NotifierComposition.swift:423`
- `let debugEnabled: Bool` — `Riverpods/Composition/NotifierComposition.swift:426`
- `let strategy: CompositionStrategy` — `Riverpods/Composition/NotifierComposition.swift:429`
- `init( domains: [String], debugEnabled: Bool = false, strategy: CompositionStrategy = .hierarchical )` — `Riverpods/Composition/NotifierComposition.swift:443`
- `static let shared = ProviderContainer()` — `Riverpods/Container/ProviderContainer.swift:74`
- `let parent: ProviderContainer?` — `Riverpods/Container/ProviderContainer.swift:82`
- `init( parent: ProviderContainer? = nil, overrides: [ProviderOverride] = [], observers: [ProviderObserver] = [] )` — `Riverpods/Container/ProviderContainer.swift:129`
- `func addObserver(_ observer: ProviderObserver)` — `Riverpods/Container/ProviderContainer.swift:156`
- `func ensureElement<P: ProviderProtocol>(for provider: P) -> AnyProviderElement` — `Riverpods/Container/ProviderContainer.swift:184`
- `func refresh<P: ProviderProtocol>(_ provider: P) -> P.State` — `Riverpods/Container/ProviderContainer.swift:237`
- `func read<P: ProviderProtocol>(_ provider: P) -> P.State` — `Riverpods/Container/ProviderContainer.swift:254`
- `func watch<P: ProviderProtocol>(_ provider: P) -> P.State` — `Riverpods/Container/ProviderContainer.swift:266`
- `func listen<P: ProviderProtocol>( _ provider: P, fireImmediately: Bool = false, listener: @escaping (P.State?, P.State) -> Void` — `Riverpods/Container/ProviderContainer.swift:292`
- `func addListener<P: ProviderProtocol>(for provider: P) -> P.State` — `Riverpods/Container/ProviderContainer.swift:308`
- `func removeListener<P: ProviderProtocol>(for provider: P)` — `Riverpods/Container/ProviderContainer.swift:326`
- `func batch(_ body: () -> Void)` — `Riverpods/Container/ProviderContainer.swift:533`
- `func close()` — `Riverpods/Container/ProviderContainer.swift:716`
- `let provider: P` — `Riverpods/Container/ProviderElement.swift:24`
- `let container: ProviderContainer` — `Riverpods/Container/ProviderElement.swift:27`
- `let id: ProviderID` — `Riverpods/Container/ProviderElement.swift:30`
- `var stateBox: StateBox<P.State>?` — `Riverpods/Container/ProviderElement.swift:36`
- `var dependents: Set<ProviderID> = []` — `Riverpods/Container/ProviderElement.swift:53`
- `var isKeepAlive: Bool` — `Riverpods/Container/ProviderElement.swift:67`
- `func incrementListeners()` — `Riverpods/Container/ProviderElement.swift:71`
- `func decrementListeners()` — `Riverpods/Container/ProviderElement.swift:79`
- `init(provider: P, container: ProviderContainer)` — `Riverpods/Container/ProviderElement.swift:122`
- `func getState() -> P.State` — `Riverpods/Container/ProviderElement.swift:138`
- `func invalidate()` — `Riverpods/Container/ProviderElement.swift:237`
- `func performUpdate()` — `Riverpods/Container/ProviderElement.swift:245`
- `func notifyDependents()` — `Riverpods/Container/ProviderElement.swift:251`
- `func dispose()` — `Riverpods/Container/ProviderElement.swift:273`
- `func watch<Dep: ProviderProtocol>(_ depProvider: Dep) -> Dep.State` — `Riverpods/Container/ProviderElement.swift:307`
- `func _addDependentRef(_ element: AnyObject)` — `Riverpods/Container/ProviderElement.swift:318`
- `func read<Dep: ProviderProtocol>(_ depProvider: Dep) -> Dep.State` — `Riverpods/Container/ProviderElement.swift:323`
- `func listen<Dep: ProviderProtocol>( _ depProvider: Dep, fireImmediately: Bool = false, listener: @escaping (Dep.State?, Dep.State) -> Void` — `Riverpods/Container/ProviderElement.swift:327`
- `func onDispose(_ cleanup: @escaping () -> Void)` — `Riverpods/Container/ProviderElement.swift:336`
- `func onCancel(_ callback: @escaping () -> Void)` — `Riverpods/Container/ProviderElement.swift:337`
- `func onResume(_ callback: @escaping () -> Void)` — `Riverpods/Container/ProviderElement.swift:338`
- `func onAddListener(_ callback: @escaping () -> Void)` — `Riverpods/Container/ProviderElement.swift:339`
- `func onRemoveListener(_ callback: @escaping () -> Void)` — `Riverpods/Container/ProviderElement.swift:340`
- `func keepAlive() -> KeepAliveLink` — `Riverpods/Container/ProviderElement.swift:342`
- `var value: T` — `Riverpods/Container/ProviderElement.swift:406`
- `init(_ value: T)` — `Riverpods/Container/ProviderElement.swift:411`
- `func didAddProvider<P: ProviderProtocol>( _ provider: P, value: P.State, container: ProviderContainer )` — `Riverpods/Container/ProviderObserver.swift:357`
- `func didUpdateProvider<P: ProviderProtocol>( _ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer )` — `Riverpods/Container/ProviderObserver.swift:366`
- `func didDisposeProvider<P: ProviderProtocol>( _ provider: P, container: ProviderContainer )` — `Riverpods/Container/ProviderObserver.swift:376`
- `var value: T?` — `Riverpods/Core/AsyncValue.swift:77`
- `var error: Error?` — `Riverpods/Core/AsyncValue.swift:97`
- `var isLoading: Bool` — `Riverpods/Core/AsyncValue.swift:112`
- `var isRefreshing: Bool` — `Riverpods/Core/AsyncValue.swift:132`
- `var hasValue: Bool` — `Riverpods/Core/AsyncValue.swift:147`
- `func when<Result>( data: (T) -> Result, error: (Error, T?) -> Result, loading: (T?) -> Result` — `Riverpods/Core/AsyncValue.swift:172`
- `func map<U>(_ transform: (T) -> U) -> AsyncValue<U>` — `Riverpods/Core/AsyncValue.swift:202`
- `static func `guard`(_ action: @escaping () async throws -> T) async -> AsyncValue<T>` — `Riverpods/Core/AsyncValue.swift:229`
- `func unwrap() throws -> T` — `Riverpods/Core/AsyncValue.swift:255`
- `func update(_ transform: (T) -> T) -> AsyncValue<T>` — `Riverpods/Core/AsyncValue.swift:280`
- `func watch<A: SKAtom>(_ atom: A) -> A.Value` — `Riverpods/Core/EcosystemBridge.swift:90`
- `let provider: P` — `Riverpods/Core/EcosystemBridge.swift:175`
- `let container: ProviderContainer` — `Riverpods/Core/EcosystemBridge.swift:181`
- `init(_ provider: P, container: ProviderContainer = .shared)` — `Riverpods/Core/EcosystemBridge.swift:199`
- `func value(context: SKAtomTransactionContext) -> P.State` — `Riverpods/Core/EcosystemBridge.swift:216`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Core/EcosystemBridge.swift:226`
- `static func == (lhs: RiverpodAtom, rhs: RiverpodAtom) -> Bool` — `Riverpods/Core/EcosystemBridge.swift:231`
- `func asAtom(in container: ProviderContainer = .shared) -> RiverpodAtom<Self>` — `Riverpods/Core/EcosystemBridge.swift:284`
- `init<P: ProviderProtocol>(_ provider: P)` — `Riverpods/Core/ProviderID.swift:47`
- `init(identifier: AnyHashable, name: String? = nil)` — `Riverpods/Core/ProviderID.swift:65`
- `var description: String` — `Riverpods/Core/ProviderID.swift:80`
- `var autoDispose: Bool` — `Riverpods/Core/ProviderProtocol.swift:132`
- `var cacheTime: TimeInterval` — `Riverpods/Core/ProviderProtocol.swift:135`
- `var name: String?` — `Riverpods/Core/ProviderProtocol.swift:138`
- `func overrideWith(_ value: State) -> ProviderOverride` — `Riverpods/Core/ProviderProtocol.swift:164`
- `func overrideWithProvider<P: ProviderProtocol>(_ provider: P) -> ProviderOverride where P.State == State` — `Riverpods/Core/ProviderProtocol.swift:186`
- `func select<Selected: Sendable & Hashable>( _ keyPath: KeyPath<State, Selected> ) -> SelectorProvider<Self, Selected>` — `Riverpods/Core/ProviderProtocol.swift:228`
- `let provider: P` — `Riverpods/Core/ProviderProtocol.swift:305`
- `let keyPath: KeyPath<P.State, Selected>` — `Riverpods/Core/ProviderProtocol.swift:308`
- `var autoDispose: Bool` — `Riverpods/Core/ProviderProtocol.swift:313`
- `init(provider: P, keyPath: KeyPath<P.State, Selected>)` — `Riverpods/Core/ProviderProtocol.swift:322`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Core/ProviderProtocol.swift:331`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Core/ProviderProtocol.swift:338`
- `static func == (lhs: SelectorProvider, rhs: SelectorProvider) -> Bool` — `Riverpods/Core/ProviderProtocol.swift:344`
- `override func providerCreate() -> Selected` — `Riverpods/Core/ProviderProtocol.swift:382`
- `override func performUpdate()` — `Riverpods/Core/ProviderProtocol.swift:395`
- `func close()` — `Riverpods/Core/ProviderRef.swift:359`
- `var state: AsyncValue<State>` — `Riverpods/Providers/AsyncNotifierProvider.swift:142`
- `var future: State` — `Riverpods/Providers/AsyncNotifierProvider.swift:181`
- `init()` — `Riverpods/Providers/AsyncNotifierProvider.swift:208`
- `func update(_ transform: (State) -> State)` — `Riverpods/Providers/AsyncNotifierProvider.swift:321`
- `var notifier: N?` — `Riverpods/Providers/AsyncNotifierProvider.swift:356`
- `override func providerCreate() -> AsyncValue<T>` — `Riverpods/Providers/AsyncNotifierProvider.swift:372`
- `override func dispose()` — `Riverpods/Providers/AsyncNotifierProvider.swift:397`
- `let autoDispose: Bool` — `Riverpods/Providers/AsyncNotifierProvider.swift:537`
- `let cacheTime: TimeInterval` — `Riverpods/Providers/AsyncNotifierProvider.swift:540`
- `let name: String?` — `Riverpods/Providers/AsyncNotifierProvider.swift:543`
- `init( autoDispose: Bool = true, cacheTime: TimeInterval = 0, name: String? = nil, _ create: @escaping @MainActor () -> N` — `Riverpods/Providers/AsyncNotifierProvider.swift:561`
- `var future: AsyncNotifierFutureProvider<N, T>` — `Riverpods/Providers/AsyncNotifierProvider.swift:589`
- `var notifier: AsyncNotifierInstanceProvider<N, T>` — `Riverpods/Providers/AsyncNotifierProvider.swift:611`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/AsyncNotifierProvider.swift:627`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/AsyncNotifierProvider.swift:632`
- `static func == (lhs: AsyncNotifierProvider, rhs: AsyncNotifierProvider) -> Bool` — `Riverpods/Providers/AsyncNotifierProvider.swift:637`
- `let provider: AsyncNotifierProvider<N, T>` — `Riverpods/Providers/AsyncNotifierProvider.swift:673`
- `var autoDispose: Bool` — `Riverpods/Providers/AsyncNotifierProvider.swift:676`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/AsyncNotifierProvider.swift:690`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/AsyncNotifierProvider.swift:695`
- `static func == (lhs: AsyncNotifierInstanceProvider, rhs: AsyncNotifierInstanceProvider) -> Bool` — `Riverpods/Providers/AsyncNotifierProvider.swift:700`
- `override func providerCreate() -> N` — `Riverpods/Providers/AsyncNotifierProvider.swift:725`
- `let provider: AsyncNotifierProvider<N, T>` — `Riverpods/Providers/AsyncNotifierProvider.swift:759`
- `var autoDispose: Bool` — `Riverpods/Providers/AsyncNotifierProvider.swift:762`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/AsyncNotifierProvider.swift:767`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/AsyncNotifierProvider.swift:772`
- `static func == (lhs: AsyncNotifierFutureProvider, rhs: AsyncNotifierFutureProvider) -> Bool` — `Riverpods/Providers/AsyncNotifierProvider.swift:777`
- `override func providerCreate() -> AsyncValue<T>` — `Riverpods/Providers/AsyncSequenceProvider.swift:48`
- `let autoDispose: Bool` — `Riverpods/Providers/AsyncSequenceProvider.swift:224`
- `let cacheTime: TimeInterval` — `Riverpods/Providers/AsyncSequenceProvider.swift:227`
- `let name: String?` — `Riverpods/Providers/AsyncSequenceProvider.swift:230`
- `init( autoDispose: Bool = true, cacheTime: TimeInterval = 0, name: String? = nil, _ create: @escaping @MainActor (ProviderRef) -> S` — `Riverpods/Providers/AsyncSequenceProvider.swift:257`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/AsyncSequenceProvider.swift:285`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/AsyncSequenceProvider.swift:290`
- `static func == (lhs: AsyncSequenceProvider, rhs: AsyncSequenceProvider) -> Bool` — `Riverpods/Providers/AsyncSequenceProvider.swift:295`
- `static func family<Arg: Hashable & Sendable>( autoDispose: Bool = true, _ factory: @MainActor @escaping (ProviderRef, Arg) -> T` — `Riverpods/Providers/Family.swift:136`
- `static func family<Arg: Hashable & Sendable>( autoDispose: Bool = true, _ factory: @MainActor @escaping (ProviderRef, Arg) -> T` — `Riverpods/Providers/Family.swift:202`
- `static func family<Arg: Hashable & Sendable>( autoDispose: Bool = true, _ factory: @MainActor @escaping (Arg) -> N` — `Riverpods/Providers/Family.swift:295`
- `static func family<Arg: Hashable & Sendable>( autoDispose: Bool = true, _ factory: @MainActor @escaping (ProviderRef, Arg) async throws -> T` — `Riverpods/Providers/Family.swift:357`
- `static func family<Arg: Hashable & Sendable>( autoDispose: Bool = true, _ factory: @MainActor @escaping (ProviderRef, Arg) -> AnyPublisher<T, Error>` — `Riverpods/Providers/Family.swift:421`
- `override func providerCreate() -> AsyncValue<T>` — `Riverpods/Providers/FutureProvider.swift:49`
- `let autoDispose: Bool` — `Riverpods/Providers/FutureProvider.swift:258`
- `let cacheTime: TimeInterval` — `Riverpods/Providers/FutureProvider.swift:261`
- `let name: String?` — `Riverpods/Providers/FutureProvider.swift:264`
- `init( autoDispose: Bool = true, cacheTime: TimeInterval = 0, name: String? = nil, _ create: @escaping @MainActor (ProviderRef) async throws -> T` — `Riverpods/Providers/FutureProvider.swift:285`
- `var future: FutureFutureProvider<T>` — `Riverpods/Providers/FutureProvider.swift:340`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/FutureProvider.swift:360`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/FutureProvider.swift:365`
- `static func == (lhs: FutureProvider, rhs: FutureProvider) -> Bool` — `Riverpods/Providers/FutureProvider.swift:370`
- `let provider: FutureProvider<T>` — `Riverpods/Providers/FutureProvider.swift:423`
- `var autoDispose: Bool` — `Riverpods/Providers/FutureProvider.swift:426`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/FutureProvider.swift:431`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/FutureProvider.swift:436`
- `static func == (lhs: FutureFutureProvider, rhs: FutureFutureProvider) -> Bool` — `Riverpods/Providers/FutureProvider.swift:441`
- `var state: State` — `Riverpods/Providers/NotifierProvider.swift:106`
- `init()` — `Riverpods/Providers/NotifierProvider.swift:121`
- `func update(_ transform: (State) -> State)` — `Riverpods/Providers/NotifierProvider.swift:219`
- `var notifier: N?` — `Riverpods/Providers/NotifierProvider.swift:254`
- `override func providerCreate() -> T` — `Riverpods/Providers/NotifierProvider.swift:270`
- `override func dispose()` — `Riverpods/Providers/NotifierProvider.swift:294`
- `override func providerCreate() -> N` — `Riverpods/Providers/NotifierProvider.swift:320`
- `let autoDispose: Bool` — `Riverpods/Providers/NotifierProvider.swift:463`
- `let cacheTime: TimeInterval` — `Riverpods/Providers/NotifierProvider.swift:466`
- `let name: String?` — `Riverpods/Providers/NotifierProvider.swift:469`
- `init( autoDispose: Bool = true, cacheTime: TimeInterval = 0, name: String? = nil, _ create: @escaping @MainActor () -> N` — `Riverpods/Providers/NotifierProvider.swift:497`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/NotifierProvider.swift:538`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/NotifierProvider.swift:543`
- `static func == (lhs: NotifierProvider, rhs: NotifierProvider) -> Bool` — `Riverpods/Providers/NotifierProvider.swift:548`
- `var notifier: NotifierInstanceProvider<N, T>` — `Riverpods/Providers/NotifierProvider.swift:571`
- `var autoDispose: Bool` — `Riverpods/Providers/NotifierProvider.swift:631`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/NotifierProvider.swift:637`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/NotifierProvider.swift:642`
- `static func == (lhs: NotifierInstanceProvider, rhs: NotifierInstanceProvider) -> Bool` — `Riverpods/Providers/NotifierProvider.swift:648`
- `init( provider: P, container: ProviderContainer, create: @escaping (ProviderRef) -> P.State` — `Riverpods/Providers/Provider.swift:28`
- `override func providerCreate() -> P.State` — `Riverpods/Providers/Provider.swift:44`
- `let autoDispose: Bool` — `Riverpods/Providers/Provider.swift:134`
- `let cacheTime: TimeInterval` — `Riverpods/Providers/Provider.swift:139`
- `let name: String?` — `Riverpods/Providers/Provider.swift:143`
- `init( autoDispose: Bool = true, cacheTime: TimeInterval = 0, name: String? = nil, _ create: @escaping @MainActor (ProviderRef) -> T` — `Riverpods/Providers/Provider.swift:166`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/Provider.swift:204`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/Provider.swift:211`
- `static func == (lhs: Provider, rhs: Provider) -> Bool` — `Riverpods/Providers/Provider.swift:219`
- `override func providerCreate() -> T` — `Riverpods/Providers/StateProvider.swift:34`
- `let autoDispose: Bool` — `Riverpods/Providers/StateProvider.swift:178`
- `let cacheTime: TimeInterval` — `Riverpods/Providers/StateProvider.swift:181`
- `let name: String?` — `Riverpods/Providers/StateProvider.swift:184`
- `init( autoDispose: Bool = true, cacheTime: TimeInterval = 0, name: String? = nil, _ defaultValue: @escaping @MainActor (ProviderRef) -> T` — `Riverpods/Providers/StateProvider.swift:215`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/StateProvider.swift:248`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/StateProvider.swift:259`
- `static func == (lhs: StateProvider, rhs: StateProvider) -> Bool` — `Riverpods/Providers/StateProvider.swift:264`
- `var notifier: StateProviderNotifier<T>` — `Riverpods/Providers/StateProvider.swift:287`
- `var autoDispose: Bool` — `Riverpods/Providers/StateProvider.swift:354`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/StateProvider.swift:360`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/StateProvider.swift:374`
- `static func == (lhs: StateProviderNotifier, rhs: StateProviderNotifier) -> Bool` — `Riverpods/Providers/StateProvider.swift:380`
- `var state: T` — `Riverpods/Providers/StateProvider.swift:481`
- `override func providerCreate() -> AsyncValue<T>` — `Riverpods/Providers/StreamProvider.swift:42`
- `let autoDispose: Bool` — `Riverpods/Providers/StreamProvider.swift:219`
- `let cacheTime: TimeInterval` — `Riverpods/Providers/StreamProvider.swift:222`
- `let name: String?` — `Riverpods/Providers/StreamProvider.swift:225`
- `init( autoDispose: Bool = true, cacheTime: TimeInterval = 0, name: String? = nil, _ create: @escaping @MainActor (ProviderRef) -> AnyPublisher<T, Err…` — `Riverpods/Providers/StreamProvider.swift:249`
- `func createElement(container: ProviderContainer) -> AnyProviderElement` — `Riverpods/Providers/StreamProvider.swift:293`
- `func hash(into hasher: inout Hasher)` — `Riverpods/Providers/StreamProvider.swift:298`
- `static func == (lhs: StreamProvider, rhs: StreamProvider) -> Bool` — `Riverpods/Providers/StreamProvider.swift:303`
- `init(overrides: [ProviderOverride] = [], @ViewBuilder content: () -> Content)` — `Riverpods/SwiftUI/ProviderScope.swift:171`
- `init(container: ProviderContainer, @ViewBuilder content: () -> Content)` — `Riverpods/SwiftUI/ProviderScope.swift:210`
- `var body: some View` — `Riverpods/SwiftUI/ProviderScope.swift:221`
- `init(_ provider: P)` — `Riverpods/SwiftUI/Read.swift:139`
- `var wrappedValue: P.State` — `Riverpods/SwiftUI/Read.swift:161`
- `init(_ provider: P)` — `Riverpods/SwiftUI/Watch.swift:136`
- `var wrappedValue: P.State` — `Riverpods/SwiftUI/Watch.swift:155`
- `func useRiverpod<P: ProviderProtocol>(_ provider: P) -> P.State` — `Riverpods/SwiftUI/Watch.swift:322`

---

## `StateConcurrency`

Task helpers (retry/timeout/gather/race/debounce/throttle) + async streams.

### Types

- **class `DebouncedAction<each Input: Sendable>`** — `StateConcurrency/Actions/DebouncedAction.swift`
- **class `ThrottledAction<each Input: Sendable>`** — `StateConcurrency/Actions/ThrottledAction.swift`
- **struct `AnyAsyncSequence<Element>`** — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift`
- **struct `AnyAsyncIterator`** — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift`
- **typealias `Element`** — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift`
- **typealias `AsyncIterator`** — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift`
- **extension `AsyncSequence`** — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift`
- **struct `AsyncCurrentValueStream<Element: Sendable>`** — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift`
- **struct `Iterator`** — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift`
- **struct `AsyncPassthroughStream<Element: Sendable>`** — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift`
- **struct `Iterator`** — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift`
- **struct `AsyncValueStream<Element: Sendable>`** — `StateConcurrency/SCAsyncSequence/AsyncValueStream.swift`
- **class `ObservableTask<Success: Sendable, Failure: Error>`** — `StateConcurrency/SCTask/Objects/ObservableTask.swift`
- **enum `State`** — `StateConcurrency/SCTask/Objects/ObservableTask.swift`
- **actor `SCConcurrencyLimiter`** — `StateConcurrency/SCTask/Objects/SCConcurrencyLimiter.swift`
- **actor `SCLocalActor`** — `StateConcurrency/SCTask/Objects/SCLocalActor.swift`
- **enum `SCRetryPolicy`** — `StateConcurrency/SCTask/Objects/SCRetryPolicy.swift`
- **enum `SCTaskDuration`** — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift`
- **struct `SCTimeoutError`** — `StateConcurrency/SCTask/Objects/TimeoutError.swift`
- **struct `AsyncThrowingTimeoutSequence<Base: AsyncSequence & Sendable>`** — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift`
- **typealias `Element`** — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift`
- **struct `Iterator`** — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift`
- **struct `AsyncDebounceSequence<Base: AsyncSequence & Sendable>`** — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift`

### Members (func/var/init)

- `init(interval: Duration, operation: @escaping @Sendable (repeat each Input) async -> Void)` — `StateConcurrency/Actions/DebouncedAction.swift:31`
- `func callAsFunction(_ args: repeat each Input)` — `StateConcurrency/Actions/DebouncedAction.swift:38`
- `init(interval: Duration, operation: @escaping @Sendable (repeat each Input) async -> Void)` — `StateConcurrency/Actions/ThrottledAction.swift:32`
- `func callAsFunction(_ args: repeat each Input)` — `StateConcurrency/Actions/ThrottledAction.swift:39`
- `init<T: AsyncSequence>(_ sequence: T) where T.Element == Element` — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift:13`
- `init<T: AsyncIteratorProtocol>(_ iterator: T) where T.Element == Element` — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift:20`
- `func next() async throws -> Element?` — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift:25`
- `func makeAsyncIterator() -> AsyncIterator` — `StateConcurrency/SCAsyncSequence/AnyAsyncSequence.swift:36`
- `var value: Element` — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift:36`
- `init(_ value: Element)` — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift:43`
- `func send(_ value: Element)` — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift:57`
- `func finish()` — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift:70`
- `func makeAsyncIterator() -> Iterator` — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift:84`
- `mutating func next() async -> Element?` — `StateConcurrency/SCAsyncSequence/AsyncCurrentValueStream.swift:116`
- `init()` — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift:35`
- `func send(_ value: Element)` — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift:47`
- `func finish()` — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift:59`
- `func makeAsyncIterator() -> Iterator` — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift:73`
- `mutating func next() async -> Element?` — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift:104`
- `func makeAsyncStream() -> AsyncStream<Element>` — `StateConcurrency/SCAsyncSequence/AsyncPassthroughStream.swift:125`
- `static func unimplemented(_ prefix: String) -> Self` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Convenience.swift:6`
- `static func unimplemented(_ prefix: String) -> Self` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Convenience.swift:18`
- `static func unimplemented(_ prefix: String) -> Self` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Convenience.swift:30`
- `static var finished: Self` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Convenience.swift:41`
- `static func unimplemented(_ prefix: String, placeholder: Element) -> Self` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Convenience.swift:52`
- `static func unimplemented(_ prefix: String, placeholder: Element) -> Self` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Convenience.swift:64`
- `func eraseToAsyncSequence() -> some AsyncSequence<Element, Failure>` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Extensions.swift:11`
- `var publisher: some Publisher<Element, Failure>` — `StateConcurrency/SCAsyncSequence/AsyncSequence+Extensions.swift:27`
- `var value: Element` — `StateConcurrency/SCAsyncSequence/AsyncValueStream.swift:34`
- `init(_ stream: AsyncCurrentValueStream<Element>)` — `StateConcurrency/SCAsyncSequence/AsyncValueStream.swift:41`
- `func makeAsyncIterator() -> AsyncCurrentValueStream<Element>.AsyncIterator` — `StateConcurrency/SCAsyncSequence/AsyncValueStream.swift:45`
- `static func constant(_ value: Element) -> Self` — `StateConcurrency/SCAsyncSequence/AsyncValueStream.swift:58`
- `var value: Success?` — `StateConcurrency/SCTask/Objects/ObservableTask.swift:46`
- `var error: Failure?` — `StateConcurrency/SCTask/Objects/ObservableTask.swift:52`
- `var isRunning: Bool` — `StateConcurrency/SCTask/Objects/ObservableTask.swift:58`
- `init(operation: @Sendable @escaping () async throws(Failure) -> Success)` — `StateConcurrency/SCTask/Objects/ObservableTask.swift:72`
- `func run()` — `StateConcurrency/SCTask/Objects/ObservableTask.swift:77`
- `func cancel()` — `StateConcurrency/SCTask/Objects/ObservableTask.swift:96`
- `init(maxConcurrentTasks: Int)` — `StateConcurrency/SCTask/Objects/SCConcurrencyLimiter.swift:16`
- `func execute<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T` — `StateConcurrency/SCTask/Objects/SCConcurrencyLimiter.swift:23`
- `init()` — `StateConcurrency/SCTask/Objects/SCLocalActor.swift:138`
- `func withLock<T>(_ body: () throws -> T) rethrows -> T` — `StateConcurrency/SCTask/Objects/SCLocalActor.swift:158`
- `func delay(forAttempt attempt: Int) -> SCTaskDuration?` — `StateConcurrency/SCTask/Objects/SCRetryPolicy.swift:23`
- `init(_ duration: Swift.Duration)` — `StateConcurrency/SCTask/Objects/SCTaskDuration+Native.swift:7`
- `var asDuration: Swift.Duration` — `StateConcurrency/SCTask/Objects/SCTaskDuration+Native.swift:13`
- `init(_ seconds: TimeInterval)` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:23`
- `var asTimeInterval: TimeInterval` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:38`
- `var asMilliseconds: UInt64` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:68`
- `var asNanoseconds: UInt64` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:98`
- `static func + (lhs: SCTaskDuration, rhs: SCTaskDuration) -> SCTaskDuration` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:122`
- `static func - (lhs: SCTaskDuration, rhs: SCTaskDuration) -> SCTaskDuration` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:132`
- `static func < (lhs: SCTaskDuration, rhs: SCTaskDuration) -> Bool` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:142`
- `static func == (lhs: SCTaskDuration, rhs: SCTaskDuration) -> Bool` — `StateConcurrency/SCTask/Objects/SCTaskDuration.swift:151`
- `let seconds: TimeInterval` — `StateConcurrency/SCTask/Objects/TimeoutError.swift:43`
- `let fileID: String` — `StateConcurrency/SCTask/Objects/TimeoutError.swift:47`
- `let line: UInt` — `StateConcurrency/SCTask/Objects/TimeoutError.swift:51`
- `init( _ seconds: TimeInterval, fileID: String = #fileID, line: UInt = #line )` — `StateConcurrency/SCTask/Objects/TimeoutError.swift:68`
- `var debugDescription: String` — `StateConcurrency/SCTask/Objects/TimeoutError.swift:87`
- `static func runImmediately<T: Sendable>( _ operation: @MainActor () throws -> T, file: StaticString = #file, line: UInt = #line` — `StateConcurrency/SCTask/SCHelpers/MainActor+Extensions.swift:71`
- `func timeout(_ duration: SCTaskDuration) -> AsyncThrowingTimeoutSequence<Self>` — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift:7`
- `func debounce(for duration: SCTaskDuration) -> AsyncDebounceSequence<Self>` — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift:14`
- `mutating func next() async throws -> Base.Element?` — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift:34`
- `func makeAsyncIterator() -> Iterator` — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift:39`
- `mutating func next() async throws -> Base.Element?` — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift:106`
- `func makeAsyncIterator() -> Iterator` — `StateConcurrency/SCTask/SCTask+AsyncSequence.swift:111`
- `static func cancellationWithError<T: Sendable>( _ onCancelError: any Error, operation: @Sendable @escaping () async throws -> T` — `StateConcurrency/SCTask/Task+Cancellation.swift:59`
- `static func gather<T: Sendable>( _ operations: [@Sendable () async throws -> T], maxConcurrentTasks: Int? = nil` — `StateConcurrency/SCTask/Task+Gather.swift:15`
- `static func gatherThrowing<T: Sendable>( _ operations: [@Sendable () async throws -> T], maxConcurrentTasks: Int? = nil` — `StateConcurrency/SCTask/Task+Gather.swift:54`
- `static func gatherValues<T: Sendable>( _ operations: [@Sendable () async throws -> T], maxConcurrentTasks: Int? = nil` — `StateConcurrency/SCTask/Task+Gather.swift:69`
- `static func race<T: Sendable>( _ operations: [@Sendable () async throws -> T]` — `StateConcurrency/SCTask/Task+Race.swift:12`
- `static func withResult<T: Sendable, E: Sendable>(priority: TaskPriority? = nil, operation: sending @escaping @isolated(any) () async throws(E) -> T) …` — `StateConcurrency/SCTask/Task+Result.swift:42`
- `static func retrying<T: Sendable>( priority: TaskPriority? = nil, maxRetryCount: Int = 3, policy: SCRetryPolicy = .exponential(initialDelay: .seconds…` — `StateConcurrency/SCTask/Task+Retry.swift:12`
- `static func retrying<T: Sendable>( priority: TaskPriority? = nil, maxRetryCount: Int = 3, retryInterval: SCTaskDuration? = nil, isRetryingCallback: (…` — `StateConcurrency/SCTask/Task+Retry.swift:43`
- `static func sleep(duration value: SCTaskDuration) async throws` — `StateConcurrency/SCTask/Task+Sleep.swift:22`
- `static func sleep(seconds: TimeInterval) async throws` — `StateConcurrency/SCTask/Task+Sleep.swift:26`
- `static func throwingTimeout<T: Sendable>( _ timeout: SCTaskDuration, operation: @Sendable @escaping () async throws -> T` — `StateConcurrency/SCTask/Task+Timeout.swift:62`

---

## `StateKitSupport`

Property wrappers @SAtom/@Hook + helper hooks (useCount, useNow, useLoadMore...).

### Types

- **struct `SKContext`** — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKContext.swift`
- **struct `SKState<A: SKStateAtom>`** — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKState.swift`
- **struct `SKTask<A: SKAsyncPhaseAtom>`** — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKTask.swift`
- **struct `SKValue<A: SKAtom>`** — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKValue.swift`
- **struct `HCountdown`** — `StateKitSupport/Hooks/@HookPropertyWrapper/HCount.swift`
- **struct `HEnvironment<Value>`** — `StateKitSupport/Hooks/@HookPropertyWrapper/HEnvironment.swift`
- **struct `HMemo<Node>`** — `StateKitSupport/Hooks/@HookPropertyWrapper/HMemo.swift`
- **struct `HPrint<Node>`** — `StateKitSupport/Hooks/@HookPropertyWrapper/HPrint.swift`
- **struct `HRef<Node>`** — `StateKitSupport/Hooks/@HookPropertyWrapper/HRef.swift`
- **struct `HState<Node>`** — `StateKitSupport/Hooks/@HookPropertyWrapper/HState.swift`
- **struct `CountdownController`** — `StateKitSupport/Hooks/Functions/useCountdown.swift`
- **extension `CountdownController`** — `StateKitSupport/Hooks/Functions/useCountdown.swift`
- **struct `LoadMorePage<Item, Cursor>`** — `StateKitSupport/Hooks/Functions/useLoadMore.swift`
- **struct `LoadMoreController<Item>`** — `StateKitSupport/Hooks/Functions/useLoadMore.swift`

### Members (func/var/init)

- `init()` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKContext.swift:48`
- `var wrappedValue: SKAtomViewContext` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKContext.swift:53`
- `init(_ atom: A)` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKState.swift:48`
- `var wrappedValue: A.Value` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKState.swift:66`
- `var projectedValue: Binding<A.Value>` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKState.swift:77`
- `init(_ atom: A)` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKTask.swift:61`
- `var wrappedValue: A.Value` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKTask.swift:79`
- `init(_ atom: A)` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKValue.swift:45`
- `var wrappedValue: A.Value` — `StateKitSupport/Atoms/@SAtomPropertyWrapper/SKValue.swift:63`
- `init( wrappedValue duration: Double, timeInterval: Double )` — `StateKitSupport/Hooks/@HookPropertyWrapper/HCount.swift:50`
- `var wrappedValue: Double` — `StateKitSupport/Hooks/@HookPropertyWrapper/HCount.swift:61`
- `var projectedValue: CountdownController` — `StateKitSupport/Hooks/@HookPropertyWrapper/HCount.swift:69`
- `init(_ keyPath: KeyPath<EnvironmentValues, Value>)` — `StateKitSupport/Hooks/@HookPropertyWrapper/HEnvironment.swift:38`
- `var wrappedValue: Value` — `StateKitSupport/Hooks/@HookPropertyWrapper/HEnvironment.swift:43`
- `var projectedValue: Self` — `StateKitSupport/Hooks/@HookPropertyWrapper/HEnvironment.swift:46`
- `var value: Value` — `StateKitSupport/Hooks/@HookPropertyWrapper/HEnvironment.swift:51`
- `init( wrappedValue compute: @autoclosure @escaping () -> Node, updateStrategy: UpdateStrategy = .once` — `StateKitSupport/Hooks/@HookPropertyWrapper/HMemo.swift:54`
- `var wrappedValue: Node` — `StateKitSupport/Hooks/@HookPropertyWrapper/HMemo.swift:62`
- `init( updateStrategy: UpdateStrategy = .once, wrappedValue compute: @autoclosure @escaping () -> Node, fileID: String = #fileID, line: UInt = #line, …` — `StateKitSupport/Hooks/@HookPropertyWrapper/HPrint.swift:58`
- `var wrappedValue: Node` — `StateKitSupport/Hooks/@HookPropertyWrapper/HPrint.swift:80`
- `init(wrappedValue initial: @autoclosure @escaping () -> Node)` — `StateKitSupport/Hooks/@HookPropertyWrapper/HRef.swift:57`
- `init(wrappedValue initial: @escaping () -> Node)` — `StateKitSupport/Hooks/@HookPropertyWrapper/HRef.swift:70`
- `var wrappedValue: Node` — `StateKitSupport/Hooks/@HookPropertyWrapper/HRef.swift:79`
- `var projectedValue: StateRef<Node>` — `StateKitSupport/Hooks/@HookPropertyWrapper/HRef.swift:89`
- `init(wrappedValue: @escaping () -> Node)` — `StateKitSupport/Hooks/@HookPropertyWrapper/HState.swift:72`
- `init(wrappedValue: Node)` — `StateKitSupport/Hooks/@HookPropertyWrapper/HState.swift:83`
- `init(wrappedValue: @escaping () -> Binding<Node>)` — `StateKitSupport/Hooks/@HookPropertyWrapper/HState.swift:95`
- `init(wrappedValue: Binding<Node>)` — `StateKitSupport/Hooks/@HookPropertyWrapper/HState.swift:106`
- `var wrappedValue: Node` — `StateKitSupport/Hooks/@HookPropertyWrapper/HState.swift:116`
- `var projectedValue: Binding<Node>` — `StateKitSupport/Hooks/@HookPropertyWrapper/HState.swift:125`
- `@MainActor public func useCount( updateStrategy: UpdateStrategy = .once ) -> Int` — `StateKitSupport/Hooks/Functions/useCount.swift:9`
- `func useCountdown( duration: Double, timeInterval: TimeInterval = 0.1 ) -> CountdownController` — `StateKitSupport/Hooks/Functions/useCountdown.swift:46`
- `let remaining: Binding<Double>` — `StateKitSupport/Hooks/Functions/useCountdown.swift:162`
- `let isRunning: Binding<Bool>` — `StateKitSupport/Hooks/Functions/useCountdown.swift:163`
- `let start: @MainActor () -> Void` — `StateKitSupport/Hooks/Functions/useCountdown.swift:164`
- `let pause: @MainActor () -> Void` — `StateKitSupport/Hooks/Functions/useCountdown.swift:165`
- `let resume: @MainActor () -> Void` — `StateKitSupport/Hooks/Functions/useCountdown.swift:166`
- `let cancel: @MainActor () -> Void` — `StateKitSupport/Hooks/Functions/useCountdown.swift:167`
- `let phase: Binding<Phase>` — `StateKitSupport/Hooks/Functions/useCountdown.swift:168`
- `init( remaining: Binding<Double>, isRunning: Binding<Bool>, start: @escaping @MainActor () -> Void, pause: @escaping @MainActor () -> Void, resume: @…` — `StateKitSupport/Hooks/Functions/useCountdown.swift:170`
- `func useLastValueAsyncPhase<Value>( _ phase: AsyncPhase<Value> ) -> Value?` — `StateKitSupport/Hooks/Functions/useLastValue.swift:49`
- `func useLastSuccessAsyncPhase<Value>( _ phase: AsyncPhase<Value> ) -> AsyncPhase<Value>` — `StateKitSupport/Hooks/Functions/useLastValue.swift:95`
- `func useOnFirstAppear( _ action: (() -> Void)? = nil` — `StateKitSupport/Hooks/Functions/useLifetime.swift:11`
- `func useOnLastDisappear( _ action: (() -> Void)? = nil` — `StateKitSupport/Hooks/Functions/useLifetime.swift:29`
- `let items: [Item]` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:8`
- `let nextCursor: Cursor?` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:9`
- `init( items: [Item], nextCursor: Cursor? )` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:11`
- `let phase: AsyncPhase<[Item]>` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:31`
- `let isReloading: Bool` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:32`
- `let isLoadingMore: Bool` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:33`
- `let reloadError: Error?` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:34`
- `let loadMoreError: Error?` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:35`
- `let hasNextPage: Bool` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:36`
- `var reload: @MainActor () -> Void` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:37`
- `var loadNext: @MainActor () -> Void` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:38`
- `var items: [Item]` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:44`
- `func useLoadMore<Item, Cursor>( initialCursor: Cursor, updateStrategy: UpdateStrategy? = .once, priority: TaskPriority? = nil, _ loadPage: @escaping …` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:149`
- `func useLoadMore<Item, Cursor>( initialCursor: Cursor, updateStrategy: UpdateStrategy? = .once, priority: TaskPriority? = nil, _ loadPage: @escaping …` — `StateKitSupport/Hooks/Functions/useLoadMore.swift:276`
- `func useNow( every interval: TimeInterval = 1 ) -> Date` — `StateKitSupport/Hooks/Functions/useNow.swift:37`
- `@MainActor public func usePrint( updateStrategy: UpdateStrategy? = .once, _ items: Any..., fileID: String = #fileID, line: UInt = #line, name: String…` — `StateKitSupport/Hooks/Functions/usePrint.swift:11`
- `func useSeenSKStatus<Value>( _ status: SKStatus, in phase: AsyncPhase<Value> ) -> SKStatus?` — `StateKitSupport/Hooks/Functions/useSeen.swift:69`
- `func useHasSeenSKStatus<Value>( _ status: SKStatus, in phase: AsyncPhase<Value> ) -> Bool` — `StateKitSupport/Hooks/Functions/useSeen.swift:116`

---

## `StateKitCombine`

Bridge Combine cho atoms và phases.

### Types

- **struct `SKCombineAtom<P: Publisher & Sendable>`** — `StateKitCombine/SKCombineAtom.swift`
- **typealias `TaskSuccess`** — `StateKitCombine/SKCombineAtom.swift`
- **extension `Publisher`** — `StateKitCombine/SKCombineAtom.swift`
- **struct `SKCombinePublisherAtom<P: Publisher & Sendable>`** — `StateKitCombine/SKCombinePublisherAtom.swift`
- **typealias `PublisherOutput`** — `StateKitCombine/SKCombinePublisherAtom.swift`
- **typealias `AtomPublisher`** — `StateKitCombine/SKCombinePublisherAtom.swift`
- **extension `Publisher`** — `StateKitCombine/SKCombinePublisherAtom.swift`
- **extension `Publisher`** — `StateKitCombine/StateKitCombine.swift`
- **extension `PublisherPhase`** — `StateKitCombine/StateKitCombine.swift`

### Members (func/var/init)

- `init(_ publisher: P, identifier: String)` — `StateKitCombine/SKCombineAtom.swift:16`
- `func task(context: SKAtomTransactionContext) async throws -> P.Output` — `StateKitCombine/SKCombineAtom.swift:21`
- `func hash(into hasher: inout Hasher)` — `StateKitCombine/SKCombineAtom.swift:29`
- `static func == (lhs: SKCombineAtom<P>, rhs: SKCombineAtom<P>) -> Bool` — `StateKitCombine/SKCombineAtom.swift:33`
- `init(_ publisher: P, identifier: String)` — `StateKitCombine/SKCombinePublisherAtom.swift:17`
- `func publisher(context: SKAtomTransactionContext) -> P` — `StateKitCombine/SKCombinePublisherAtom.swift:22`
- `func hash(into hasher: inout Hasher)` — `StateKitCombine/SKCombinePublisherAtom.swift:26`
- `static func == (lhs: SKCombinePublisherAtom<P>, rhs: SKCombinePublisherAtom<P>) -> Bool` — `StateKitCombine/SKCombinePublisherAtom.swift:30`

---

## `StateKitPersistence`

Persistence: UserDefaults, Keychain, SwiftData.

### Types

- **struct `KeychainStateProvider<T: Sendable & Codable>`** — `StateKitPersistence/KeychainStateProvider.swift`
- **enum `KeychainAccessibility`** — `StateKitPersistence/KeychainStateProvider.swift`
- **enum `KeychainError`** — `StateKitPersistence/KeychainStateProvider.swift`
- **struct `KeychainNotifierProvider`** — `StateKitPersistence/KeychainStateProvider.swift`
- **class `KeychainNotifier<T: Sendable & Codable>`** — `StateKitPersistence/KeychainStateProvider.swift`
- **struct `AuthToken`** — `StateKitPersistence/KeychainStateProvider.swift`
- **struct `SecureCredentials`** — `StateKitPersistence/KeychainStateProvider.swift`
- **struct `BiometricState`** — `StateKitPersistence/KeychainStateProvider.swift`
- **struct `KeychainBatch`** — `StateKitPersistence/KeychainStateProvider.swift`
- **struct `KeychainMigration`** — `StateKitPersistence/KeychainStateProvider.swift`
- **enum `StateKitPersistence`** — `StateKitPersistence/StateKitPersistence.swift`
- **typealias `SecureStateProvider`** — `StateKitPersistence/StateKitPersistence.swift`
- **struct `SwiftDataProvider<T: Sendable>`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **typealias `Build`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **class `SwiftDataProviderRef`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **struct `SwiftDataSync<T: Sendable & Codable>`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **struct `SwiftDataNotifierProvider`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **class `SwiftDataNotifier<T: Sendable>`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **struct `SwiftDataQueryProvider`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **struct `AutoPersist<T: Sendable & Codable>`** — `StateKitPersistence/SwiftDataIntegration.swift`
- **protocol `UserDefaultsSerializable`** — `StateKitPersistence/UserDefaultsAtom.swift`
- **class `PersistentAtomStorage<T: UserDefaultsSerializable>`** — `StateKitPersistence/UserDefaultsAtom.swift`
- **struct `AppPreferences`** — `StateKitPersistence/UserDefaultsAtom.swift`
- **struct `CacheMetadata`** — `StateKitPersistence/UserDefaultsAtom.swift`
- **struct `SessionInfo`** — `StateKitPersistence/UserDefaultsAtom.swift`
- **struct `PersistenceMigration<T: UserDefaultsSerializable>`** — `StateKitPersistence/UserDefaultsAtom.swift`

### Members (func/var/init)

- `init(key: String, accessibility: KeychainAccessibility = .afterFirstUnlock)` — `StateKitPersistence/KeychainStateProvider.swift:28`
- `func retrieve() throws -> T?` — `StateKitPersistence/KeychainStateProvider.swift:34`
- `func store(_ value: T) throws` — `StateKitPersistence/KeychainStateProvider.swift:55`
- `func delete() throws` — `StateKitPersistence/KeychainStateProvider.swift:86`
- `func exists() -> Bool` — `StateKitPersistence/KeychainStateProvider.swift:100`
- `func clearAll() throws` — `StateKitPersistence/KeychainStateProvider.swift:112`
- `var localizedDescription: String` — `StateKitPersistence/KeychainStateProvider.swift:146`
- `static func create<T: Sendable & Codable>( key: String, initial: T, accessibility: KeychainAccessibility = .whenUnlocked ) -> NotifierProvider<Keycha…` — `StateKitPersistence/KeychainStateProvider.swift:165`
- `init( provider: KeychainStateProvider<T>, initial: T )` — `StateKitPersistence/KeychainStateProvider.swift:182`
- `override func build() -> T` — `StateKitPersistence/KeychainStateProvider.swift:191`
- `func updateValue(_ value: T) throws` — `StateKitPersistence/KeychainStateProvider.swift:197`
- `func clear() throws` — `StateKitPersistence/KeychainStateProvider.swift:203`
- `let accessToken: String` — `StateKitPersistence/KeychainStateProvider.swift:213`
- `let refreshToken: String?` — `StateKitPersistence/KeychainStateProvider.swift:214`
- `let expiresAt: Date` — `StateKitPersistence/KeychainStateProvider.swift:215`
- `init(accessToken: String, refreshToken: String? = nil, expiresAt: Date)` — `StateKitPersistence/KeychainStateProvider.swift:217`
- `var isExpired: Bool` — `StateKitPersistence/KeychainStateProvider.swift:223`
- `let username: String` — `StateKitPersistence/KeychainStateProvider.swift:230`
- `let password: String` — `StateKitPersistence/KeychainStateProvider.swift:231`
- `let lastUpdated: Date` — `StateKitPersistence/KeychainStateProvider.swift:232`
- `init(username: String, password: String, lastUpdated: Date = Date())` — `StateKitPersistence/KeychainStateProvider.swift:234`
- `let isEnabled: Bool` — `StateKitPersistence/KeychainStateProvider.swift:243`
- `let lastVerified: Date?` — `StateKitPersistence/KeychainStateProvider.swift:244`
- `init(isEnabled: Bool = false, lastVerified: Date? = nil)` — `StateKitPersistence/KeychainStateProvider.swift:246`
- `init()` — `StateKitPersistence/KeychainStateProvider.swift:258`
- `mutating func add<T: Codable>(_ value: T, forKey key: String) throws` — `StateKitPersistence/KeychainStateProvider.swift:261`
- `func store(accessibility: KeychainAccessibility = .whenUnlocked) throws` — `StateKitPersistence/KeychainStateProvider.swift:267`
- `func deleteAll(matching pattern: String? = nil) throws` — `StateKitPersistence/KeychainStateProvider.swift:286`
- `static func migrateKey<T: Sendable & Codable>( from oldKey: String, to newKey: String, type: T.Type ) throws` — `StateKitPersistence/KeychainStateProvider.swift:303`
- `static func rotate<T: Sendable & Codable>( key: String, with newValue: T, type: T.Type ) throws` — `StateKitPersistence/KeychainStateProvider.swift:318`
- `static let version = "2.5.0-beta"` — `StateKitPersistence/StateKitPersistence.swift:17`
- `init(_ build: @escaping Build)` — `StateKitPersistence/SwiftDataIntegration.swift:25`
- `let modelContext: ModelContext` — `StateKitPersistence/SwiftDataIntegration.swift:32`
- `init(modelContext: ModelContext)` — `StateKitPersistence/SwiftDataIntegration.swift:34`
- `func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) throws -> [T]` — `StateKitPersistence/SwiftDataIntegration.swift:39`
- `func save() throws` — `StateKitPersistence/SwiftDataIntegration.swift:48`
- `init(state: T, context: ModelContext)` — `StateKitPersistence/SwiftDataIntegration.swift:62`
- `func encodeForStorage() throws -> Data` — `StateKitPersistence/SwiftDataIntegration.swift:68`
- `static func decodeFromStorage(_ data: Data) throws -> T` — `StateKitPersistence/SwiftDataIntegration.swift:73`
- `func getAllModels<M: PersistentModel>(_ type: M.Type) throws -> [M]` — `StateKitPersistence/SwiftDataIntegration.swift:78`
- `func persistChanges() throws` — `StateKitPersistence/SwiftDataIntegration.swift:84`
- `static func create<T: Sendable>( initialState: T, context: ModelContext ) -> AsyncNotifierProvider<SwiftDataNotifier<T>, T>` — `StateKitPersistence/SwiftDataIntegration.swift:95`
- `init(initialState: T, context: ModelContext)` — `StateKitPersistence/SwiftDataIntegration.swift:110`
- `override func build() async throws -> T` — `StateKitPersistence/SwiftDataIntegration.swift:116`
- `func updateAndPersist(_ update: (inout T) -> Void) async` — `StateKitPersistence/SwiftDataIntegration.swift:122`
- `static func query<T: PersistentModel>( type: T.Type, in context: ModelContext, predicate: Predicate<T>? = nil, sort: [SortDescriptor<T>] = [] ) -> Fu…` — `StateKitPersistence/SwiftDataIntegration.swift:142`
- `func syncToState( in context: ModelContext ) async throws -> Self` — `StateKitPersistence/SwiftDataIntegration.swift:166`
- `init(key: String, initial: T)` — `StateKitPersistence/SwiftDataIntegration.swift:181`
- `mutating func load() throws -> T` — `StateKitPersistence/SwiftDataIntegration.swift:187`
- `func save(_ value: T) throws` — `StateKitPersistence/SwiftDataIntegration.swift:195`
- `func clear()` — `StateKitPersistence/SwiftDataIntegration.swift:201`
- `func userDefaultsAtom<T: UserDefaultsSerializable>( _ type: T.Type, suiteName: String? = nil ) -> (() -> T)` — `StateKitPersistence/UserDefaultsAtom.swift:32`
- `init( type: T.Type, userDefaultsKey: String? = nil, suiteName: String? = nil )` — `StateKitPersistence/UserDefaultsAtom.swift:61`
- `func load() -> T` — `StateKitPersistence/UserDefaultsAtom.swift:71`
- `func save(_ value: T)` — `StateKitPersistence/UserDefaultsAtom.swift:82`
- `func delete()` — `StateKitPersistence/UserDefaultsAtom.swift:91`
- `func addObserver(_ observer: @escaping (T) -> Void)` — `StateKitPersistence/UserDefaultsAtom.swift:96`
- `let isDarkMode: Bool` — `StateKitPersistence/UserDefaultsAtom.swift:117`
- `let language: String` — `StateKitPersistence/UserDefaultsAtom.swift:118`
- `let lastOpenedDate: Date?` — `StateKitPersistence/UserDefaultsAtom.swift:119`
- `init(isDarkMode: Bool = false, language: String = "en", lastOpenedDate: Date? = nil)` — `StateKitPersistence/UserDefaultsAtom.swift:121`
- `static let userDefaultsKey = "com.statekit.appPreferences"` — `StateKitPersistence/UserDefaultsAtom.swift:127`
- `static let defaultValue = AppPreferences(isDarkMode: false, language: "en", lastOpenedDate: nil)` — `StateKitPersistence/UserDefaultsAtom.swift:128`
- `let lastUpdated: Date` — `StateKitPersistence/UserDefaultsAtom.swift:139`
- `let version: Int` — `StateKitPersistence/UserDefaultsAtom.swift:140`
- `let itemCount: Int` — `StateKitPersistence/UserDefaultsAtom.swift:141`
- `init(lastUpdated: Date = Date(), version: Int = 1, itemCount: Int = 0)` — `StateKitPersistence/UserDefaultsAtom.swift:143`
- `static let userDefaultsKey = "com.statekit.cacheMetadata"` — `StateKitPersistence/UserDefaultsAtom.swift:149`
- `static let defaultValue = CacheMetadata()` — `StateKitPersistence/UserDefaultsAtom.swift:150`
- `let userId: String?` — `StateKitPersistence/UserDefaultsAtom.swift:155`
- `let sessionToken: String?` — `StateKitPersistence/UserDefaultsAtom.swift:156`
- `let loginTime: Date?` — `StateKitPersistence/UserDefaultsAtom.swift:157`
- `init(userId: String? = nil, sessionToken: String? = nil, loginTime: Date? = nil)` — `StateKitPersistence/UserDefaultsAtom.swift:159`
- `static let userDefaultsKey = "com.statekit.sessionInfo"` — `StateKitPersistence/UserDefaultsAtom.swift:165`
- `static let defaultValue = SessionInfo(userId: nil, sessionToken: nil, loginTime: nil)` — `StateKitPersistence/UserDefaultsAtom.swift:166`
- `var isAuthenticated: Bool` — `StateKitPersistence/UserDefaultsAtom.swift:168`
- `func observeChanges() -> [T]` — `StateKitPersistence/UserDefaultsAtom.swift:177`
- `func exportAsJSON() -> Data?` — `StateKitPersistence/UserDefaultsAtom.swift:188`
- `func importFromJSON(_ data: Data) -> Bool` — `StateKitPersistence/UserDefaultsAtom.swift:194`
- `init(storage: PersistentAtomStorage<T>, version: Int)` — `StateKitPersistence/UserDefaultsAtom.swift:212`
- `func needsMigration(_ previousVersion: Int) -> Bool` — `StateKitPersistence/UserDefaultsAtom.swift:218`
- `func migrate(from previousVersion: Int, using updater: (inout T) -> Void)` — `StateKitPersistence/UserDefaultsAtom.swift:223`

---

## `StateKitCache`

Cache policies + LRU/TTL cache cho provider.

### Types

- **struct `CacheAsidePattern<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/CachePolicy.swift`
- **struct `WriteThroughPattern<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/CachePolicy.swift`
- **struct `CacheProviderFactory`** — `StateKitCache/CachePolicy.swift`
- **struct `MemoryPressureHandler<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/CachePolicy.swift`
- **struct `CachePreloader<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/CachePolicy.swift`
- **struct `CacheWarmer<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/CachePolicy.swift`
- **enum `CacheInvalidationStrategy`** — `StateKitCache/CachePolicy.swift`
- **struct `CacheMonitor<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/CachePolicy.swift`
- **class `LeastRecentlyUsedCache<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/LRUCache.swift`
- **class `LeastFrequentlyUsedCache<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/LRUCache.swift`
- **enum `StateKitCache`** — `StateKitCache/StateKitCache.swift`
- **protocol `CacheProtocol<Key, Value>`** — `StateKitCache/StateKitCache.swift`
- **struct `CacheStats`** — `StateKitCache/StateKitCache.swift`
- **typealias `CacheEvictionCallback<Key: Hashable, Value>`** — `StateKitCache/StateKitCache.swift`
- **enum `EvictionReason`** — `StateKitCache/StateKitCache.swift`
- **typealias `LRUCache`** — `StateKitCache/StateKitCache.swift`
- **typealias `TTLCache`** — `StateKitCache/StateKitCache.swift`
- **class `TimeToLiveCache<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/TTLCache.swift`
- **class `SlidingWindowTTLCache<Key: Hashable & Sendable, Value: Sendable>`** — `StateKitCache/TTLCache.swift`

### Members (func/var/init)

- `init(cache: LeastRecentlyUsedCache<Key, Value>, fetcher: @escaping (Key) async throws -> Value)` — `StateKitCache/CachePolicy.swift:12`
- `func get(_ key: Key) async throws -> Value` — `StateKitCache/CachePolicy.swift:18`
- `init(cache: LeastRecentlyUsedCache<Key, Value>, writer: @escaping (Key, Value) async throws -> Void)` — `StateKitCache/CachePolicy.swift:35`
- `func set(_ key: Key, _ value: Value) async throws` — `StateKitCache/CachePolicy.swift:41`
- `static func cacheAside<Key: Hashable & Sendable, T: Sendable>( key: Key, capacity: Int = 100, fetcher: @escaping (Key) async throws -> T` — `StateKitCache/CachePolicy.swift:53`
- `static func cachedFamily<Key: Hashable & Sendable, T: Sendable>( capacity: Int = 100, fetcher: @escaping (Key) async throws -> T` — `StateKitCache/CachePolicy.swift:73`
- `init(cache: LeastRecentlyUsedCache<Key, Value>, targetSize: Int = 10)` — `StateKitCache/CachePolicy.swift:99`
- `func handleMemoryPressure()` — `StateKitCache/CachePolicy.swift:106`
- `init(cache: LeastRecentlyUsedCache<Key, Value>)` — `StateKitCache/CachePolicy.swift:126`
- `func preload(_ items: [(key: Key, value: Value)])` — `StateKitCache/CachePolicy.swift:131`
- `func preloadAsync(_ fetcher: () async throws -> [(Key, Value)]) async throws` — `StateKitCache/CachePolicy.swift:136`
- `init(cache: LeastRecentlyUsedCache<Key, Value>)` — `StateKitCache/CachePolicy.swift:149`
- `func warmCache(with keys: [Key], fetcher: (Key) async throws -> Value) async throws` — `StateKitCache/CachePolicy.swift:154`
- `func apply<K: Hashable & Sendable, V: Sendable>( to cache: LeastRecentlyUsedCache<K, V>, invalidate key: K ) async` — `StateKitCache/CachePolicy.swift:171`
- `init(cache: LeastRecentlyUsedCache<Key, Value>)` — `StateKitCache/CachePolicy.swift:199`
- `func report() -> String` — `StateKitCache/CachePolicy.swift:204`
- `func isHealthy(minHitRate: Double = 0.7) -> Bool` — `StateKitCache/CachePolicy.swift:217`
- `init(capacity: Int = 100, onEvict: CacheEvictionCallback<Key, Value>? = nil)` — `StateKitCache/LRUCache.swift:23`
- `func get(_ key: Key) -> Value?` — `StateKitCache/LRUCache.swift:29`
- `func set(_ key: Key, _ value: Value)` — `StateKitCache/LRUCache.swift:43`
- `func remove(_ key: Key)` — `StateKitCache/LRUCache.swift:63`
- `func clear()` — `StateKitCache/LRUCache.swift:71`
- `var stats: CacheStats` — `StateKitCache/LRUCache.swift:77`
- `func resetStats()` — `StateKitCache/LRUCache.swift:82`
- `var count: Int` — `StateKitCache/LRUCache.swift:88`
- `var keys: [Key]` — `StateKitCache/LRUCache.swift:93`
- `func preload(_ items: [(key: Key, value: Value)])` — `StateKitCache/LRUCache.swift:98`
- `init(capacity: Int = 100, onEvict: CacheEvictionCallback<Key, Value>? = nil)` — `StateKitCache/LRUCache.swift:118`
- `func get(_ key: Key) -> Value?` — `StateKitCache/LRUCache.swift:124`
- `func set(_ key: Key, _ value: Value)` — `StateKitCache/LRUCache.swift:136`
- `func remove(_ key: Key)` — `StateKitCache/LRUCache.swift:152`
- `func clear()` — `StateKitCache/LRUCache.swift:160`
- `var stats: CacheStats` — `StateKitCache/LRUCache.swift:166`
- `func resetStats()` — `StateKitCache/LRUCache.swift:171`
- `var count: Int` — `StateKitCache/LRUCache.swift:177`
- `static let version = "2.6.0-beta"` — `StateKitCache/StateKitCache.swift:16`
- `let hits: Int` — `StateKitCache/StateKitCache.swift:46`
- `let misses: Int` — `StateKitCache/StateKitCache.swift:47`
- `let size: Int` — `StateKitCache/StateKitCache.swift:48`
- `let capacity: Int` — `StateKitCache/StateKitCache.swift:49`
- `var hitRate: Double` — `StateKitCache/StateKitCache.swift:51`
- `init(hits: Int = 0, misses: Int = 0, size: Int = 0, capacity: Int = 0)` — `StateKitCache/StateKitCache.swift:56`
- `init( ttl: TimeInterval = 300, onEvict: CacheEvictionCallback<Key, Value>? = nil, onExpire: ((Key, Value) -> Void)? = nil` — `StateKitCache/TTLCache.swift:29`
- `func get(_ key: Key) -> Value?` — `StateKitCache/TTLCache.swift:45`
- `func set(_ key: Key, _ value: Value)` — `StateKitCache/TTLCache.swift:65`
- `func remove(_ key: Key)` — `StateKitCache/TTLCache.swift:71`
- `func clear()` — `StateKitCache/TTLCache.swift:78`
- `var stats: CacheStats` — `StateKitCache/TTLCache.swift:83`
- `func resetStats()` — `StateKitCache/TTLCache.swift:88`
- `var count: Int` — `StateKitCache/TTLCache.swift:94`
- `var validCount: Int` — `StateKitCache/TTLCache.swift:99`
- `func set(_ key: Key, _ value: Value, ttl customTTL: TimeInterval)` — `StateKitCache/TTLCache.swift:105`
- `func cleanup()` — `StateKitCache/TTLCache.swift:111`
- `init(ttl: TimeInterval = 300, onEvict: CacheEvictionCallback<Key, Value>? = nil)` — `StateKitCache/TTLCache.swift:163`
- `func get(_ key: Key) -> Value?` — `StateKitCache/TTLCache.swift:174`
- `func set(_ key: Key, _ value: Value)` — `StateKitCache/TTLCache.swift:187`
- `func remove(_ key: Key)` — `StateKitCache/TTLCache.swift:193`
- `func clear()` — `StateKitCache/TTLCache.swift:200`
- `var stats: CacheStats` — `StateKitCache/TTLCache.swift:205`
- `func resetStats()` — `StateKitCache/TTLCache.swift:210`
- `func cleanup()` — `StateKitCache/TTLCache.swift:216`

---

## `StateKitAnalytics`

Analytics event tracking + user journey.

### Types

- **class `EventTracker`** — `StateKitAnalytics/EventTracker.swift`
- **struct `EventLogger`** — `StateKitAnalytics/EventTracker.swift`
- **struct `EventFilter`** — `StateKitAnalytics/EventTracker.swift`
- **enum `StateKitAnalytics`** — `StateKitAnalytics/StateKitAnalytics.swift`
- **struct `AnalyticsEvent`** — `StateKitAnalytics/StateKitAnalytics.swift`
- **enum `AnyCodable`** — `StateKitAnalytics/StateKitAnalytics.swift`
- **struct `AnalyticsConfig`** — `StateKitAnalytics/StateKitAnalytics.swift`
- **class `AnalyticsProviderObserver`** — `StateKitAnalytics/StateKitAnalytics.swift`
- **enum `StandardEvent`** — `StateKitAnalytics/StateKitAnalytics.swift`
- **enum `StandardProperty`** — `StateKitAnalytics/StateKitAnalytics.swift`
- **class `UserJourneyTracker`** — `StateKitAnalytics/UserJourney.swift`
- **struct `Session`** — `StateKitAnalytics/UserJourney.swift`
- **struct `FunnelAnalyzer`** — `StateKitAnalytics/UserJourney.swift`
- **struct `FunnelStep`** — `StateKitAnalytics/UserJourney.swift`
- **struct `FunnelResult`** — `StateKitAnalytics/UserJourney.swift`
- **struct `DropoffAnalyzer`** — `StateKitAnalytics/UserJourney.swift`
- **struct `CohortAnalyzer`** — `StateKitAnalytics/UserJourney.swift`
- **struct `Cohort`** — `StateKitAnalytics/UserJourney.swift`

### Members (func/var/init)

- `init(config: AnalyticsConfig = AnalyticsConfig())` — `StateKitAnalytics/EventTracker.swift:14`
- `func track(_ event: AnalyticsEvent)` — `StateKitAnalytics/EventTracker.swift:24`
- `func track(_ name: String, properties: [String: AnyCodable] = [:])` — `StateKitAnalytics/EventTracker.swift:43`
- `func flush()` — `StateKitAnalytics/EventTracker.swift:54`
- `func onFlush(_ callback: @escaping ([AnalyticsEvent]) -> Void)` — `StateKitAnalytics/EventTracker.swift:64`
- `var allEvents: [AnalyticsEvent]` — `StateKitAnalytics/EventTracker.swift:69`
- `var pendingEvents: [AnalyticsEvent]` — `StateKitAnalytics/EventTracker.swift:74`
- `var eventCount: Int` — `StateKitAnalytics/EventTracker.swift:79`
- `func clearEvents()` — `StateKitAnalytics/EventTracker.swift:84`
- `init(tracker: EventTracker)` — `StateKitAnalytics/EventTracker.swift:111`
- `func logEvents() -> String` — `StateKitAnalytics/EventTracker.swift:116`
- `func summary() -> [String: Int]` — `StateKitAnalytics/EventTracker.swift:137`
- `init(events: [AnalyticsEvent])` — `StateKitAnalytics/EventTracker.swift:154`
- `func byName(_ name: String) -> [AnalyticsEvent]` — `StateKitAnalytics/EventTracker.swift:159`
- `func byUser(_ userId: String) -> [AnalyticsEvent]` — `StateKitAnalytics/EventTracker.swift:164`
- `func byDate(from: Date, to: Date) -> [AnalyticsEvent]` — `StateKitAnalytics/EventTracker.swift:169`
- `func byProperty(_ key: String, value: AnyCodable) -> [AnalyticsEvent]` — `StateKitAnalytics/EventTracker.swift:174`
- `static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool` — `StateKitAnalytics/EventTracker.swift:187`
- `static let version = "2.6.0-beta"` — `StateKitAnalytics/StateKitAnalytics.swift:16`
- `let name: String` — `StateKitAnalytics/StateKitAnalytics.swift:23`
- `let timestamp: Date` — `StateKitAnalytics/StateKitAnalytics.swift:24`
- `let properties: [String: AnyCodable]` — `StateKitAnalytics/StateKitAnalytics.swift:25`
- `let userId: String?` — `StateKitAnalytics/StateKitAnalytics.swift:26`
- `let sessionId: String` — `StateKitAnalytics/StateKitAnalytics.swift:27`
- `init( name: String, properties: [String: AnyCodable] = [:], userId: String? = nil, sessionId: String = UUID().uuidString )` — `StateKitAnalytics/StateKitAnalytics.swift:29`
- `func toDictionary() -> [String: Any]` — `StateKitAnalytics/StateKitAnalytics.swift:43`
- `init(from decoder: Decoder) throws` — `StateKitAnalytics/StateKitAnalytics.swift:74`
- `func encode(to encoder: Encoder) throws` — `StateKitAnalytics/StateKitAnalytics.swift:96`
- `let enabled: Bool` — `StateKitAnalytics/StateKitAnalytics.swift:122`
- `let flushInterval: TimeInterval` — `StateKitAnalytics/StateKitAnalytics.swift:123`
- `let batchSize: Int` — `StateKitAnalytics/StateKitAnalytics.swift:124`
- `let persistLocal: Bool` — `StateKitAnalytics/StateKitAnalytics.swift:125`
- `let userId: String?` — `StateKitAnalytics/StateKitAnalytics.swift:126`
- `let sessionId: String` — `StateKitAnalytics/StateKitAnalytics.swift:127`
- `init( enabled: Bool = true, flushInterval: TimeInterval = 30, batchSize: Int = 50, persistLocal: Bool = false, userId: String? = nil,` — `StateKitAnalytics/StateKitAnalytics.swift:129`
- `init(tracker: EventTracker, includeValues: Bool = false)` — `StateKitAnalytics/StateKitAnalytics.swift:154`
- `func didUpdateProvider<P: ProviderProtocol>( _ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer )` — `StateKitAnalytics/StateKitAnalytics.swift:159`
- `static let appLaunched = "app_launched"` — `StateKitAnalytics/StateKitAnalytics.swift:181`
- `static let appForegrounded = "app_foregrounded"` — `StateKitAnalytics/StateKitAnalytics.swift:182`
- `static let appBackgrounded = "app_backgrounded"` — `StateKitAnalytics/StateKitAnalytics.swift:183`
- `static let appTerminated = "app_terminated"` — `StateKitAnalytics/StateKitAnalytics.swift:184`
- `static let userSignedIn = "user_signed_in"` — `StateKitAnalytics/StateKitAnalytics.swift:185`
- `static let userSignedOut = "user_signed_out"` — `StateKitAnalytics/StateKitAnalytics.swift:186`
- `static let screenViewed = "screen_viewed"` — `StateKitAnalytics/StateKitAnalytics.swift:187`
- `static let buttonTapped = "button_tapped"` — `StateKitAnalytics/StateKitAnalytics.swift:188`
- `static let errorOccurred = "error_occurred"` — `StateKitAnalytics/StateKitAnalytics.swift:189`
- `static let userId = "user_id"` — `StateKitAnalytics/StateKitAnalytics.swift:196`
- `static let sessionId = "session_id"` — `StateKitAnalytics/StateKitAnalytics.swift:197`
- `static let timestamp = "timestamp"` — `StateKitAnalytics/StateKitAnalytics.swift:198`
- `static let screenName = "screen_name"` — `StateKitAnalytics/StateKitAnalytics.swift:199`
- `static let errorCode = "error_code"` — `StateKitAnalytics/StateKitAnalytics.swift:200`
- `static let errorMessage = "error_message"` — `StateKitAnalytics/StateKitAnalytics.swift:201`
- `static let value = "value"` — `StateKitAnalytics/StateKitAnalytics.swift:202`
- `let id: String` — `StateKitAnalytics/UserJourney.swift:9`
- `let userId: String` — `StateKitAnalytics/UserJourney.swift:10`
- `let startTime: Date` — `StateKitAnalytics/UserJourney.swift:11`
- `let endTime: Date?` — `StateKitAnalytics/UserJourney.swift:12`
- `let eventCount: Int` — `StateKitAnalytics/UserJourney.swift:13`
- `let properties: [String: AnyCodable]` — `StateKitAnalytics/UserJourney.swift:14`
- `var duration: TimeInterval?` — `StateKitAnalytics/UserJourney.swift:16`
- `init()` — `StateKitAnalytics/UserJourney.swift:25`
- `func startNewSession(userId: String? = nil, properties: [String: AnyCodable] = [:])` — `StateKitAnalytics/UserJourney.swift:30`
- `func endSession()` — `StateKitAnalytics/UserJourney.swift:44`
- `func recordEvent(_ event: AnalyticsEvent)` — `StateKitAnalytics/UserJourney.swift:60`
- `var currentSessionId: String?` — `StateKitAnalytics/UserJourney.swift:67`
- `var allSessions: [Session]` — `StateKitAnalytics/UserJourney.swift:72`
- `func session(id: String) -> Session?` — `StateKitAnalytics/UserJourney.swift:77`
- `func journey(sessionId: String) -> [AnalyticsEvent]` — `StateKitAnalytics/UserJourney.swift:82`
- `let name: String` — `StateKitAnalytics/UserJourney.swift:92`
- `let eventName: String` — `StateKitAnalytics/UserJourney.swift:93`
- `let index: Int` — `StateKitAnalytics/UserJourney.swift:94`
- `init(name: String, eventName: String, index: Int)` — `StateKitAnalytics/UserJourney.swift:96`
- `let steps: [FunnelStep]` — `StateKitAnalytics/UserJourney.swift:104`
- `let completions: [String: Int] // userId -> step completed to` — `StateKitAnalytics/UserJourney.swift:105`
- `let conversionRates: [Double] // Percentage for each step` — `StateKitAnalytics/UserJourney.swift:106`
- `var totalCompletions: Int` — `StateKitAnalytics/UserJourney.swift:108`
- `init(steps: [FunnelStep])` — `StateKitAnalytics/UserJourney.swift:115`
- `func analyze(events: [AnalyticsEvent]) -> FunnelResult` — `StateKitAnalytics/UserJourney.swift:120`
- `init(funnel: [String])` — `StateKitAnalytics/UserJourney.swift:157`
- `func analyzeDropoff(events: [AnalyticsEvent]) -> [String: Int]` — `StateKitAnalytics/UserJourney.swift:162`
- `func dropoffRate(events: [AnalyticsEvent], from: String, to: String) -> Double` — `StateKitAnalytics/UserJourney.swift:175`
- `let weekStarting: Date` — `StateKitAnalytics/UserJourney.swift:192`
- `let size: Int` — `StateKitAnalytics/UserJourney.swift:193`
- `let retentionByWeek: [Double]` — `StateKitAnalytics/UserJourney.swift:194`
- `func analyzeCohorts(events: [AnalyticsEvent], onEvent: String = "app_launched") -> [Cohort]` — `StateKitAnalytics/UserJourney.swift:198`

---

## `StateKitFeatureFlags`

Feature flags, rollout, A/B testing.

### Types

- **struct `ABTestVariant<T: Sendable>`** — `StateKitFeatureFlags/ABTestFramework.swift`
- **struct `ABTest<T: Sendable>`** — `StateKitFeatureFlags/ABTestFramework.swift`
- **class `ABTestRunner<T: Sendable>`** — `StateKitFeatureFlags/ABTestFramework.swift`
- **struct `Result`** — `StateKitFeatureFlags/ABTestFramework.swift`
- **class `ABTestManager`** — `StateKitFeatureFlags/ABTestFramework.swift`
- **struct `StatisticalTest`** — `StateKitFeatureFlags/ABTestFramework.swift`
- **protocol `RolloutStrategy`** — `StateKitFeatureFlags/Rollout.swift`
- **struct `PercentageRollout`** — `StateKitFeatureFlags/Rollout.swift`
- **struct `CohortRollout`** — `StateKitFeatureFlags/Rollout.swift`
- **struct `TimeBasedRollout`** — `StateKitFeatureFlags/Rollout.swift`
- **struct `GeolocationRollout`** — `StateKitFeatureFlags/Rollout.swift`
- **struct `CanaryRollout`** — `StateKitFeatureFlags/Rollout.swift`
- **class `RolloutManager`** — `StateKitFeatureFlags/Rollout.swift`
- **struct `StagedRollout`** — `StateKitFeatureFlags/Rollout.swift`
- **enum `Stage`** — `StateKitFeatureFlags/Rollout.swift`
- **enum `StateKitFeatureFlags`** — `StateKitFeatureFlags/StateKitFeatureFlags.swift`
- **protocol `FeatureFlagDefinition`** — `StateKitFeatureFlags/StateKitFeatureFlags.swift`
- **enum `FeatureFlagValue`** — `StateKitFeatureFlags/StateKitFeatureFlags.swift`
- **struct `FeatureFlag<T: Sendable>`** — `StateKitFeatureFlags/StateKitFeatureFlags.swift`
- **class `FeatureFlagRegistry`** — `StateKitFeatureFlags/StateKitFeatureFlags.swift`
- **struct `FeatureFlagStatus`** — `StateKitFeatureFlags/StateKitFeatureFlags.swift`

### Members (func/var/init)

- `let id: String` — `StateKitFeatureFlags/ABTestFramework.swift:7`
- `let name: String` — `StateKitFeatureFlags/ABTestFramework.swift:8`
- `let description: String` — `StateKitFeatureFlags/ABTestFramework.swift:9`
- `let value: T` — `StateKitFeatureFlags/ABTestFramework.swift:10`
- `init(id: String, name: String, description: String = "", value: T)` — `StateKitFeatureFlags/ABTestFramework.swift:12`
- `let id: String` — `StateKitFeatureFlags/ABTestFramework.swift:22`
- `let name: String` — `StateKitFeatureFlags/ABTestFramework.swift:23`
- `let variants: [ABTestVariant<T>]` — `StateKitFeatureFlags/ABTestFramework.swift:24`
- `let trafficPercentage: Int` — `StateKitFeatureFlags/ABTestFramework.swift:25`
- `let userKey: @Sendable (String) -> String` — `StateKitFeatureFlags/ABTestFramework.swift:26`
- `let isActive: Bool` — `StateKitFeatureFlags/ABTestFramework.swift:27`
- `init( id: String, name: String, variants: [ABTestVariant<T>], trafficPercentage: Int = 100, userKey: @escaping @Sendable (String) -> String = { $0 },` — `StateKitFeatureFlags/ABTestFramework.swift:29`
- `func assignUser(_ userId: String) -> ABTestVariant<T>?` — `StateKitFeatureFlags/ABTestFramework.swift:46`
- `func variant(for userId: String) -> ABTestVariant<T>?` — `StateKitFeatureFlags/ABTestFramework.swift:60`
- `func isInControl(_ userId: String) -> Bool` — `StateKitFeatureFlags/ABTestFramework.swift:65`
- `func isInTreatment(_ userId: String) -> Bool` — `StateKitFeatureFlags/ABTestFramework.swift:70`
- `let testId: String` — `StateKitFeatureFlags/ABTestFramework.swift:85`
- `let userId: String` — `StateKitFeatureFlags/ABTestFramework.swift:86`
- `let variant: ABTestVariant<T>` — `StateKitFeatureFlags/ABTestFramework.swift:87`
- `let timestamp: Date` — `StateKitFeatureFlags/ABTestFramework.swift:88`
- `let conversionValue: Double?` — `StateKitFeatureFlags/ABTestFramework.swift:89`
- `init( testId: String, userId: String, variant: ABTestVariant<T>, conversionValue: Double? = nil )` — `StateKitFeatureFlags/ABTestFramework.swift:91`
- `init(test: ABTest<T>)` — `StateKitFeatureFlags/ABTestFramework.swift:108`
- `func recordAssignment(_ userId: String, variant: ABTestVariant<T>)` — `StateKitFeatureFlags/ABTestFramework.swift:113`
- `func recordConversion(_ userId: String, variant: ABTestVariant<T>, value: Double = 1.0)` — `StateKitFeatureFlags/ABTestFramework.swift:118`
- `func results(for variantId: String) -> [Result]` — `StateKitFeatureFlags/ABTestFramework.swift:123`
- `var allResults: [Result]` — `StateKitFeatureFlags/ABTestFramework.swift:128`
- `func conversionRate(for variantId: String) -> Double` — `StateKitFeatureFlags/ABTestFramework.swift:133`
- `func report() -> String` — `StateKitFeatureFlags/ABTestFramework.swift:140`
- `func clearResults()` — `StateKitFeatureFlags/ABTestFramework.swift:157`
- `init()` — `StateKitFeatureFlags/ABTestFramework.swift:170`
- `func register<T: Sendable>(_ test: ABTest<T>)` — `StateKitFeatureFlags/ABTestFramework.swift:173`
- `func test<T: Sendable>(_ id: String, type: T.Type) -> ABTest<T>?` — `StateKitFeatureFlags/ABTestFramework.swift:179`
- `func runner<T: Sendable>(_ testId: String, type: T.Type) -> ABTestRunner<T>?` — `StateKitFeatureFlags/ABTestFramework.swift:184`
- `var testIds: [String]` — `StateKitFeatureFlags/ABTestFramework.swift:189`
- `static func chiSquareTest( variantA: (successes: Int, total: Int), variantB: (successes: Int, total: Int) ) -> Double` — `StateKitFeatureFlags/ABTestFramework.swift:199`
- `static func isSignificant(_ chiSquareValue: Double) -> Bool` — `StateKitFeatureFlags/ABTestFramework.swift:227`
- `let percentage: Int` — `StateKitFeatureFlags/Rollout.swift:18`
- `init(percentage: Int, userHasher: @escaping @Sendable (String) -> Int =` — `StateKitFeatureFlags/Rollout.swift:21`
- `func isEnabled(for userId: String) -> Bool` — `StateKitFeatureFlags/Rollout.swift:27`
- `let percentage: Int` — `StateKitFeatureFlags/Rollout.swift:38`
- `init(cohorts: Set<String>, percentage: Int = 100)` — `StateKitFeatureFlags/Rollout.swift:41`
- `func isEnabled(for userId: String) -> Bool` — `StateKitFeatureFlags/Rollout.swift:47`
- `let percentage: Int` — `StateKitFeatureFlags/Rollout.swift:56`
- `let startDate: Date` — `StateKitFeatureFlags/Rollout.swift:57`
- `let endDate: Date?` — `StateKitFeatureFlags/Rollout.swift:58`
- `init( percentage: Int, startDate: Date, endDate: Date? = nil )` — `StateKitFeatureFlags/Rollout.swift:60`
- `func isEnabled(for userId: String) -> Bool` — `StateKitFeatureFlags/Rollout.swift:71`
- `let percentage: Int` — `StateKitFeatureFlags/Rollout.swift:85`
- `let allowedRegions: Set<String>` — `StateKitFeatureFlags/Rollout.swift:86`
- `init(allowedRegions: Set<String>, percentage: Int = 100)` — `StateKitFeatureFlags/Rollout.swift:88`
- `func isEnabled(for userId: String) -> Bool` — `StateKitFeatureFlags/Rollout.swift:98`
- `let startPercentage: Int` — `StateKitFeatureFlags/Rollout.swift:107`
- `let endPercentage: Int` — `StateKitFeatureFlags/Rollout.swift:108`
- `let startDate: Date` — `StateKitFeatureFlags/Rollout.swift:109`
- `let endDate: Date` — `StateKitFeatureFlags/Rollout.swift:110`
- `init( startPercentage: Int = 1, endPercentage: Int = 100, startDate: Date, endDate: Date, userHasher: @escaping @Sendable (String) -> Int = { djb2Has…` — `StateKitFeatureFlags/Rollout.swift:113`
- `var percentage: Int` — `StateKitFeatureFlags/Rollout.swift:128`
- `func isEnabled(for userId: String) -> Bool` — `StateKitFeatureFlags/Rollout.swift:142`
- `init()` — `StateKitFeatureFlags/Rollout.swift:160`
- `func register<S: RolloutStrategy>(_ rollout: S, for featureId: String)` — `StateKitFeatureFlags/Rollout.swift:163`
- `func isEnabled(_ featureId: String, for userId: String) -> Bool` — `StateKitFeatureFlags/Rollout.swift:168`
- `func percentage(for featureId: String) -> Int` — `StateKitFeatureFlags/Rollout.swift:173`
- `var allRollouts: [String]` — `StateKitFeatureFlags/Rollout.swift:178`
- `let percentage: Int` — `StateKitFeatureFlags/Rollout.swift:193`
- `let stage: Stage` — `StateKitFeatureFlags/Rollout.swift:194`
- `let internalUsers: Set<String>` — `StateKitFeatureFlags/Rollout.swift:195`
- `let betaUsers: Set<String>` — `StateKitFeatureFlags/Rollout.swift:196`
- `init( stage: Stage, percentage: Int = 100, internalUsers: Set<String> = [], betaUsers: Set<String> = [] )` — `StateKitFeatureFlags/Rollout.swift:198`
- `func isEnabled(for userId: String) -> Bool` — `StateKitFeatureFlags/Rollout.swift:211`
- `static let version = "2.6.0-beta"` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:15`
- `var boolValue: Bool?` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:47`
- `var stringValue: String?` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:52`
- `var intValue: Int?` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:57`
- `var doubleValue: Double?` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:63`
- `let id: String` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:73`
- `let name: String` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:74`
- `let description: String` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:75`
- `let defaultValue: T` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:76`
- `init( id: String, name: String, description: String = "", defaultValue: T )` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:78`
- `init()` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:99`
- `func register<T: Sendable>(_ flag: FeatureFlag<T>)` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:102`
- `func value<T: Sendable>(for flag: FeatureFlag<T>) -> T` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:107`
- `func setOverride<T: Sendable>(_ flag: FeatureFlag<T>, value: T)` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:115`
- `func clearOverride(_ flagId: String)` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:120`
- `func clearAllOverrides()` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:125`
- `var allFlags: [String: String]` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:130`
- `let flagId: String` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:143`
- `let isEnabled: Bool` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:144`
- `let rolloutPercentage: Int` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:145`
- `let enabledFor: Set<String>` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:146`
- `let lastUpdated: Date` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:147`
- `init( flagId: String, isEnabled: Bool, rolloutPercentage: Int = 100, enabledFor: Set<String> = [], lastUpdated: Date = Date()` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:149`
- `let newUIFlag = FeatureFlag<Bool>( id: "feature_new_ui", name: "New UI", description: "Enable new user interface design", defaultValue: false )` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:167`
- `let darkModeFlag = FeatureFlag<Bool>( id: "feature_dark_mode", name: "Dark Mode", description: "Enable dark mode support", defaultValue: false )` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:175`
- `let betaFeaturesFlag = FeatureFlag<Bool>( id: "feature_beta", name: "Beta Features", description: "Enable beta/experimental features", defaultValue: …` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:183`
- `let analyticsLevelFlag = FeatureFlag<String>( id: "feature_analytics_level", name: "Analytics Level", description: "Set analytics detail level", defa…` — `StateKitFeatureFlags/StateKitFeatureFlags.swift:191`

---

## `StateKitTesting`

Testing utilities deterministic + integration.

### Types

- **class `DeterministicTestEnvironment`** — `StateKitTesting/Deterministic/DeterministicTesting.swift`
- **struct `DeterministicRandom`** — `StateKitTesting/Deterministic/DeterministicTesting.swift`
- **struct `DeterministicTimeProvider`** — `StateKitTesting/Deterministic/DeterministicTesting.swift`
- **class `TestExecutionRecord`** — `StateKitTesting/Deterministic/DeterministicTesting.swift`
- **actor `DeterministicAsyncExecutor`** — `StateKitTesting/Deterministic/DeterministicTesting.swift`
- **struct `StateMutationTrace<T: Sendable & Equatable>`** — `StateKitTesting/Deterministic/DeterministicTesting.swift`
- **struct `DeterministicAssertions`** — `StateKitTesting/Deterministic/DeterministicTesting.swift`
- **protocol `StateTestFixture`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `FixtureBuilder<T: Sendable>`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `StateGenerator`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `TestDataBuilder<T: Sendable>`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `CommonFixtures`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `StateSnapshot<T: Sendable & Codable>`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **class `FixtureRegistry`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `ParameterizedFixture<T: Sendable>`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `FixtureFactory`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **struct `FixtureAssertion`** — `StateKitTesting/Fixtures/StateTestFixtures.swift`
- **class `IntegrationTestEnvironment`** — `StateKitTesting/Integration/IntegrationTestHelpers.swift`
- **struct `MockProviderBuilder<T: Sendable>`** — `StateKitTesting/Integration/IntegrationTestHelpers.swift`
- **struct `StateVerification`** — `StateKitTesting/Integration/IntegrationTestHelpers.swift`
- **class `FeatureTestHarness<State: Sendable>`** — `StateKitTesting/Integration/IntegrationTestHelpers.swift`
- **struct `TestScenarioBuilder`** — `StateKitTesting/Integration/IntegrationTestHelpers.swift`
- **struct `PerformanceTesting`** — `StateKitTesting/Integration/IntegrationTestHelpers.swift`
- **class `StateTest`** — `StateKitTesting/Testing.swift`

### Members (func/var/init)

- `init(seed: UInt64 = 0)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:28`
- `func freezeTime(to date: Date)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:34`
- `func now() -> Date` — `StateKitTesting/Deterministic/DeterministicTesting.swift:39`
- `func advance(by interval: TimeInterval)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:44`
- `func enqueueAsync(_ operation: @escaping () async -> Void) async` — `StateKitTesting/Deterministic/DeterministicTesting.swift:51`
- `func reset()` — `StateKitTesting/Deterministic/DeterministicTesting.swift:70`
- `init(seed: UInt64)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:92`
- `mutating func next() -> UInt64` — `StateKitTesting/Deterministic/DeterministicTesting.swift:97`
- `mutating func nextInt(min: Int, max: Int) -> Int` — `StateKitTesting/Deterministic/DeterministicTesting.swift:104`
- `mutating func nextDouble(min: Double = 0, max: Double = 1) -> Double` — `StateKitTesting/Deterministic/DeterministicTesting.swift:110`
- `mutating func nextBool() -> Bool` — `StateKitTesting/Deterministic/DeterministicTesting.swift:116`
- `mutating func reset(seed: UInt64)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:121`
- `init(startTime: Date = Date(timeIntervalSince1970: 0))` — `StateKitTesting/Deterministic/DeterministicTesting.swift:134`
- `func now() -> Date` — `StateKitTesting/Deterministic/DeterministicTesting.swift:139`
- `mutating func advance(by interval: TimeInterval)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:144`
- `mutating func setTime(to date: Date)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:149`
- `func timeUntil(_ date: Date) -> TimeInterval` — `StateKitTesting/Deterministic/DeterministicTesting.swift:154`
- `func logEvent(_ description: String)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:179`
- `var allEvents: [(String, String)]` — `StateKitTesting/Deterministic/DeterministicTesting.swift:184`
- `func verify( _ expectedSequence: [String], file: StaticString = #file, line: UInt = #line )` — `StateKitTesting/Deterministic/DeterministicTesting.swift:192`
- `func clear()` — `StateKitTesting/Deterministic/DeterministicTesting.swift:208`
- `func report() -> String` — `StateKitTesting/Deterministic/DeterministicTesting.swift:213`
- `func enqueue(_ operation: @escaping () async -> Void)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:238`
- `func executeAll() async` — `StateKitTesting/Deterministic/DeterministicTesting.swift:245`
- `func executeNext() async -> Bool` — `StateKitTesting/Deterministic/DeterministicTesting.swift:258`
- `var pendingCount: Int` — `StateKitTesting/Deterministic/DeterministicTesting.swift:266`
- `func clear()` — `StateKitTesting/Deterministic/DeterministicTesting.swift:271`
- `init(initialState: T)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:293`
- `mutating func record(from: T, to: T, action: String)` — `StateKitTesting/Deterministic/DeterministicTesting.swift:298`
- `var path: [T]` — `StateKitTesting/Deterministic/DeterministicTesting.swift:304`
- `var allMutations: [(T, T, String)]` — `StateKitTesting/Deterministic/DeterministicTesting.swift:309`
- `func contains(action: String) -> Bool` — `StateKitTesting/Deterministic/DeterministicTesting.swift:314`
- `func mutationsFor(_ action: String) -> [(T, T)]` — `StateKitTesting/Deterministic/DeterministicTesting.swift:319`
- `var count: Int` — `StateKitTesting/Deterministic/DeterministicTesting.swift:324`
- `func report() -> String` — `StateKitTesting/Deterministic/DeterministicTesting.swift:329`
- `static func assertDeterministic<T: Sendable & Equatable>( seed: UInt64 = 42, operation: @escaping () -> T, file: StaticString = #file, line: UInt = #…` — `StateKitTesting/Deterministic/DeterministicTesting.swift:346`
- `static func assertReproducible<T: Sendable & Equatable>( seed: UInt64, operation: @escaping (UInt64) -> T, file: StaticString = #file, line: UInt = #…` — `StateKitTesting/Deterministic/DeterministicTesting.swift:369`
- `static func assertPredictableTiming( expectedDuration: TimeInterval, tolerance: TimeInterval = 0.01, operation: @escaping () async -> Void` — `StateKitTesting/Deterministic/DeterministicTesting.swift:388`
- `mutating func set<V: Sendable>(_ key: String, to value: V)` — `StateKitTesting/Fixtures/StateTestFixtures.swift:32`
- `func build() -> [String: Any]` — `StateKitTesting/Fixtures/StateTestFixtures.swift:36`
- `static func randomInt(min: Int = 0, max: Int = 100) -> Int` — `StateKitTesting/Fixtures/StateTestFixtures.swift:46`
- `static func randomDouble(min: Double = 0, max: Double = 100) -> Double` — `StateKitTesting/Fixtures/StateTestFixtures.swift:51`
- `static func randomString(length: Int = 10) -> String` — `StateKitTesting/Fixtures/StateTestFixtures.swift:56`
- `static func randomBool() -> Bool` — `StateKitTesting/Fixtures/StateTestFixtures.swift:62`
- `static func randomDate( startDate: Date = Date(timeIntervalSince1970: 0), endDate: Date = Date() ) -> Date` — `StateKitTesting/Fixtures/StateTestFixtures.swift:67`
- `static func randomArray<T>( count: Int = 5, generator: () -> T` — `StateKitTesting/Fixtures/StateTestFixtures.swift:77`
- `init(base: T)` — `StateKitTesting/Fixtures/StateTestFixtures.swift:100`
- `mutating func set<V: Sendable>(_ keyPath: WritableKeyPath<T, V>, to value: V) -> Self` — `StateKitTesting/Fixtures/StateTestFixtures.swift:105`
- `mutating func modify(_ closure: @escaping (inout T) -> Void) -> Self` — `StateKitTesting/Fixtures/StateTestFixtures.swift:114`
- `func build() -> T` — `StateKitTesting/Fixtures/StateTestFixtures.swift:121`
- `static func minimal<T>() -> T? where T: Sendable` — `StateKitTesting/Fixtures/StateTestFixtures.swift:133`
- `static func typical<T>() -> T? where T: Sendable` — `StateKitTesting/Fixtures/StateTestFixtures.swift:139`
- `static func maximal<T>() -> T? where T: Sendable` — `StateKitTesting/Fixtures/StateTestFixtures.swift:144`
- `static func edgeCase<T>() -> T? where T: Sendable` — `StateKitTesting/Fixtures/StateTestFixtures.swift:149`
- `static func errorState<T>() -> T? where T: Sendable` — `StateKitTesting/Fixtures/StateTestFixtures.swift:154`
- `let data: T` — `StateKitTesting/Fixtures/StateTestFixtures.swift:166`
- `let timestamp: Date` — `StateKitTesting/Fixtures/StateTestFixtures.swift:169`
- `let description: String` — `StateKitTesting/Fixtures/StateTestFixtures.swift:172`
- `init( data: T, description: String = "" )` — `StateKitTesting/Fixtures/StateTestFixtures.swift:174`
- `func encodeToJSON() throws -> String` — `StateKitTesting/Fixtures/StateTestFixtures.swift:184`
- `static func decodeFromJSON(_ json: String) throws -> StateSnapshot<T>` — `StateKitTesting/Fixtures/StateTestFixtures.swift:192`
- `init()` — `StateKitTesting/Fixtures/StateTestFixtures.swift:212`
- `func register<T: Sendable>(_ key: String, fixture: @escaping () -> T)` — `StateKitTesting/Fixtures/StateTestFixtures.swift:215`
- `func get<T: Sendable>(_ key: String) -> T?` — `StateKitTesting/Fixtures/StateTestFixtures.swift:220`
- `func allKeys() -> [String]` — `StateKitTesting/Fixtures/StateTestFixtures.swift:225`
- `func clear()` — `StateKitTesting/Fixtures/StateTestFixtures.swift:230`
- `init(parameters: [(String, T)])` — `StateKitTesting/Fixtures/StateTestFixtures.swift:253`
- `func get(_ name: String) -> T?` — `StateKitTesting/Fixtures/StateTestFixtures.swift:258`
- `func all() -> [(String, T)]` — `StateKitTesting/Fixtures/StateTestFixtures.swift:263`
- `func map<U>(_ transform: (String, T) -> U) -> [U]` — `StateKitTesting/Fixtures/StateTestFixtures.swift:268`
- `func filter(_ predicate: (String, T) -> Bool) -> [(String, T)]` — `StateKitTesting/Fixtures/StateTestFixtures.swift:273`
- `static func sequence<T: Sendable>( start: T, count: Int, increment: (inout T) -> Void` — `StateKitTesting/Fixtures/StateTestFixtures.swift:283`
- `static func conditions<T: Sendable>( base: T, conditions: [(String, (inout T) -> Void)]` — `StateKitTesting/Fixtures/StateTestFixtures.swift:300`
- `static func cartesianProduct<A: Sendable, B: Sendable>( _ aValues: [A], _ bValues: [B] ) -> [(A, B)]` — `StateKitTesting/Fixtures/StateTestFixtures.swift:312`
- `static func weightedRandom<T: Sendable>( choices: [(value: T, weight: Int)] ) -> T` — `StateKitTesting/Fixtures/StateTestFixtures.swift:322`
- `static func assertEqual<T: Equatable & Sendable>( _ lhs: T, _ rhs: T, file: StaticString = #file, line: UInt = #line )` — `StateKitTesting/Fixtures/StateTestFixtures.swift:344`
- `static func assert<T: Sendable>( _ fixture: T, _ condition: (T) -> Bool, file: StaticString = #file, line: UInt = #line` — `StateKitTesting/Fixtures/StateTestFixtures.swift:360`
- `init()` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:25`
- `func addObserver(_ observer: ProviderObserver) -> Self` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:28`
- `func override<P: ProviderProtocol>( _ provider: P, with value: P.State ) -> Self` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:34`
- `func onSetup(_ callback: @escaping () -> Void) -> Self` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:43`
- `func build() -> ProviderContainer` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:49`
- `var testEnvironment: IntegrationTestEnvironment` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:89`
- `func assertStateConsistency<T: Sendable & Equatable>( provider: Provider<T>, expectedValue: T, container: ProviderContainer, message: String = "" )` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:101`
- `func measureFeaturePerformance( name: String, block: @escaping () async -> Void` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:116`
- `init()` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:145`
- `mutating func returns(_ value: T) -> Self` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:148`
- `mutating func withError(_ error: Error) -> Self` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:154`
- `mutating func withCallCount(_ callback: @escaping (Int) -> Void) -> Self` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:160`
- `func build() -> Provider<T>` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:166`
- `static func verifyTransition<T: Sendable & Equatable>( from: T, to: T, action: @escaping () async -> Void` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:182`
- `static func verifyConsistency<A: Sendable, B: Sendable>( provider1: Provider<A>, provider2: Provider<B>, predicate: (A, B) -> Bool, in container: Pro…` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:195`
- `static func verifyWithinTimeout<T: Sendable>( timeout: TimeInterval = 5.0, action: @escaping @Sendable () async -> T` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:207`
- `let name: String` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:243`
- `let container: ProviderContainer` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:244`
- `init( name: String, buildProvider: () -> Provider<State>` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:247`
- `var currentState: State` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:257`
- `func observe(_ callback: @escaping (State) -> Void)` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:262`
- `func generateReport() -> String` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:267`
- `let name: String` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:299`
- `init(_ name: String)` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:304`
- `mutating func given( _ block: @escaping (inout IntegrationTestEnvironment) -> Void` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:309`
- `mutating func when( _ block: @escaping (ProviderContainer) async -> Void` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:317`
- `mutating func then( _ block: @escaping (ProviderContainer) -> Void` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:325`
- `func run() async` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:334`
- `static func measureTime<T: Sendable>( action: @escaping () async -> T` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:358`
- `static func measureMemory<T: Sendable>( action: @escaping () async -> T` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:368`
- `static func comparePerformance<T: Sendable>( name1: String, action1: @escaping () async -> T, name2: String, action2: @escaping () async -> T` — `StateKitTesting/Integration/IntegrationTestHelpers.swift:377`
- `init()` — `StateKitTesting/Testing.swift:87`
- `func render<T>(_ body: @MainActor () -> T) -> T` — `StateKitTesting/Testing.swift:101`
- `func render<T>(environment: EnvironmentValues, _ body: @MainActor () -> T) -> T` — `StateKitTesting/Testing.swift:117`
- `func reset()` — `StateKitTesting/Testing.swift:129`

---

## `StateKitDevTools`

State history, profiling, debug observer, DevTools UI.

### Types

- **protocol `StateHistory`** — `StateKitDevTools/History/StateHistory.swift`
- **struct `HistoryEntry`** — `StateKitDevTools/History/StateHistory.swift`
- **enum `JSONValue`** — `StateKitDevTools/History/StateHistory.swift`
- **struct `AnyCodable`** — `StateKitDevTools/History/StateHistory.swift`
- **struct `InMemoryStateHistory`** — `StateKitDevTools/History/StateHistory.swift`
- **class `DebugProviderObserver`** — `StateKitDevTools/Observers/DebugProviderObserver.swift`
- **class `DevToolsObserver`** — `StateKitDevTools/Observers/DevToolsObserver.swift`
- **class `ConsoleLoggerObserver`** — `StateKitDevTools/Observers/DevToolsObserver.swift`
- **protocol `PerformanceMetrics`** — `StateKitDevTools/Performance/PerformanceMetrics.swift`
- **struct `PerformanceData`** — `StateKitDevTools/Performance/PerformanceMetrics.swift`
- **struct `InMemoryPerformanceMetrics`** — `StateKitDevTools/Performance/PerformanceMetrics.swift`
- **enum `StateKitDevTools`** — `StateKitDevTools/Public.swift`
- **enum `StateHookInspector`** — `StateKitDevTools/StateDevTools.swift`
- **struct `StateDevScope<Content: View>`** — `StateKitDevTools/StateDevTools.swift`
- **protocol `StateDevView`** — `StateKitDevTools/StateDevTools.swift`
- **extension `StateDevView`** — `StateKitDevTools/StateDevTools.swift`
- **struct `DevToolsHandle`** — `StateKitDevTools/UI/DevToolsHandle.swift`
- **struct `DevToolsMiniPanel`** — `StateKitDevTools/UI/DevToolsHandle.swift`
- **struct `DevToolsQuickStats`** — `StateKitDevTools/UI/DevToolsHandle.swift`
- **struct `StateDevTools`** — `StateKitDevTools/UI/DevToolsView.swift`

### Members (func/var/init)

- `let timestamp: Date` — `StateKitDevTools/History/StateHistory.swift:94`
- `let action: String?` — `StateKitDevTools/History/StateHistory.swift:97`
- `let stateBefore: JSONValue` — `StateKitDevTools/History/StateHistory.swift:100`
- `let stateAfter: JSONValue` — `StateKitDevTools/History/StateHistory.swift:103`
- `let computeTime: Double` — `StateKitDevTools/History/StateHistory.swift:106`
- `var isActive: Bool = false` — `StateKitDevTools/History/StateHistory.swift:109`
- `init( timestamp: Date, action: String?, stateBefore: JSONValue, stateAfter: JSONValue, computeTime: Double` — `StateKitDevTools/History/StateHistory.swift:111`
- `init(from decoder: Decoder) throws` — `StateKitDevTools/History/StateHistory.swift:137`
- `func encode(to encoder: Encoder) throws` — `StateKitDevTools/History/StateHistory.swift:160`
- `static func from(_ value: Any) -> JSONValue?` — `StateKitDevTools/History/StateHistory.swift:180`
- `let value: Any` — `StateKitDevTools/History/StateHistory.swift:194`
- `init(_ value: Any)` — `StateKitDevTools/History/StateHistory.swift:196`
- `init(from decoder: Decoder) throws` — `StateKitDevTools/History/StateHistory.swift:200`
- `func encode(to encoder: Encoder) throws` — `StateKitDevTools/History/StateHistory.swift:225`
- `var maxEntries: Int = 100` — `StateKitDevTools/History/StateHistory.swift:262`
- `var storeSnapshots: Bool = true` — `StateKitDevTools/History/StateHistory.swift:265`
- `var canGoBack: Bool` — `StateKitDevTools/History/StateHistory.swift:267`
- `var canGoForward: Bool` — `StateKitDevTools/History/StateHistory.swift:271`
- `var currentState: AnyCodable?` — `StateKitDevTools/History/StateHistory.swift:275`
- `mutating func record( action: String?, before: AnyCodable, after: AnyCodable, computeTime: Double )` — `StateKitDevTools/History/StateHistory.swift:280`
- `mutating func goBack() -> AnyCodable?` — `StateKitDevTools/History/StateHistory.swift:310`
- `mutating func goForward() -> AnyCodable?` — `StateKitDevTools/History/StateHistory.swift:316`
- `mutating func jumpTo(index: Int) -> AnyCodable?` — `StateKitDevTools/History/StateHistory.swift:322`
- `mutating func clear()` — `StateKitDevTools/History/StateHistory.swift:328`
- `func export() -> String` — `StateKitDevTools/History/StateHistory.swift:333`
- `mutating func importJSON(_ json: String) -> Bool` — `StateKitDevTools/History/StateHistory.swift:345`
- `func replay() async` — `StateKitDevTools/History/StateHistory.swift:358`
- `let filter: ((any ProviderProtocol) -> Bool)?` — `StateKitDevTools/Observers/DebugProviderObserver.swift:26`
- `init(filter: ((any ProviderProtocol) -> Bool)? = nil)` — `StateKitDevTools/Observers/DebugProviderObserver.swift:31`
- `func didAddProvider<P: ProviderProtocol>( _ provider: P, value: P.State, container: ProviderContainer )` — `StateKitDevTools/Observers/DebugProviderObserver.swift:39`
- `func didUpdateProvider<P: ProviderProtocol>( _ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer )` — `StateKitDevTools/Observers/DebugProviderObserver.swift:49`
- `func didDisposeProvider<P: ProviderProtocol>( _ provider: P, container: ProviderContainer )` — `StateKitDevTools/Observers/DebugProviderObserver.swift:61`
- `var maxHistoryEntries: Int` — `StateKitDevTools/Observers/DevToolsObserver.swift:45`
- `var maxMetricsRecords: Int` — `StateKitDevTools/Observers/DevToolsObserver.swift:51`
- `var storeSnapshots: Bool` — `StateKitDevTools/Observers/DevToolsObserver.swift:57`
- `var debugLoggingEnabled: Bool = false` — `StateKitDevTools/Observers/DevToolsObserver.swift:63`
- `init()` — `StateKitDevTools/Observers/DevToolsObserver.swift:67`
- `func didAddProvider<P: ProviderProtocol>( _ provider: P, value: P.State, container: ProviderContainer )` — `StateKitDevTools/Observers/DevToolsObserver.swift:74`
- `func didUpdateProvider<P: ProviderProtocol>( _ provider: P, previousValue: P.State, newValue: P.State, container: ProviderContainer )` — `StateKitDevTools/Observers/DevToolsObserver.swift:84`
- `func didDisposeProvider<P: ProviderProtocol>( _ provider: P, container: ProviderContainer )` — `StateKitDevTools/Observers/DevToolsObserver.swift:110`
- `func startComputation(providerName: String)` — `StateKitDevTools/Observers/DevToolsObserver.swift:131`
- `func endComputation(providerName: String, memoryBytes: Int = 0)` — `StateKitDevTools/Observers/DevToolsObserver.swift:142`
- `func recordAction( _ action: String, before: AnyCodable, after: AnyCodable, computeTime: Double = 0 )` — `StateKitDevTools/Observers/DevToolsObserver.swift:169`
- `func goBack() -> AnyCodable?` — `StateKitDevTools/Observers/DevToolsObserver.swift:187`
- `func goForward() -> AnyCodable?` — `StateKitDevTools/Observers/DevToolsObserver.swift:195`
- `func jumpToHistoryIndex(_ index: Int) -> AnyCodable?` — `StateKitDevTools/Observers/DevToolsObserver.swift:204`
- `func clearHistory()` — `StateKitDevTools/Observers/DevToolsObserver.swift:209`
- `func generateDebugReport() -> String` — `StateKitDevTools/Observers/DevToolsObserver.swift:216`
- `func exportAsJSON() -> String` — `StateKitDevTools/Observers/DevToolsObserver.swift:237`
- `let logPrefix: String` — `StateKitDevTools/Observers/DevToolsObserver.swift:277`
- `var logAdditions: Bool = false` — `StateKitDevTools/Observers/DevToolsObserver.swift:280`
- `var logUpdates: Bool = true` — `StateKitDevTools/Observers/DevToolsObserver.swift:283`
- `var logDisposals: Bool = false` — `StateKitDevTools/Observers/DevToolsObserver.swift:286`
- `init(prefix: String = "[StateKit]")` — `StateKitDevTools/Observers/DevToolsObserver.swift:288`
- `func didAddProvider<P: ProviderProtocol>( _ provider: P, value: P.State, container: ProviderContainer )` — `StateKitDevTools/Observers/DevToolsObserver.swift:292`
- `func didUpdateProvider<P: ProviderProtocol>( _ provider: P, previousValue: P.State, newValue: P.State, container: ProviderContainer )` — `StateKitDevTools/Observers/DevToolsObserver.swift:301`
- `func didDisposeProvider<P: ProviderProtocol>( _ provider: P, container: ProviderContainer )` — `StateKitDevTools/Observers/DevToolsObserver.swift:311`
- `let providerName: String` — `StateKitDevTools/Performance/PerformanceMetrics.swift:88`
- `let updateFrequency: Double` — `StateKitDevTools/Performance/PerformanceMetrics.swift:91`
- `let averageComputeTime: Double` — `StateKitDevTools/Performance/PerformanceMetrics.swift:94`
- `let totalCallCount: Int` — `StateKitDevTools/Performance/PerformanceMetrics.swift:97`
- `let estimatedMemory: Int` — `StateKitDevTools/Performance/PerformanceMetrics.swift:100`
- `let minComputeTime: Double` — `StateKitDevTools/Performance/PerformanceMetrics.swift:103`
- `let maxComputeTime: Double` — `StateKitDevTools/Performance/PerformanceMetrics.swift:106`
- `let totalComputeTime: Double` — `StateKitDevTools/Performance/PerformanceMetrics.swift:109`
- `let firstAccessTime: Date` — `StateKitDevTools/Performance/PerformanceMetrics.swift:112`
- `let lastUpdateTime: Date` — `StateKitDevTools/Performance/PerformanceMetrics.swift:115`
- `init( providerName: String, updateFrequency: Double, averageComputeTime: Double, totalCallCount: Int, estimatedMemory: Int,` — `StateKitDevTools/Performance/PerformanceMetrics.swift:117`
- `static func < (lhs: PerformanceData, rhs: PerformanceData) -> Bool` — `StateKitDevTools/Performance/PerformanceMetrics.swift:142`
- `var isSlowProvider: Bool` — `StateKitDevTools/Performance/PerformanceMetrics.swift:147`
- `var isFrequentlyUpdated: Bool` — `StateKitDevTools/Performance/PerformanceMetrics.swift:152`
- `var performanceScore: Int` — `StateKitDevTools/Performance/PerformanceMetrics.swift:157`
- `var maxRecordsPerProvider: Int = 1000` — `StateKitDevTools/Performance/PerformanceMetrics.swift:181`
- `var slowestProviders: [PerformanceData]` — `StateKitDevTools/Performance/PerformanceMetrics.swift:183`
- `var mostUpdated: [PerformanceData]` — `StateKitDevTools/Performance/PerformanceMetrics.swift:187`
- `var allMetrics: [PerformanceData]` — `StateKitDevTools/Performance/PerformanceMetrics.swift:191`
- `func updateFrequency(for providerName: String) -> Double` — `StateKitDevTools/Performance/PerformanceMetrics.swift:222`
- `func computeTime(for providerName: String) -> Double` — `StateKitDevTools/Performance/PerformanceMetrics.swift:226`
- `func callCount(for providerName: String) -> Int` — `StateKitDevTools/Performance/PerformanceMetrics.swift:230`
- `func memoryUsage(for providerName: String) -> Int` — `StateKitDevTools/Performance/PerformanceMetrics.swift:234`
- `mutating func recordUpdate( providerName: String, computeTime: Double, memoryBytes: Int )` — `StateKitDevTools/Performance/PerformanceMetrics.swift:238`
- `mutating func reset()` — `StateKitDevTools/Performance/PerformanceMetrics.swift:266`
- `func generateReport() -> String` — `StateKitDevTools/Performance/PerformanceMetrics.swift:272`
- `static let version = "2.2.0-beta"` — `StateKitDevTools/Public.swift:7`
- `static func createDevToolsObserver() -> DevToolsObserver` — `StateKitDevTools/Public.swift:13`
- `static func createConsoleLogger() -> ConsoleLoggerObserver` — `StateKitDevTools/Public.swift:21`
- `static func createDebugObserver( filter: ((any ProviderProtocol) -> Bool)? = nil` — `StateKitDevTools/Public.swift:30`
- `static func describe(_ any: Any) -> String` — `StateKitDevTools/StateDevTools.swift:17`
- `static func valueString(_ value: Any) -> String` — `StateKitDevTools/StateDevTools.swift:33`
- `let showOverlay: Bool` — `StateKitDevTools/StateDevTools.swift:66`
- `let overlayAlignment: Alignment` — `StateKitDevTools/StateDevTools.swift:67`
- `init( showOverlay: Bool = true, overlayAlignment: Alignment = .topLeading, @ViewBuilder content: @escaping @MainActor () -> Content` — `StateKitDevTools/StateDevTools.swift:71`
- `var body: some View` — `StateKitDevTools/StateDevTools.swift:82`
- `let observer: DevToolsObserver?` — `StateKitDevTools/UI/DevToolsHandle.swift:39`
- `var size: CGFloat = 60` — `StateKitDevTools/UI/DevToolsHandle.swift:42`
- `var backgroundColor: Color = .blue` — `StateKitDevTools/UI/DevToolsHandle.swift:45`
- `var foregroundColor: Color = .white` — `StateKitDevTools/UI/DevToolsHandle.swift:46`
- `init( showDevTools: Binding<Bool>, observer: DevToolsObserver? = nil, size: CGFloat = 60, backgroundColor: Color = .blue, foregroundColor: Color = .w…` — `StateKitDevTools/UI/DevToolsHandle.swift:48`
- `var body: some View` — `StateKitDevTools/UI/DevToolsHandle.swift:66`
- `init(observer: DevToolsObserver)` — `StateKitDevTools/UI/DevToolsHandle.swift:116`
- `var body: some View` — `StateKitDevTools/UI/DevToolsHandle.swift:128`
- `init(observer: DevToolsObserver)` — `StateKitDevTools/UI/DevToolsHandle.swift:227`
- `var body: some View` — `StateKitDevTools/UI/DevToolsHandle.swift:245`
- `init(observer: DevToolsObserver)` — `StateKitDevTools/UI/DevToolsView.swift:65`
- `var body: some View` — `StateKitDevTools/UI/DevToolsView.swift:69`

---

## `StateKitMacros`

48 public macro declarations (@StateAtom, @HookState, @Provider...).

### Types

- **macro `StateAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `ValueAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `TaskAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `ThrowingTaskAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `PublisherAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `Atom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `AtomFamily`** — `StateKitMacros/StateKitMacros.swift`
- **macro `SelectorFamily`** — `StateKitMacros/StateKitMacros.swift`
- **macro `AsyncTaskFamily`** — `StateKitMacros/StateKitMacros.swift`
- **macro `AtomReducer`** — `StateKitMacros/StateKitMacros.swift`
- **macro `Computed`** — `StateKitMacros/StateKitMacros.swift`
- **macro `SelectorAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `FilteredAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `MappedAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `CombineAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `DistinctAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `FlatMapAtom`** — `StateKitMacros/StateKitMacros.swift`
- **macro `RiverpodNotifier`** — `StateKitMacros/StateKitMacros.swift`
- **macro `RiverpodFamily`** — `StateKitMacros/StateKitMacros.swift`
- **macro `StateProvider`** — `StateKitMacros/StateKitMacros.swift`
- **macro `Provider`** — `StateKitMacros/StateKitMacros.swift`
- **macro `FutureProvider`** — `StateKitMacros/StateKitMacros.swift`
- **macro `StreamProvider`** — `StateKitMacros/StateKitMacros.swift`
- **macro `ProviderFamily`** — `StateKitMacros/StateKitMacros.swift`
- **macro `RiverpodSelector`** — `StateKitMacros/StateKitMacros.swift`
- **macro `RiverpodAsync`** — `StateKitMacros/StateKitMacros.swift`
- **macro `RiverpodFutureFamily`** — `StateKitMacros/StateKitMacros.swift`
- **macro `RiverpodStreamFamily`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookView`** — `StateKitMacros/StateKitMacros.swift`
- **macro `StateView`** — `StateKitMacros/StateKitMacros.swift`
- **macro `AsyncView`** — `StateKitMacros/StateKitMacros.swift`
- **macro `ObservableState`** — `StateKitMacros/StateKitMacros.swift`
- **macro `Hook`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookState`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookRef`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookToggle`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookEffect`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookLayoutEffect`** — `StateKitMacros/StateKitMacros.swift`
- **macro `AsyncHook`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookPrevious`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookInterval`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookMemo`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookCallback`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookReducer`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookContext`** — `StateKitMacros/StateKitMacros.swift`
- **macro `HookForm`** — `StateKitMacros/StateKitMacros.swift`
- **macro `Debounce`** — `StateKitMacros/StateKitMacros.swift`
- **macro `Throttle`** — `StateKitMacros/StateKitMacros.swift`

---

## Ghi chú cho AI agent

- **Không import `StateKitMacrosPlugin`** — đó là compiler plugin; chỉ dùng `@macro` từ module `StateKitMacros`.
- **Extension** được liệt kê ở phần Types vì chúng thêm API public cho type có sẵn (ví dụ `Task`, `AsyncSequence`, `MainActor`).
- Flow khuyến nghị khi viết tính năng mới: `StateKitCore` (đã re-export qua `StateKit`) → chọn state model (hooks / atom / provider) → UI ở `StateKitUI` → side effects ở `StateConcurrency` → test ở `StateKitTesting` → debug ở `StateKitDevTools`.
- Tài liệu chi tiết hơn: `docs/core/GUIDE.md`, `docs/macros/STATEKIT_V1_REFERENCE.md`, `docs/release/API_STABILITY.md`.