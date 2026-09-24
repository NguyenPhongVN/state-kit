# StateKit

A modular state-management toolkit for Swift and SwiftUI. StateKit combines three proven
models — each implemented the way you already know it — so you can pick the right tool for
each kind of state and mix them freely:

| Model | Module | Use it for |
|-------|--------|-----------|
| 🪝 **React-style hooks** | `StateKit` | Local, screen-scoped state (`useState`, `useEffect`, `useReducer`, …) |
| ⚛️ **Recoil/Jotai-style atoms** | `StateKitAtoms` | Global state graphs with derived values and automatic dependency tracking |
| 🌊 **Riverpod-style providers** | `Riverpods` | App-wide state with lifecycle: `autoDispose`, `cacheTime`, `keepAlive`, overrides |

Around these sit everything a production app needs: SwiftUI integration, Combine bridges,
persistence, caching, analytics, feature flags, dev tools, concurrency utilities, testing
helpers, and **48 compile-time macros**.

---

## Installation (Swift Package Manager)

```swift
dependencies: [
    .package(url: "https://github.com/NguyenPhongVN/state-kit", from: "2.0.0")
]
```

Then add only the products you need:

```swift
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
```

> **3.0.0 (on `main`)** is a conventions release: the `StateConcurrency` `SC*` types are
> renamed to `SK*` (e.g. `SKTaskDuration`, `SKConcurrencyLimiter`). See
> [MIGRATION_GUIDE.md](docs/release/MIGRATION_GUIDE.md) for a one-command migration.

## Modules

| Module | Purpose |
|--------|---------|
| `StateKitCore` | Runtime primitives (`StateContext`, `StateRuntime`, `StateSignal`, `StateRef`) |
| `StateKit` | Hooks API: `useState`, `useBinding`, `useEffect`, `useReducer`, `useMemo`, … |
| `StateKitUI` | SwiftUI integration: `StateScope`, `StateView`, phase views |
| `StateKitAtoms` | Atom store, atom protocols, selectors, atom hooks and effects |
| `Riverpods` | Provider container, notifiers, families, overrides, SwiftUI wrappers |
| `StateConcurrency` | `Task` helpers (`timeout`, `retry`, `gather`, `race`) + async streams |
| `StateKitCombine` | Combine bridge for atoms and phases |
| `StateKitSupport` | Property wrappers and ready-made helper hooks (`useLoadMore`, `useCountdown`, …) |
| `StateKitPersistence` | Keychain / UserDefaults / SwiftData persistence |
| `StateKitCache` | LRU, LFU, TTL and sliding-window caches with policies |
| `StateKitAnalytics` | Event tracking, funnels, cohorts, user journeys |
| `StateKitFeatureFlags` | Rollouts, cohorts, A/B testing |
| `StateKitDevTools` | State history, performance metrics, debug overlay |
| `StateKitTesting` | Deterministic and integration testing utilities |
| `StateKitMacros` | Macro declarations (48 public macros) |
| `StateKitMacrosPlugin` | Macro implementation (compiler plugin) |

## Quick examples

Local state with hooks:

```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)

        Button("Count: \(count)") { setCount(count + 1) }
    }
}
```

Global state with an atom, plus a derived value that updates itself:

```swift
@StateAtom
struct CounterAtom {
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

@Computed
struct DoubledAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> Int {
        context.watch(CounterAtom()) * 2
    }
}

struct AtomView: View {
    @SKState(CounterAtom()) private var count   // read + write
    @SKValue(DoubledAtom()) private var doubled // derived, read-only

    var body: some View {
        Stepper("Count: \(count)", value: $count)
        Text("Doubled: \(doubled)")
    }
}
```

Riverpod-style providers — `read` is a snapshot, `watch` registers interest:

```swift
enum CounterFeature {
    static let counter = StateProvider { _ in 0 }
}

struct FeatureView: View {
    @Watch(CounterFeature.counter) private var count   // reactive, auto-cleanup
    @Environment(\.providerContainer) private var container

    var body: some View {
        Button("Count: \(count)") {
            container.read(CounterFeature.counter.notifier).state += 1
        }
    }
}
```

## Learning path for newcomers

The Examples app ships a **"Start Here"** curriculum: 19 tiny lessons in 6 progressive
chapters (local state → atoms → providers → async & derived → persistence & caching →
architecture), each one concept, one screen, with plain-language explanations — ending in a
capstone mini-app. Open `Examples/CaseStudies/ReferenceExamplesApp` and start at the top.

## Macros

StateKit ships **48 public macros** across atoms, riverpods, views, hooks, and utilities:

- Atoms: `@StateAtom`, `@ValueAtom`, `@TaskAtom`, `@ThrowingTaskAtom`, `@Computed`, `@MappedAtom`, …
- Riverpods: `@RiverpodNotifier`, `@Provider`, `@FutureProvider`, `@StreamProvider`, …
- Views: `@StateView`, `@HookView`, `@AsyncView`, `@ObservableState`
- Hooks: `@Hook`, `@HookState`, `@HookEffect`, `@AsyncHook`, `@HookForm`, …

Full references: [docs/macros/STATEKIT_COMPLETE_MACROS_GUIDE.md](docs/macros/STATEKIT_COMPLETE_MACROS_GUIDE.md)
and [docs/macros/STATEKIT_V1_REFERENCE.md](docs/macros/STATEKIT_V1_REFERENCE.md).

## Documentation

| Section | Path |
|---------|------|
| Docs hub | [docs/DOCS.md](docs/DOCS.md) |
| Coding conventions (contributor entry point) | [docs/engineering/CODING_CONVENTIONS.md](docs/engineering/CODING_CONVENTIONS.md) |
| Hooks vs macros | [docs/core/HOOKS_VS_MACROS.md](docs/core/HOOKS_VS_MACROS.md) |
| Changelog & migration | [docs/release/](docs/release/) |

## Requirements

- Swift 6.2+
- iOS 17+ / macOS 14+ / tvOS 17+ / watchOS 10+ / visionOS 1+

## References & Inspiration

StateKit's models are deliberately modeled on these proven systems — when a concept feels
familiar, that's why:

| Reference | What StateKit borrows |
|---|---|
| [React — Reference](https://react.dev/reference/react) | The hooks model: positional hooks, effect cleanup, run-once defaults |
| [Recoil](https://recoiljs.org/) | The atom graph: derived atoms, dependency tracking, topological recomputation |
| [Jotai — Core `atom`](https://jotai.org/docs/core/atom) | Minimal atom authoring — small atoms composed into bigger ones |
| [Riverpod](https://riverpod.dev/) | Provider lifecycle: `read` vs `watch`, auto-dispose/keepAlive, overrides |

## Contributing

Start with the [Coding Conventions](docs/engineering/CODING_CONVENTIONS.md) — they define file
layout, naming, documentation, and the lint setup (`.swiftlint.yml`, `.swiftformat`). Every
behavior change ships with a failing-first test, and all fixes land with a changelog entry.

## License

MIT. See [LICENSE](LICENSE).
