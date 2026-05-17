# 📊 View & Riverpod Macros Analysis & Recommendations

## Current Status

**Existing Macros:**
- ✅ 1 View Macro: @HookView (generates body with StateScope)
- ✅ 1 Riverpod Macro: @riverpodNotifier (generates NotifierProvider from class)

---

## Code Analysis

### View Patterns in StateKit

#### 1. StateView Protocol (Already exists)
```swift
public protocol StateView: View {
    var stateBody: some View { get }
}

// Default body implementation wraps in StateScope
public extension StateView {
    var body: some View {
        StateScope { stateBody }
    }
}
```

Current usage: 7+ views in examples use StateView pattern

#### 2. View with Atom Integration
```swift
struct CounterView: View {
    @SKState(counterAtom) var count
    @SKContext var atomContext
    
    var body: some View {
        VStack {
            Text("\(count)")
            Button("Increment") { 
                atomContext.write(counterAtom) { $0 += 1 }
            }
        }
    }
}
```

Pattern: Manual property wrapper usage + context access

#### 3. Async Phase Handling
```swift
struct ProfileView: View {
    @SKTask(fetchUserAtom) var userPhase
    
    var body: some View {
        switch userPhase {
        case .idle, .loading:
            ProgressView()
        case .success(let user):
            Text(user.name)
        case .failure(let error):
            Text("Error: \(error.localizedDescription)")
        }
    }
}
```

Pattern: Manual switch statement for AsyncPhase

#### 4. List with Atom Bindings
```swift
struct TodoListView: View {
    @SKState(todosAtom) var todos
    
    var body: some View {
        List {
            ForEach($todos, id: \.id) { $todo in
                TextField("Task", text: $todo.title)
            }
        }
    }
}
```

Pattern: List of bindable state items

---

### Riverpod Patterns in StateKit

#### 1. Simple StateProvider
```swift
let counterProvider = StateProvider { _ in 0 }
```

#### 2. Derived Provider
```swift
let doubleCounterProvider = Provider { ref in
    let count = ref.watch(counterProvider)
    return count * 2
}
```

#### 3. Notifier Provider (Has @riverpodNotifier macro)
```swift
@riverpodNotifier
class TodoNotifier: Notifier<[String]> {
    override func build() -> [String] { [...] }
    
    func add(_ todo: String) {
        state.append(todo)
    }
}
// Generates: public let todoNotifierProvider = NotifierProvider { TodoNotifier() }
```

#### 4. AsyncNotifier Provider (Has @riverpodNotifier macro)
```swift
@riverpodNotifier
class UserProfileNotifier: AsyncNotifier<String> {
    override func build() async throws -> String { ... }
    
    func updateName(_ newName: String) async { ... }
}
// Generates: public let userProfileNotifierProvider = AsyncNotifierProvider { UserProfileNotifier() }
```

#### 5. FutureProvider
```swift
let weatherProvider = FutureProvider { _ in
    try await Task.sleep(nanoseconds: 1_000_000_000)
    return "Sunny ☀️"
}
```

Pattern: Inline closure for one-shot async

#### 6. StreamProvider
```swift
let clockProvider = StreamProvider { _ in
    Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .map { "\($0.formatted(date: .omitted, time: .standard))" }
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}
```

Pattern: Inline closure for continuous streams

#### 7. Family Provider
```swift
let userDetailProvider = Provider.family { (ref, id: Int) in
    "User Details for ID: \(id)"
}
```

Pattern: Manual family wrapper

---

## 🎯 Recommended New Macros

### HIGH PRIORITY (View Macros)

#### 1. **@StateView** — Auto-conform to StateView protocol
```swift
// Before: Manual body boilerplate
struct CounterView: StateView {
    var stateBody: some View {
        // ...
    }
}

// After: Macro handles StateView conformance
@StateView
struct CounterView {
    var body: some View {
        // Uses hooks directly - @StateView wraps in StateScope
        let (count, setCount) = useState(0)
        
        VStack {
            Text("\(count)")
            Button("Inc") { setCount(count + 1) }
        }
    }
}
```

