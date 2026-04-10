# StateKitUI

SwiftUI integration layer for StateKit. Provides hook-based views, atom scope providers, and dependency injection property wrappers.

**Dependencies:** `StateKit`, `StateKitCore`, `StateKitAtoms`

---

## Overview

| Group | What it provides |
|---|---|
| `ScopedState` | `StateView`, `StateScope` — hook-based local state |
| `SharedState` | `SKAtomRoot`, `SKAtomScopeView`, `SharedStateView`, `ViewContext`, `Inject`, `Watch` |

---

## Scoped State (Hook-based)

### `StateView`

A SwiftUI protocol that opts into the hook runtime. Implement `stateBody` instead of `body` — hooks (`useState`, `useReducer`, `useAsync`, `useMemo`, `useRef`) are available inside it.

```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useStateSet(0)
        VStack {
            Text("Count: \(count)")
            Button("Increment") { setCount(count + 1) }
        }
    }
}
```

`StateView` automatically wraps `stateBody` in a `StateScope`, so hooks work without any extra setup.

### `StateScope`

Low-level container that enables the hook runtime for arbitrary SwiftUI content. Use this when you cannot conform to `StateView` (e.g. wrapping third-party views).

```swift
StateScope {
    let (text, setText) = useState("")
    TextField("Name", text: Binding(get: { text }, set: setText))
}
```

---

## Atom State

### `SKAtomRoot`

Place once near the root of your app to provide an `SKAtomStore` to all descendants. Every atom property wrapper in the subtree resolves against this store.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .atomRoot()
        }
    }
}
```

Nesting is supported — inner `SKAtomRoot` views provide their own store, and atoms resolve against the innermost root.

### `SKAtomScopeView`

Provides an isolated `SKAtomStore` to a subtree. Useful for previews, tests, modal sheets, or any component that needs clean, independent atom state.

```swift
// Fresh empty store
SKAtomScopeView {
    MyFeatureView()
}

// Preconfigured store
SKAtomScopeView(store: preloadedStore) {
    MyFeatureView()
}
```

View modifier equivalents:

```swift
MyFeatureView().atomScope()
MyFeatureView().atomScope(store: preloadedStore)
```

---

## Dependency Injection

### `@ViewContext`

Property wrapper that exposes a `StateStore` instance with `@dynamicMemberLookup` support. Provides both direct access and `Binding` projection.

```swift
struct ProfileView: View {
    @ViewContext var context

    var body: some View {
        Text(context.userName)       // direct access
        TextField("Name", text: $context.userName)  // Binding
    }
}
```

### `@Inject`

Resolves a `Provider` value from the nearest `Container` in the environment.

```swift
struct ApiView: View {
    @Inject var apiClient: ApiClient

    var body: some View {
        Button("Fetch") { apiClient.fetch() }
    }
}
```

### `@InjectFamily`

Resolves a parameterized `FamilyProvider` value.

```swift
struct UserView: View {
    @InjectFamily(param: userId) var user: User

    var body: some View {
        Text(user.name)
    }
}
```

### `@Watch`

Resolves a `Provider` value and re-renders the view whenever it changes.

```swift
struct StatusView: View {
    @Watch var status: AppStatus

    var body: some View {
        Text(status.description)
    }
}
```

### `SharedStateView`

Injects a child `Container` into its subtree. Use to scope dependency overrides to a sub-tree without affecting the parent.

```swift
SharedStateView(parentContainer) {
    ChildFeatureView()
}
```

---

## Directory Structure

```
StateKitUI/
├── ScopedState/
│   ├── StateView.swift       # StateView protocol
│   └── StateScope.swift      # Hook runtime container
├── SharedState/
│   ├── SKAtomRoot.swift      # Root atom store provider
│   ├── SKAtomScope.swift     # Isolated atom scope
│   ├── SharedStateView.swift # Container-scoped DI view
│   └── ViewContext.swift     # @ViewContext, @Inject, @InjectFamily, @Watch
└── Internal/
    ├── Export.swift          # Re-exports StateKitCore
    └── TypeName.swift        # Type name formatting utility
```
