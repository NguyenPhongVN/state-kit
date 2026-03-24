Now I'll create a comprehensive overview of StateKit's public APIs.

## StateKit: Comprehensive Public API Overview

StateKit is a React Hooks-inspired state management library for Swift/SwiftUI that provides a lightweight runtime with hooks, UI utilities, and testing support. Here's a complete guide to all public APIs:

---

## **Core Architecture**

### **StateContext** ([StateKitCore](Sources/StateKitCore/ScopedState/StateContext.swift))
Manages hook state storage and execution index for each render pass.

```swift
public final class StateContext {
    public var states: [Any] = []
    public var context: [Any] = []
    public private(set) var index: Int = 0
    
    public func nextIndex() -> Int  // Called by hooks internally
    public func reset()              // Reset index for new render
}
```

### **StateRuntime** ([StateKitCore](Sources/StateKitCore/ScopedState/StateRuntime.swift))
Static manager that sets up the hook execution environment.

```swift
@MainActor
public enum StateRuntime {
    public static var current: StateContext?
    public static func begin(_ context: StateContext)
    public static func end()
    
    // Convenience wrapper for hook execution
    public static func stateRun<T>(
        context: StateContext,
        body: () -> T
    ) -> T
}
```

Usage Example:
```swift
StateRuntime.begin(context)
let result = body()  // Hook code runs here
StateRuntime.end()
```

---

## **State Hooks** (StateKit)

### **useState** — Basic State Management
Returns current value and setter function.

```swift
@MainActor
public func useState<T>(_ initial: T) -> (T, ((T) -> Void))
```

**Example from Case Studies** ([UseState.swift](Examples/CaseStudies/CaseStudies/ScopedStudies/UseState.swift)):
```swift
struct CounterView: View {
    var body: some View {
        StateScope {
            let (count, setCount) = useState(0)
            
            VStack {
                Text("Count: \(count)")
                Button("Increment") {
                    setCount(count + 1)
                }
            }
        }
    }
}
```

### **useReducer** — Advanced State with Actions
Manages complex state with action dispatching (Redux-like pattern).

```swift
@MainActor
public func useReducer<Action, State>(
    _ initial: State,
    _ reduce: @escaping (inout State, Action) -> Void
) -> (State, (Action) -> Void)
```

**Example from Case Studies** ([UseReducer.swift](Examples/CaseStudies/CaseStudies/ScopedStudies/UseReducer.swift)):
```swift
enum CounterAction {
    case increment
    case decrement
}

struct CounterView: View {
    var body: some View {
        StateScope {
            let (count, dispatch): (Int, (CounterAction) -> Void) = useReducer(0) { state, action in
                switch action {
                case .increment:
                    state += 1
                case .decrement:
                    state -= 1
                }
            }
            
            VStack {
                Text("Count: \(count)")
                HStack {
                    Button("-") { dispatch(.decrement) }
                    Button("+") { dispatch(.increment) }
                }
            }
        }
    }
}
```

### **useMemo** — Value Memoization
Caches computation results based on dependencies.

```swift
@MainActor
public func useMemo<T>(_ compute: () -> T, deps: [AnyHashable]) -> T
public func useMemo<T>(_ compute: () -> T, _ deps: AnyHashable...) -> T
public func useMemo<T>(_ compute: () -> T) -> T  // Compute once
```

**Example from Case Studies** ([UseMemo.swift](Examples/CaseStudies/CaseStudies/ScopedStudies/UseMemo.swift)):
```swift
struct UseMemo: View {
    var body: some View {
        StateScope {
            @HState var numberOne = 0
            @HState var numberTwo = 0
            
            @HMemo(deps: [numberOne])
            var memo: Int = { Int.random(in: 1...100) }()
            
            VStack {
                Text("Memo: \(memo)")
                Button("Increment") { numberOne += 1 }
                Button("Increment 2") { numberTwo += 1 }
            }
        }
    }
}
```

