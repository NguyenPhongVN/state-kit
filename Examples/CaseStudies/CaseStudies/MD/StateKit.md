# StateKit Scoped API

Tai lieu nay tong hop day du scoped hook API cua `StateKit` dang duoc demo trong app `CaseStudies`.

| Nhom | API |
|------|-----|
| State | `useState`, `useBinding`, `useReducer`, `useRef`, `useMemo`, `useCallback` |
| Data Flow | `useContext`, `useEnvironment`, `useOnChange` |
| Effects | `useEffect`, `useLayoutEffect` |
| Async | `useAsync`, `useAsyncSequence`, `usePublisher` |
| Runtime | `StateScope`, `StateView`, `UpdateStrategy` |

## Runtime can biet truoc

### `StateScope`

Tat ca hook phai duoc goi ben trong `StateScope` hoac `StateView.stateBody`.

```swift
StateScope {
    let (count, setCount) = useState(0)
    Button("+1") { setCount(count + 1) }
}
```

### `StateView`

Neu muon viet view theo kieu hook-first, dung `StateView`.

```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)

        Button("Count: \\(count)") {
            setCount(count + 1)
        }
    }
}
```

### `UpdateStrategy`

Dung cho cac hook co dependency.

```swift
.once
.preserved(by: query)
.preserved(by: id, reloadToken)
```

---

## State Hooks

### `useState`

**Use case**

- Counter
- Toggle
- Local form state

**Example**

```swift
StateScope {
    let (count, setCount) = useState(0)

    Button("Increment") {
        setCount(count + 1)
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseState.swift`

### `useBinding`

**Use case**

- Noi truc tiep vao `TextField`
- Noi vao `Toggle`, `Slider`
- Truyen `Binding` xuong child view

**Example**

```swift
StateScope {
    let name = useBinding("")

    VStack {
        TextField("Name", text: name)
        Text(name.wrappedValue)
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseBinding.swift`

### `useReducer`

**Use case**

- State co nhieu action
- Workflow co transition ro rang
- Muon gom logic update vao mot reducer

**Example**

```swift
enum CounterAction {
    case increment
    case decrement
    case reset
}

StateScope {
    let (count, dispatch) = useReducer(0) { state, action in
        switch action {
        case .increment:
            state += 1
        case .decrement:
            state -= 1
        case .reset:
            state = 0
        }
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseReducer.swift`

### `useRef`

**Use case**

- Giu gia tri qua nhieu render
- Mutation khong duoc trigger UI
- Luu timer, cancellable, cache object, counter tam

**Example**

```swift
StateScope {
    let counterRef = useRef(0)
    let (snapshot, setSnapshot) = useState(0)

    Button("Increment ref only") {
        counterRef.value += 1
    }

    Button("Sync") {
        setSnapshot(counterRef.value)
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseRef.swift`

### `useMemo`

**Use case**

- Cache ket qua tinh toan
- Tranh tinh lai khi dependency khong doi
- Sort, filter, derive data

**Example**

```swift
StateScope {
    @SKScopeState var numberOne = 0

    let memo = useMemo(updateStrategy: .preserved(by: numberOne)) {
        "Memo token: \\(Int.random(in: 100...999))"
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseMemo.swift`

### `useCallback`

**Use case**

- Muon callback co identity on dinh
- Truyen callback xuong child view
- Dung callback lam dependency cho hook khac

**Example**

```swift
StateScope {
    @SKScopeState var query = "swift"

    let handler = useCallback(
        updateStrategy: .preserved(by: query),
        {
            print("Submit \\(query)")
        }
    )

    Button("Submit") {
        handler()
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseCallback.swift`

---

## Data Flow Hooks

### `useContext`

**Use case**

- Truyen shared reference qua nhieu view con
- Giu shared config, theme, session, demo data

**Example**

```swift
let themeContext = HookContext("Ocean")

struct Child: StateView {
    var stateBody: some View {
        let theme = useContext(themeContext)
        Text(theme)
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseContext.swift`

### `useEnvironment`

**Use case**

- Doc `colorScheme`
- Doc `locale`
- Doc `timeZone`
- Doc environment values ngay trong hook scope

**Example**

```swift
StateScope {
    let colorScheme = useEnvironment(\\.colorScheme)
    let locale = useEnvironment(\\.locale)
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseEnvironment.swift`

### `useOnChange`

**Use case**

- Theo doi dependency thay doi
- Chay side effect khi state doi
- Can ca old/new value hoac initial fire

