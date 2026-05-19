import SwiftUI
import StateKitMacros

/// Demonstrates reducer-style local state with nested `State` and `Action` types.
///
/// `@HookReducer` generates `useCounterReducer(initial:)` from this type.
/// The view can then dispatch actions instead of mutating state directly.
@HookReducer
private struct CounterReducer {

    enum Action {
        case increment
        case decrement
        case reset
    }

    struct State {
        var number: Int = 0
    }

    func reduce(_ state: inout State, action: Action) {
        switch action {
        case .increment:
            state.number += 1
        case .decrement:
            state.number -= 1
        case .reset:
            state.number = 0
        }
    }
}


/// Example screen for reducer-based local state.
///
/// Why this example matters:
/// - Keeps transition logic centralized inside `reduce`.
/// - Makes updates explicit and easier to test.
/// - Scales better than scattered setter calls as state grows.
struct UseReducer: View {
    var body: some View {
        StateScope {
            let (count, dispatch) = useCounterReducer(initial: .init(number: 0))

            VStack(alignment: .leading, spacing: 12) {
                Text("Count: \(count.number)")
                    .font(.title3.monospacedDigit())

                Text("All updates go through actions instead of direct state mutation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Decrement") { dispatch(.decrement) }
                    Button("Increment") { dispatch(.increment) }
                        .buttonStyle(.borderedProminent)
                    Button("Reset") { dispatch(.reset) }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