### **useRef** — Non-Rendering References
Persists mutable values across renders without triggering re-renders.

```swift
@MainActor
public func useRef<T>(_ initial: T) -> StateRef<T>
```

**Example**:
```swift
struct TimerView: View {
    var body: some View {
        StateScope {
            let timerRef = useRef<Timer?>(nil)
            
            VStack {
                Button("Start timer") {
                    timerRef.value?.invalidate()
                    timerRef.value = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        print("tick")
                    }
                }
            }
        }
    }
}
```

### **useCallback** — Function Memoization
Preserves function identity based on dependencies.

```swift
@MainActor
func useCallback<T>(
    _ callback: T,
    deps: [AnyHashable]? = nil
) -> T
```

**Example**:
```swift
let memoizedHandler = useCallback({
    // Handler logic reused unless deps change
}, deps: [dependencyValue])
```

### **useEffect** — Side Effects with Cleanup
Runs effects after render with optional cleanup.

```swift
@MainActor 
public func useEffect(
    _ effect: @escaping () -> (() -> Void)?,
    deps: [AnyHashable]? = nil
)
```

**Example**:
```swift
useEffect({
    let subscription = publisher.sink { value in
        // Handle value
    }
    return {
        subscription.cancel()  // Cleanup
    }
}, deps: [publisher])
```

### **useLayoutEffect** — Post-Layout Effects
Runs effects after layout updates with manual disposal.

```swift
@MainActor
@discardableResult
public func useLayoutEffect<Deps: LayoutEffectDependencies>(
    key: AnyHashable,
    deps: Deps,
    _ effect: @escaping () -> (() -> Void)?
) -> () -> Void
```

---

## **Async Hooks** (StateKit)

### **useAsync** — Async Operation State
Handles Promise-like async operations with loading/success/failure states.

```swift
@MainActor
public func useAsync<Value>(
    _ operation: @escaping () async throws -> Value,
    deps: [AnyHashable]
) -> StateSignal<AsyncPhase<Value>>
```

Where `AsyncPhase<Value>` is:
```swift
public enum AsyncPhase<Value> {
    case idle
    case loading
    case success(Value)
    case failure(Error)
}
```

**Example**:
```swift
struct UserView: View {
    let userId: String
    
    var body: some View {
        StateScope {
            let userPhase = useAsync({
                try await api.fetchUser(id: userId)
            }, deps: [userId])
            
            switch userPhase.value {
            case .idle, .loading:
                ProgressView()
            case .success(let user):
                Text(user.name)
            case .failure(let error):
                Text(error.localizedDescription)
            }
        }
    }
}
```

### **useAsyncSequence** — Async Sequence Consumption
Consumes async sequences with state tracking.

```swift
@MainActor
public func useAsyncSequence<S: AsyncSequence>(
    _ sequence: @escaping () -> S,
    deps: [AnyHashable]
) -> StateSignal<AsyncPhase<S.Element>>
```

**Example**:
```swift
struct ClockView: View {
    var body: some View {
        StateScope {
            let tick = useAsyncSequence({
                AsyncTimerSequence(interval: .seconds(1))
                    .map { Date() }
            }, deps: [])
            
            switch tick.value {
            case .idle, .loading:
                ProgressView()
            case .success(let date):
                Text(date.formatted())
            case .failure(let error):
                Text(error.localizedDescription)
            }
        }
    }
}
```

### **usePublisher** — Combine Publisher Integration
Subscribes to Combine publishers with event tracking.

```swift
@MainActor
public func usePublisher<P: Publisher>(
    _ publisher: @escaping () -> P,
    deps: [AnyHashable]
) -> PublisherPhase<P.Output>
```

Where `PublisherPhase<Output>` is:
```swift
public enum PublisherPhase<Output> {
    case idle
    case value(Output)
    case finished
    case failure(Error)
}
```