**Boilerplate Saved:** StateView protocol conformance, stateBody naming  
**Pattern Frequency:** 7+ examples  
**Recommendation:** ⭐⭐⭐ Implement

---

#### 2. **@AsyncView** — Auto-handle AsyncPhase switch statements
```swift
// Before: Manual switch
struct ProfileView: View {
    @SKTask(fetchUserAtom) var userPhase
    
    var body: some View {
        switch userPhase {
        case .idle, .loading:
            ProgressView()
        case .success(let user):
            Text(user.name)
        case .failure(let error):
            Text("Error: \(error.localizedDescription)")
        }
    }
}

// After: Macro generates switch scaffold
@AsyncView(fetchUserAtom, loadingView: { ProgressView() })
struct ProfileView {
    func successView(_ user: User) -> some View {
        Text(user.name)
    }
    
    func failureView(_ error: Error) -> some View {
        Text("Error: \(error.localizedDescription)")
    }
}
```

**Boilerplate Saved:** Eliminates switch statement boilerplate  
**Pattern Frequency:** 4+ async views in examples  
**Recommendation:** ⭐⭐ Nice to have

---

#### 3. **@AtomView** — For views using only atoms (no hooks)
```swift
// Before: Manual property wrappers
struct CounterView: View {
    @SKState(counterAtom) var count
    @SKValue(doubleAtom) var doubled
    
    var body: some View {
        Text("\(count) → \(doubled)")
    }
}

// After: Auto-inject atoms from properties
@AtomView
struct CounterView {
    let counterAtom: SKAtomKey
    let doubleAtom: SKAtomKey
    
    var body: some View {
        // Macro auto-injects as @SKState and @SKValue
        Text("\(count) → \(doubled)")
    }
}
```

**Boilerplate Saved:** Property wrapper declarations  
**Pattern Frequency:** 3+ atom-only views  
**Recommendation:** ⭐⭐ Consider

---

### HIGH PRIORITY (Riverpod Macros)

#### 4. **@StateProvider** — Generate StateProvider from simple value
```swift
// Before: Manual inline provider
let counterProvider = StateProvider { _ in 0 }
let nameProvider = StateProvider { _ in "Alice" }

// After: Struct-based with macro
@StateProvider
struct CounterProvider {
    static let initial = 0
}
// Generates: public let counterProvider = StateProvider { _ in 0 }

@StateProvider
struct NameProvider {
    static let initial = "Alice"
}
// Generates: public let nameProvider = StateProvider { _ in "Alice" }
```

**Boilerplate Saved:** Eliminates inline closure  
**Pattern Frequency:** 2+ examples  
**Recommendation:** ⭐⭐⭐ Implement

---

#### 5. **@Provider** — Generate derived Provider from function
```swift
// Before: Manual Provider { ref in ... }
let doubleCounterProvider = Provider { ref in
    let count = ref.watch(counterProvider)
    return count * 2
}

// After: Simple function-based
@Provider(watching: counterProvider)
func doubleCounterProvider(ref: ProviderRef) -> Int {
    let count = ref.watch(counterProvider)
    return count * 2
}
// Generates: public let doubleCounterProvider = Provider { ref in ... }
```

**Boilerplate Saved:** Eliminates Provider { } wrapper  
**Pattern Frequency:** 1-2 examples  
**Recommendation:** ⭐⭐ Consider

---

#### 6. **@FutureProvider** — Generate FutureProvider from async function
```swift
// Before: Manual inline FutureProvider
let weatherProvider = FutureProvider { _ in
    try await Task.sleep(nanoseconds: 1_000_000_000)
    return "Sunny ☀️"
}

// After: Async function-based
@FutureProvider
func weatherProvider() async -> String {
    try await Task.sleep(nanoseconds: 1_000_000_000)
    return "Sunny ☀️"
}
// Generates: public let weatherProvider = FutureProvider { _ in ... }
```

