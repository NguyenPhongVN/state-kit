import SwiftUI
import StateKitUI

let counterKey = StateKey<Int>("counter")
let counterKey2 = StateKey<Int>("counter2")

//struct UseCount: View {
//    
//    @WatchState(counterKey, default: 0)
//    var count
//    
//    var body: some View {
//        VStack {
//            Text("\(count)")
//            
//            Button("Increase") {
//                count += 1
//            }
//            
//            UseCount2()
//        }
//    }
//}
//
//struct UseCount2: View {
//    
//    @WatchState(counterKey, default: 0)
//    var count
//    
//    @ViewContext
//    var context
//    
//    var body: some View {
//        VStack {
//            Text("\(context.get(key: counterKey, default: 0))")
//            
//            Button("Increase") {
//                count += 1
//            }
//        }
//    }
//}


struct CounterProvider: Provider {
    func resolve(container: Container) -> StateSignal<Int> {
        StateSignal(0)
    }
}

struct UserProvider: @preconcurrency FamilyProvider {
    @MainActor func resolve(container: Container, param: Int) -> AsyncState<String> {
        let state = AsyncState<String>()
        
        state.load {
            try await Task.sleep(nanoseconds: 5000000000)
            return "AAA" + param.description
        }
        
        return state
    }
}

struct AppRoot: View {
    let container = Container()
    
    var body: some View {
        SharedStateView(container) {
            UserView()
        }
    }
}

struct CounterView: View {
    @Inject<CounterProvider> var state
    
    var body: some View {
        VStack {
            Text("\(state.value)")
            Button("++") {
                state.value += 1
            }
        }
    }
}

struct UserView: View {
    @InjectFamily<UserProvider>(param: 1) var userState
    
    var body: some View {
        switch userState.phase {
        case .idle, .loading:
            ProgressView()
        case .success(let string):
            Text(string)
        case .failure(let error):
            Text(error.localizedDescription)
            
        }
    }
}

#Preview {
    AppRoot()
}
