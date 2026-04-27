import SwiftUI
import Riverpods

struct RiverpodNotifierView: View {
    // Notifier example
    @Watch(todoListProvider) var todos
    @Watch(todoListProvider.notifier) var todoNotifier
    
    // AsyncNotifier example
    @Watch(userProfileProvider) var profileValue
    @Watch(userProfileProvider.notifier) var profileNotifier
    
    var body: some View {
        Form {
            Section("Notifier: Todo List") {
                ForEach(Array(todos.enumerated()), id: \.offset) { index, todo in
                    Text(todo)
                }
                .onDelete { todoNotifier.remove(at: $0.first!) }
                
                Button("Add Task") {
                    todoNotifier.add("New Task #\(todos.count + 1)")
                }
            }
            
            Section("AsyncNotifier: User Profile") {
                switch profileValue {
                case .data(let name):
                    LabeledContent("Username", value: name)
                case .loading:
                    HStack {
                        Text("Loading profile...")
                        Spacer()
                        ProgressView()
                    }
                case .refreshing(let name):
                    HStack {
                        Text(name).opacity(0.5)
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                    }
                case .error(let error):
                    Text("Error: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                }
                
                Button("Randomize Name") {
                    Task {
                        await profileNotifier.updateName("User \(Int.random(in: 100...999))")
                    }
                }
                
                Button("Refresh (Seamless)") {
                    profileNotifier.invalidate()
                }
            }
        }
        .navigationTitle("Riverpod: Notifiers")
    }
}
