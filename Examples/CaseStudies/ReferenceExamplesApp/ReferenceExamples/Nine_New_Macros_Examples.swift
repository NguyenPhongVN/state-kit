import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

// MARK: - Core Atoms - Show atom type variety

@StateAtom
private struct TodosAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> [String] {
        ["Buy milk", "Read StateKit docs", "Master macros"]
    }
}

@StateAtom
private struct FilterAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> String { "" }
}

// MARK: - Computed Atoms with derivation

@Computed
private struct FilteredTodosAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> [String] {
        let todos = context.watch(TodosAtom.shared)
        let filter = context.watch(FilterAtom.shared)
        if filter.isEmpty { return todos }
        return todos.filter { $0.localizedCaseInsensitiveContains(filter) }
    }
}

@Computed
private struct TodoCountAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> Int {
        context.watch(FilteredTodosAtom.shared).count
    }
}

// MARK: - Macro 1: atomFamily - Parameterized state factory

@AtomFamily
private struct TodoCompletedAtom {
    let todo: String
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Bool { false }
}

// MARK: - Macro 2: selectorFamily - Parameterized computed values

@SelectorFamily
private struct TodoDisplayAtom {
    let todo: String
    @MainActor
    func value(context: SKAtomTransactionContext) -> String {
        let isCompleted = context.watch(TodoCompletedAtom.family(todo))
        return isCompleted ? "✓ \(todo)" : "○ \(todo)"
    }
}

// MARK: - Main View

struct NineNewMacrosExamplesView: View {
    @SKState(FilterAtom.shared) private var filter
    @SKState(TodosAtom.shared) private var todos
    @SKValue(FilteredTodosAtom.shared) private var filteredTodos
    @SKValue(TodoCountAtom.shared) private var count

    var body: some View {
        NavigationStack {
            Form {
                Section("Search (atomFamily demo)") {
                    TextField("Filter todos...", text: $filter)
                        .placeholder(when: filter.isEmpty) {
                            Text("Type to search").foregroundColor(.gray)
                        }
                }

                Section("Results (\(count))") {
                    if filteredTodos.isEmpty {
                        Text("No todos match").foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredTodos, id: \.self) { todo in
                            TodoItemView(todo: todo)
                        }
                    }
                }

                Section("Add new") {
                    HStack {
                        TextField("New todo", text: Binding(
                            get: { "" },
                            set: { newTodo in
                                if !newTodo.isEmpty {
                                    todos.append(newTodo)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Full Macros Demo")
        }
    }
}

// MARK: - Todo Item View using StateScope hooks

private struct TodoItemView: View {
    let todo: String

    var body: some View {
        SKAtomScopeView {
            // Using StateScope hooks pattern
            let display = useAtomValue(TodoDisplayAtom.family(todo))
            let isCompleted = useAtomBinding(TodoCompletedAtom.family(todo))

            HStack {
                Button(action: { isCompleted.wrappedValue.toggle() }) {
                    Text(display)
                        .foregroundStyle(isCompleted.wrappedValue ? .secondary : .primary)
                        .strikethrough(isCompleted.wrappedValue)
                }
                Spacer()
                Image(systemName: isCompleted.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted.wrappedValue ? .green : .gray)
            }
        }
    }
}

#Preview {
    NineNewMacrosExamplesView()
}

// MARK: - Helper Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
