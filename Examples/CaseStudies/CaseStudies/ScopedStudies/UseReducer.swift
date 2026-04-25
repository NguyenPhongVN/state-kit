import SwiftUI

enum CounterAction {
    case increment
    case decrement
    case reset
}

struct UseReducer: View {
    var body: some View {
        StateScope {
            let (count, dispatch): (Int, (CounterAction) -> Void) = useReducer(0) { state, action in
                switch action {
                case .increment:
                    state += 1
                case .decrement:
                    state -= 1
                case .reset:
                    state = 0
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Count: \(count)")
                    .font(.title3.monospacedDigit())

                Text("Moi thao tac di qua action, thay vi goi setter truc tiep.")
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
