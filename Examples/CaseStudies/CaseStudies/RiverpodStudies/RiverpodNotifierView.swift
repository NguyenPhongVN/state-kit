import SwiftUI
import Riverpods

struct RiverpodNotifierView: View {
    // Notifier example
    @Watch(RProvider.TodoNotifierProvider) var todos
    @Watch(RProvider.TodoNotifierProvider.notifier) var todoNotifier

    // AsyncNotifier example
    @Watch(RProvider.UserProfileNotifierProvider) var profileValue
    @Watch(RProvider.UserProfileNotifierProvider.notifier) var profileNotifier

    @Environment(\.providerContainer) var container
    
    var body: some View {
        Group {
            Text("Notifier: Todo List").font(.headline)
            ForEach(Array(todos.enumerated()), id: \.offset) { index, todo in
                Text(todo)
            }
            Button("Add Task") {
                todoNotifier.add("New Task #\(todos.count + 1)")
            }
            
            Text("AsyncNotifier: User Profile").font(.headline)
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
            case .error(let error, _):
                Text("Error: \(error.localizedDescription)")
                    .foregroundStyle(.red)
            }
            
            Button("Randomize Name") {
                Task {
                    let newName = "User \(Int.random(in: 100...999))"
                    await profileNotifier.updateName(newName)
                }
            }

            Button("Refresh (Seamless)") {
                container.refresh(RProvider.UserProfileNotifierProvider)
            }
        }
    }
}
