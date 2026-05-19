# StateKit

StateKit is a modular state management toolkit for Swift and SwiftUI.

It combines three complementary models:

- Hooks-style local state (`StateKit`)
- Atom-based global state graph (`StateKitAtoms`)
- Provider/notifier global logic (`Riverpods`)

It also ships concurrency utilities, testing helpers, devtools, and compile-time macros.

## Documentation

Start here:

- `docs/DOCS.md`

Key sections:

- `docs/core/README.md`
- `docs/macros/README.md`
- `docs/release/README.md`
- `docs/engineering/README.md`

## Installation (Swift Package Manager)

```swift
dependencies: [
    .package(url: "https://github.com/NguyenPhongVN/state-kit", from: "1.0.0")
]
```

Then add only the products you need:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "StateKit", package: "state-kit"),
            .product(name: "StateKitUI", package: "state-kit"),
            .product(name: "StateKitAtoms", package: "state-kit"),
            .product(name: "Riverpods", package: "state-kit"),
            .product(name: "StateKitMacros", package: "state-kit")
        ]
    )
]
```

## Main Modules

| Module | Purpose |
|---|---|
| `StateKitCore` | Runtime primitives (`StateContext`, `StateRuntime`, `StateSignal`, `StateRef`) |
| `StateKit` | Hooks API (`useState`, `useReducer`, `useEffect`, `useAsync`, `useBinding`, ...) |
| `StateKitUI` | UI integration (`StateScope`, `StateView`, phase views) |
| `StateKitAtoms` | Atom store, atom protocols, selectors, atom hooks |
| `Riverpods` | Provider container, notifiers, families, overrides, SwiftUI wrappers |
| `StateKitMacros` | Macro declarations (47 public macros in V1) |
| `StateKitMacrosPlugin` | Macro implementation plugin |
| `StateConcurrency` | `Task` helpers (`retry`, `timeout`, `gather`, `race`) + async streams |
| `StateKitSupport` | Property wrappers and helper hooks |
| `StateKitTesting` | Deterministic and integration testing utilities |
| `StateKitDevTools` | State history and profiling tools |
| `StateKitCombine` | Combine bridge for atoms/phases |
| `StateKitPersistence` | UserDefaults/Keychain/SwiftData persistence helpers |
| `StateKitAnalytics` | Analytics and user journey tracking |
| `StateKitCache` | Cache policies and cache implementations |
| `StateKitFeatureFlags` | Rollout and feature flag utilities |

## Quick Examples

### Local hook state

```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)
        Button("Count: \(count)") { setCount(count + 1) }
    }
}
```

### Riverpod-style global state

```swift
final class CounterNotifier: Notifier<Int> {
    override func build() -> Int { 0 }
    func increment() { state += 1 }
}

let counterProvider = NotifierProvider { CounterNotifier() }
```

### Atom-style global state

```swift
@StateAtom
struct CounterAtom {
    func defaultValue(context: Context) -> Int { 0 }
}
```

## Macros (V1)

StateKit V1 ships **47 public macros** across:

- Atoms
- Riverpods
- Views
- Hooks
- Utility macros

Macro docs:

- `docs/macros/STATEKIT_COMPLETE_MACROS_GUIDE.md`
- `docs/macros/STATEKIT_V1_REFERENCE.md`

## Requirements

- Swift 6.2+
- Apple platforms aligned with package targets

## License

MIT. See `LICENSE`.
