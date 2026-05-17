import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct TodosAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> [String] {
        ["Write docs", "Ship demo"]
    }
}

@StateAtom
private struct SelectedTodoAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> String? { nil }
}

struct SwiftDataIntegrationExampleView: View {
    @SKState(TodosAtom.shared) private var todos
    @SKState(SelectedTodoAtom.shared) private var selected

    var body: some View {
        Form {
            Section("Persistence-like flow") {
                Button("Insert todo") {
                    todos.append("Todo #\(todos.count + 1)")
                }
                if let selected {
                    Text("Selected: \(selected)")
                }
            }
            Section("Todos") {
                ForEach(todos, id: \.self) { todo in
                    Button(todo) {
                        selected = todo
                    }
                }
            }
        }
        .navigationTitle("SwiftData Style")
    }
}

#Preview {
    NavigationStack {
        SwiftDataIntegrationExampleView()
    }
}
