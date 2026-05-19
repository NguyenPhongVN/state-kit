import SwiftUI
import StateKitMacros

/// Generates `useCounterRefs()` as a hook that stores mutable refs.
///
/// `@HookRef` maps each stored property to a persistent `StateRef` slot.
/// In this example, `counter` persists across renders without triggering
/// an automatic re-render when it changes.
@HookRef
private struct CounterRefs {
    var counter: Int = 0
}

/// Demonstrates how `useRef`-style storage behaves in a `StateScope`.
///
/// Key behavior:
/// - Mutating `ref.counter` updates the ref immediately.
/// - Ref mutations do not re-render the UI by themselves.
/// - `syncedValue` is regular hook state, so assigning to it re-renders.
///
/// Interaction flow:
/// 1. Tap **Increment ref only** -> ref changes, UI may still show old synced value.
/// 2. Tap **Sync to UI** -> copies ref into hook state and refreshes display.
/// 3. Tap **Reset** -> clears both ref storage and UI state.
struct UseRef: View {
    var body: some View {
        StateScope {
            @HState var syncedValue = 0
            let ref = useCounterRefs()

            VStack(alignment: .leading, spacing: 12) {
                Text("Ref current value: \(ref.counter)")
                Text("Last synced to UI: \(syncedValue)")
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Increment ref only") { ref.counter += 1 }

                    Button("Sync to UI") { syncedValue = ref.counter }
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        ref.counter = 0
                        syncedValue = 0
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
