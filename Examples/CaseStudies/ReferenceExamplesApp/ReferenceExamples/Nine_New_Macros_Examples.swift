import SwiftUI
import StateKitAtoms
import StateKitUI

// MARK: - 1. Base Atom Macros: @StateAtom, @ValueAtom

private struct TodoFilterAtom: SKStateAtom, Hashable {
    typealias Value = String
    func defaultValue(context: SKAtomTransactionContext) -> String { "" }
}

private struct TodosAtom: SKStateAtom, Hashable {
    typealias Value = [String]
    func defaultValue(context: SKAtomTransactionContext) -> [String] {
        ["Buy milk", "Read documentation", "Review macros"]
    }
}

// MARK: - 2. @ValueAtom: Derived/Computed State

private struct FilteredTodosAtom: SKValueAtom, Hashable {
    typealias Value = [String]
    func value(context: SKAtomTransactionContext) -> [String] {
        let todos = context.watch(TodosAtom())
        let filter = context.watch(TodoFilterAtom())

        if filter.isEmpty {
            return todos
        }
        return todos.filter { $0.localizedCaseInsensitiveContains(filter) }
    }
}

private struct TodoCountAtom: SKValueAtom, Hashable {
    typealias Value = Int
    func value(context: SKAtomTransactionContext) -> Int {
        context.watch(FilteredTodosAtom()).count
    }
}

// MARK: - 3. @AtomFamily: Parameterized State

private let todoCompletedAtom = atomFamily { (todo: String) in
    false
}

// MARK: - 4. @SelectorFamily: Parameterized Computed Values

private let todoDisplayAtom = selectorFamily { (todo: String, context: SKAtomTransactionContext) in
    let isCompleted = context.watch(todoCompletedAtom(todo))
    let prefix = isCompleted ? "✓" : "○"
    return "\(prefix) \(todo)"
}

struct NineNewMacrosExamplesView: View {
    @SKState(TodoFilterAtom()) private var filter
    @SKState(TodosAtom()) private var todos
    @SKValue(FilteredTodosAtom()) private var filteredTodos
    @SKValue(TodoCountAtom()) private var count

    var body: some View {
        Form {
            Section("Search & Filter") {
                TextField("Filter todos", text: $filter)
                    .placeholder(when: filter.isEmpty) {
                        Text("Search...").foregroundColor(.gray)
                    }
            }

            Section("Results (\(count))") {
                if filteredTodos.isEmpty {
                    Text("No todos match the filter")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredTodos, id: \.self) { todo in
                        TodoRow(todo: todo)
                    }
                }
            }

            Section("Add New") {
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
        .navigationTitle("Macro Examples")
    }
}

// MARK: - Todo Item Row with Completion Toggle

private struct TodoRow: View {
    let todo: String

    var body: some View {
        SKAtomScopeView {
            let display = useAtomValue(todoDisplayAtom(todo))
            let isCompleted = useAtomBinding(todoCompletedAtom(todo))

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
    NavigationStack {
        NineNewMacrosExamplesView()
    }
}

// MARK: - Helper Extensions

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
