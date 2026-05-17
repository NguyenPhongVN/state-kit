import SwiftUI
import Riverpods

private let todosProvider = StateProvider { _ in ["Write docs", "Ship demo"] }
private let selectedProvider = StateProvider<String?> { _ in nil }

struct SwiftDataIntegrationExampleView: View {
    @Watch(todosProvider) var todos
    @Watch(selectedProvider) var selected
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            Section("Persistence-like flow") {
                Button("Insert todo") { container.read(todosProvider.notifier).state.append("Todo #\(todos.count + 1)") }
                if let selected { Text("Selected: \(selected)") }
            }
            Section("Todos") {
                ForEach(todos, id: \.self) { todo in
                    Button(todo) { container.read(selectedProvider.notifier).state = todo }
                }
            }
        }
        .navigationTitle("SwiftData Style")
    }
}