**Example**

```swift
StateScope {
    @SKScopeState var query = ""

    let _ = useOnChange(query) { newValue in
        print("New:", newValue)
    }

    let _ = useOnChange(query) { oldValue, newValue in
        print(oldValue, "->", newValue)
    }

    let _ = useOnChange(query, initial: true) { value in
        print("Initial aware:", value)
    }
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseOnChange.swift`

---

## Effect Hooks

### `useEffect`

**Use case**

- Chay side effect sau render
- Dang ky / cleanup resource
- React voi dependency thay doi

**Example**

```swift
StateScope {
    @SKScopeState var isEnabled = false

    let _ = useEffect({
        print("effect run")

        guard isEnabled else { return nil }

        return {
            print("cleanup")
        }
    }, updateStrategy: .preserved(by: isEnabled))
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseEffect.swift`

### `useLayoutEffect`

**Use case**

- Muon effect layout-phase chay truoc passive effect
- Can observe order flush giua layout effect va effect thuong

**Example**

```swift
StateScope {
    @SKScopeState var step = 0

    let _ = useLayoutEffect({
        print("layout effect:", step)
        return nil
    }, updateStrategy: .preserved(by: step))
}
```

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseLayoutEffect.swift`

---

## Async Hooks

### `useAsync`

**Use case**

- Load mot resource
- Retry request
- Render theo `AsyncPhase`

**Example**

```swift
StateScope {
    @SKScopeState var userID = 1
    @SKScopeState var reloadToken = 0

    let phase = useAsync(
        updateStrategy: .preserved(by: [AnyHashable(userID), AnyHashable(reloadToken)])
    ) {
        try await api.fetchUser(id: userID)
    }
}
```

**Phase**

- `.idle`
- `.loading`
- `.success(Value)`
- `.failure(Error)`

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseAsync.swift`

### `useAsyncSequence`

**Use case**

- Theo doi stream async
- Nhan tung element mot
- Render theo `AsyncSequencePhase`

**Example**

```swift
StateScope {
    @SKScopeState var streamID = 1

    let phase = useAsyncSequence(.preserved(by: streamID)) {
        AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.finish()
        }
    }
}
```

**Phase**

- `.idle`
- `.loading`
- `.value(Element)`
- `.finished`
- `.failure(Error)`

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseAsyncSequence.swift`

### `usePublisher`

**Use case**

- Subscribe Combine publisher
- Render event moi nhat
- Restart publisher khi dependency doi

**Example**

```swift
StateScope {
    @SKScopeState var publisherID = 1

    let phase = usePublisher(updateStrategy: .preserved(by: publisherID)) {
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .prefix(3)
            .map { _ in "tick" }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
```

**Phase**

- `.idle`
- `.value(Output)`
- `.finished`
- `.failure(Error)`

**Demo source**

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UsePublisher.swift`

---

## Support Wrappers hay dung cung scoped hooks

### `@SKScopeState`

Shortcut cho state dang `Binding`.

```swift
@SKScopeState var query = ""
TextField("Query", text: $query)
```

### `@SKScopeMemo`

Shortcut cho `useMemo`.

```swift
@SKScopeMemo(updateStrategy: .preserved(by: query))
var cached = query.uppercased()
```

### `@SKScopeRef`

Shortcut cho `useRef`.

```swift
@SKScopeRef var timer: Timer? = nil
```

---

## Demo files hien co

- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseState.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseBinding.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseReducer.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseRef.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseMemo.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseCallback.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseContext.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseEnvironment.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseOnChange.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseEffect.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseLayoutEffect.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseAsync.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UseAsyncSequence.swift`
- `Examples/CaseStudies/CaseStudies/ScopedStudies/UsePublisher.swift`

## Chon nhanh

| Tinh huong | API nen dung |
|------------|---------------|
| State don gian | `useState` |
| Can `Binding` cho SwiftUI control | `useBinding` |
| Nhieu action va reducer | `useReducer` |
| Giu mutable ref khong re-render | `useRef` |
| Cache gia tri tinh toan | `useMemo` |
| Giu on dinh callback | `useCallback` |
| Theo doi thay doi cua value | `useOnChange` |
| Doc shared object | `useContext` |
| Doc SwiftUI environment | `useEnvironment` |
| Side effect sau render | `useEffect` |
| Layout-phase effect | `useLayoutEffect` |
| One-shot async task | `useAsync` |
| Async stream | `useAsyncSequence` |
| Combine publisher | `usePublisher` |