**Example**:
```swift
struct SearchView: View {
    let service: SearchService
    let query: String
    
    var body: some View {
        StateScope {
            let phase = usePublisher({
                service.search(query: query)
            }, deps: [query])
            
            switch phase {
            case .idle:
                ProgressView()
            case .value(let results):
                List(results) { result in
                    Text(result.title)
                }
            case .finished:
                Text("Search completed")
            case .failure(let error):
                Text(error.localizedDescription)
            }
        }
    }
}
```

---

## **UI Utilities** (StateKitUI)

### **StateView** — Hook-Enabled View Protocol
SwiftUI View that automatically wraps hook code execution.

```swift
public protocol StateView: View {
    associatedtype StateBody: View
    
    @ViewBuilder @MainActor var stateBody: Self.StateBody { get }
}

@MainActor
public extension StateView {
    var body: some View {
        StateScope { stateBody }
    }
}
```

**Example**:
```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)
        
        VStack {
            Text("Count: \(count)")
            Button("Increment") { setCount(count + 1) }
        }
    }
}
```

### **StateScope** — Hook Execution Container
Creates execution environment for hooks.

```swift
public struct StateScope<Content: View>: View {
    @State private var context = StateContext
    let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content)
    
    public var body: some View
}
```

### **ViewContext** — Shared State Access
Property wrapper for accessing shared state store with dynamic member lookup.

```swift
@propertyWrapper
@dynamicMemberLookup
@MainActor 
public struct ViewContext: DynamicProperty {
    public var wrappedValue: StateStore
    public var projectedValue: Binding<StateStore>
    
    public subscript<U>(dynamicMember keyPath: KeyPath<StateStore, U>) -> U
    public subscript<U>(dynamicMember keyPath: WritableKeyPath<StateStore, U>) -> U
}
```

**Example**:
```swift
struct MyView: View {
    @ViewContext var viewContext
    
    var body: some View {
        Text(viewContext.wrappedValue.get(key: myKey, default: 0))
    }
}
```

---

## **Support Types** (StateKitCore)

### **StateSignal** — Observable State Value
Wraps state with observation system for SwiftUI reactivity.

```swift
@Observable
public final class StateSignal<T> {
    public var value: T
    public init(_ value: T)
}
```

### **StateRef** — Non-Observable Reference
Mutable reference without observation or re-render triggers.

```swift
public final class StateRef<T> {
    public var value: T
    public init(_ value: T)
}
```

### **StateStore** — Shared Global State
Observable state storage accessible across views via `StateKey`.

```swift
@MainActor
@Observable
public final class StateStore {
    public static let shared = StateStore()
    
    public func get<T>(
        key: StateKey<T>,
        default defaultValue: @autoclosure () -> T
    ) -> T
    
    public func set<T>(key: StateKey<T>, value: T)
    public func registerIfNeeded<T>(key: StateKey<T>, value: T)
}
```

### **StateKey** — Type-Safe State Key
Identifier for accessing state in StateStore.

```swift
public struct StateKey<T>: Hashable, Identifiable {
    public let name: String
    public init(_ name: String)
    public var id: String
}
```

---

## **Property Wrappers** (StateKitSupport)

### **@HState** — Hook State Binding
Provides binding-based state access via property wrapper.

```swift
@propertyWrapper
@MainActor
public struct HState<Node> {
    public init(wrappedValue: @escaping () -> Node)
    public init(wrappedValue: Node)
    public init(wrappedValue: @escaping () -> Binding<Node>)
    public init(wrappedValue: Binding<Node>)
    
    public var wrappedValue: Node
    public var projectedValue: Binding<Node>
}
```

**Example**:
```swift
StateScope {
    @HState var count = 0
    @HState var name = ""
    
    VStack {
        Text("Count: \(count)")
        TextField("Name", text: $name)
    }
}
```

### **@HMemo** — Property Wrapper Memoization
Memoizes computed values with dependency tracking.

