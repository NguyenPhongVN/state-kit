import SwiftUI

/// A case study demonstrating `useState` inside a `StateScope`.
///
/// ## Overview
///
/// `useState` is the foundational hook for managing local reactive state
/// within a `StateScope`. It behaves similarly to React's `useState` hook:
/// on the first render the state is initialized with the provided value;
/// on every subsequent render the previously stored value is returned and
/// the initial value is ignored.
///
/// This example tracks a simple integer counter. Each time the user taps
/// **Increment** the setter returned by `useState` is called with the next
/// value, which triggers a re-render with the updated count.
///
/// ## Usage
///
/// ```swift
/// StateScope {
///     let (count, setCount) = useState(0)
///
///     Button("Increment") {
///         setCount(count + 1)
///     }
/// }
/// ```
///
/// ## Key concepts
///
/// - **`useState(_:)`** — returns a `(Value, (Value) -> Void)` tuple:
///   the current value and a setter closure that updates it.
/// - **`StateScope`** — the SwiftUI view that establishes the hook runtime.
///   `useState` (and all other hooks) must be called inside a `StateScope`.
/// - **Hook ordering** — hooks are identified by their call-site position,
///   so they must always be called in the same order across renders (no
///   conditionals or loops around hook calls).
///
/// ## See Also
///
/// - ``useBinding(_:)`` — same as `useState` but returns a SwiftUI `Binding`.
/// - ``StateScope``
struct UseState: View {

    var body: some View {
        StateScope {
            let (count, countSetter) = useState(0)

            VStack(alignment: .leading, spacing: 12) {
                Text("Count: \(count)")
                    .font(.title3.monospacedDigit())

                HStack {
                    Button("-1") {
                        countSetter(count - 1)
                    }

                    Button("+1") {
                        countSetter(count + 1)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        countSetter(0)
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
