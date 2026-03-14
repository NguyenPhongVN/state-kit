import SwiftUI

enum CounterAction {
    case increment
    case decrement
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
                }
            }
            
            Text("Count: \(count)")
            Button("Increment") { dispatch(.increment) }
            Button("Decrement") { dispatch(.decrement) }
        }
    }
}