```swift
@propertyWrapper
@MainActor
public struct HMemo<Node> {
    public init(wrappedValue compute: @autoclosure @escaping () -> Node, 
                deps: [AnyHashable])
    public init(wrappedValue compute: @autoclosure @escaping () -> Node, 
                _ deps: AnyHashable...)
    public init(wrappedValue compute: @autoclosure @escaping () -> Node)
    
    public var wrappedValue: Node
}
```

**Example**:
```swift
StateScope {
    @HState var a = 5
    
    @HMemo(deps: [a])
    var expensive = computeHeavyValue(a)
}
```

### **@HRef** — Reference Property Wrapper
Wraps `useRef` for property-based reference access.

```swift
@propertyWrapper
@MainActor 
public struct HRef<Node> {
    public init(wrappedValue initial: @autoclosure @escaping () -> Node)
    public init(wrappedValue initial: @escaping () -> Node)
    
    public var wrappedValue: Node
    public var projectedValue: StateRef<Node>
}
```

**Example**:
```swift
StateScope {
    @HRef var timerRef: Timer? = nil
    
    Button("Start") {
        timerRef = Timer.scheduledTimer(...)
    }
}
```

---

## **Testing Utilities** (StateKitTesting)

### **StateTest** — Hook Testing Harness
Lightweight testing framework for hooks without SwiftUI.

```swift
@MainActor
public final class StateTest {
    public let context: StateContext
    public private(set) var renderCount: Int
    
    public init(context: StateContext = StateContext())
    
    @discardableResult
    public func render<T>(_ body: () -> T) -> T
    
    public func renderAndCaptureStates<T>(_ body: () -> T) -> (result: T, states: [Any])
    
    public func reset()
}
```

**Example**:
```swift
import Testing
import StateKit
import StateKitTesting

@Test @MainActor
func useState_persistsAcrossRenders() {
    let test = StateTest()
    
    let first = test.render {
        useState(0).1(0)  // Initial state
        let (count, setter) = useState(0)
        return count
    }
    expect(first == 0)
    
    _ = test.render {
        let (count, setter) = useState(0)
        setter(5)
        return count
    }
    
    let result = test.render {
        let (count, _) = useState(0)
        return count
    }
    expect(result == 5)  // State persists
}
```

---

## **Environment Access**

### **useEnvironment** — SwiftUI Environment Access
Reads SwiftUI environment values from hook context.

```swift
@MainActor
public func useEnvironment<Value>(
    _ keyPath: KeyPath<EnvironmentValues, Value>
) -> Value
```

**Example**:
```swift
StateScope {
    let colorScheme = useEnvironment(\.colorScheme)
    
    if colorScheme == .dark {
        // Dark mode UI
    }
}
```

---

## **Module Organization**

| Module | Purpose |
|--------|---------|
| **StateKitCore** | Core types: `StateContext`, `StateRuntime`, `StateSignal`, `StateRef`, `StateStore`, `StateKey` |
| **StateKit** | All hook functions: `useState`, `useReducer`, `useMemo`, `useAsync`, `usePublisher`, etc. |
| **StateKitUI** | SwiftUI integration: `StateView`, `StateScope`, `ViewContext` |
| **StateKitSupport** | Property wrappers: `@HState`, `@HMemo`, `@HRef` |
| **StateKitCombine** | Combine framework bridge |
| **StateKitTesting** | Testing utilities: `StateTest` |
| **StateKitDevTools** | Development tools |

---

## **Key Patterns**

1. **All hooks must be called within `StateRuntime.current` context** (set up by `StateScope` or `StateView`)
2. **Hook order must be stable** across renders (call hooks at top level, never conditionally)
3. **Dependencies** control re-execution of memoized values and effects
4. **Thread safety**: All APIs are `@MainActor` for SwiftUI safety
5. **Automatic cleanup**: Tasks and subscriptions cancel when scope deallocates