**Boilerplate Saved:** Eliminates FutureProvider wrapper  
**Pattern Frequency:** 1 example  
**Recommendation:** ⭐⭐ Consider

---

#### 7. **@StreamProvider** — Generate StreamProvider from function
```swift
// Before: Manual inline StreamProvider
let clockProvider = StreamProvider { _ in
    Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .map { "\($0.formatted(date: .omitted, time: .standard))" }
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}

// After: Function-based
@StreamProvider
func clockProvider() -> AnyPublisher<String, Error> {
    Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .map { "\($0.formatted(date: .omitted, time: .standard))" }
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}
// Generates: public let clockProvider = StreamProvider { _ in ... }
```

**Boilerplate Saved:** Eliminates StreamProvider wrapper  
**Pattern Frequency:** 1 example  
**Recommendation:** ⭐⭐ Consider

---

#### 8. **@NotifierProvider** — Enhanced version of @riverpodNotifier
```swift
// Same as @riverpodNotifier but with additional scaffolding
@NotifierProvider
class TodoNotifier: Notifier<[String]> {
    override func build() -> [String] { [...] }
    
    func add(_ todo: String) { ... }
    func remove(at index: Int) { ... }
}
// Generates:
// public let todoNotifierProvider = NotifierProvider { TodoNotifier() }
// Plus: Helper extensions for easier access patterns
```

**Boilerplate Saved:** Same as @riverpodNotifier, but renamed for clarity  
**Pattern Frequency:** Existing macro already implemented  
**Recommendation:** ⭐ Alias/rename existing macro

---

### MEDIUM PRIORITY

#### 9. **@ProviderFamily** — Generate family provider from function
```swift
// Before: Manual Provider.family
let userDetailProvider = Provider.family { (ref, id: Int) in
    "User Details for ID: \(id)"
}

// After: Function-based
@ProviderFamily
func userDetailProvider(ref: ProviderRef, id: Int) -> String {
    "User Details for ID: \(id)"
}
// Generates: public let userDetailProvider = Provider.family { (ref, id) in ... }
```

**Boilerplate Saved:** Eliminates Provider.family wrapper  
**Pattern Frequency:** 1 example  
**Recommendation:** ⭐ Defer for now

---

## Summary Recommendation

### Implement in Phase 1 (3 macros, ~2 hours)

1. **@StateView** ⭐⭐⭐ — Convenience for hook-based views
2. **@StateProvider** ⭐⭐⭐ — Simple provider generation
3. **@Provider** ⭐⭐ — Derived provider generation

**Result:** 3 new macros (total: 24 macros in StateKit)

### Consider in Phase 2 (4 macros)

4. **@AsyncView** ⭐⭐ — Async phase handling
5. **@FutureProvider** ⭐⭐ — One-shot async provider
6. **@StreamProvider** ⭐⭐ — Continuous stream provider
7. **@ProviderFamily** ⭐ — Family provider generation

---

## Implementation Complexity

| Macro | Type | Complexity | Est. Time |
|-------|------|-----------|-----------|
| @StateView | MemberMacro | Low | 30 min |
| @StateProvider | PeerMacro | Low | 30 min |
| @Provider | PeerMacro | Low-Med | 40 min |
| @AsyncView | MemberMacro | Medium | 45 min |
| @FutureProvider | PeerMacro | Low | 30 min |
| @StreamProvider | PeerMacro | Low | 30 min |
| @ProviderFamily | PeerMacro | Medium | 40 min |

---

## Final Macro Count

After implementing Phase 1:

| Category | Count |
|----------|-------|
| Atom Macros | 9 |
| Hook Macros | 10 |
| View Macros | **4** (1 existing + 3 new) |
| Riverpod Macros | **4** (1 existing + 3 new) |
| **Total** | **27** |

After Phase 2: **34 macros total**
