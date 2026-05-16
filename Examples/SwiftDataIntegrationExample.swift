import Foundation
import SwiftUI
import SwiftData
import Riverpods
import StateKit
import StateKitTesting

// MARK: - SwiftData Integration Example

/// Complete example of StateKit + SwiftData integration.
///
/// Demonstrates:
/// - Syncing StateKit state with SwiftData models
/// - Reactive updates from database
/// - Bidirectional synchronization
/// - Query providers for SwiftData

// MARK: - Models

@Model
final class TodoItem: Identifiable {
    @Attribute(.unique) var id: String
    var title: String
    var description: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?

    init(id: String = UUID().uuidString, title: String, description: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.dueDate = nil
    }
}

struct TodoItemDTO: Sendable, Codable {
    let id: String
    let title: String
    let description: String
    let isCompleted: Bool
}

// MARK: - State

@SKStateAtom
var todoItemsAtom: [TodoItemDTO] = []

@SKStateAtom
var selectedTodoIdAtom: String?

// MARK: - Providers

/// Query all todos from SwiftData
let swiftDataTodosProvider = FutureProvider { ref -> [TodoItem] in
    // This would be called with actual ModelContext
    // For now, returning empty (demonstrate pattern)
    return []
}

/// Todos as reactive StateKit atoms
let todoListProvider = Provider { ref -> [TodoItemDTO] in
    ref.watch(todoItemsAtom)
}

/// Selected todo
let selectedTodoProvider = Provider { ref -> TodoItemDTO? in
    let selectedId = ref.watch(selectedTodoIdAtom)
    let items = ref.watch(todoItemsAtom)
    return items.first { $0.id == selectedId }
}

/// Computed: pending todos count
let pendingCountProvider = Provider { ref -> Int in
    let items = ref.watch(todoItemsAtom)
    return items.filter { !$0.isCompleted }.count
}

// MARK: - Notifiers

let todoNotifier = NotifierProvider { ref -> TodoNotifier in
    TodoNotifier(ref: ref)
}

final class TodoNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    /// Adds new todo item
    func addTodo(title: String, description: String = "") {
        let item = TodoItemDTO(
            id: UUID().uuidString,
            title: title,
            description: description,
            isCompleted: false
        )

        var items = ref.read(todoItemsAtom)
        items.append(item)
        ref.read(todoItemsAtom.notifier).state = items

        // In real app: sync to SwiftData
        syncToSwiftData(item)
    }

    /// Updates todo completion status
    func toggleTodo(_ id: String) {
        var items = ref.read(todoItemsAtom)
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isCompleted.toggle()
            ref.read(todoItemsAtom.notifier).state = items

            // Sync to SwiftData
            let updated = items[index]
            syncToSwiftData(updated)
        }
    }

    /// Deletes todo
    func deleteTodo(_ id: String) {
        var items = ref.read(todoItemsAtom)
        items.removeAll { $0.id == id }
        ref.read(todoItemsAtom.notifier).state = items

        // Sync to SwiftData
        deleteFromSwiftData(id)
    }

    /// Updates selected todo
    func selectTodo(_ id: String) {
        ref.read(selectedTodoIdAtom.notifier).state = id
    }

    // MARK: - SwiftData Sync

    private func syncToSwiftData(_ item: TodoItemDTO) {
        // In real app, would use ModelContext
        // context.insert(TodoItem(...))
        // try? context.save()
    }

    private func deleteFromSwiftData(_ id: String) {
        // In real app, would use ModelContext
        // let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        // let items = try? context.fetch(descriptor)
        // items?.forEach { context.delete($0) }
    }
}

// MARK: - Sync Helper

/// Manages bidirectional sync between StateKit and SwiftData
struct SwiftDataSyncManager: Sendable {
    let modelContext: ModelContext?

    /// Loads todos from SwiftData into StateKit atom
    func loadFromSwiftData() async -> [TodoItemDTO] {
        guard let context = modelContext else { return [] }

        do {
            let descriptor = FetchDescriptor<TodoItem>()
            let todos = try context.fetch(descriptor)

            return todos.map { TodoItemDTO(
                id: $0.id,
                title: $0.title,
                description: $0.description,
                isCompleted: $0.isCompleted
            )}
        } catch {
            return []
        }
    }

    /// Syncs StateKit atom changes to SwiftData
    func syncToSwiftData(_ item: TodoItemDTO) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.id == item.id }
        )

        do {
            let results = try context.fetch(descriptor)

            if let existing = results.first {
                // Update existing
                existing.title = item.title
                existing.description = item.description
                existing.isCompleted = item.isCompleted
            } else {
                // Insert new
                let new = TodoItem(
                    id: item.id,
                    title: item.title,
                    description: item.description,
                    isCompleted: item.isCompleted
                )
                context.insert(new)
            }

            try context.save()
        } catch {
            // Handle error
        }
    }
}

// MARK: - Views

struct SwiftDataIntegrationView: View {
    @Watch(var todos: todoListProvider)
    @Watch(var selectedTodo: selectedTodoProvider)
    @Watch(var pendingCount: pendingCountProvider)

    @State private var showAddTodo = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Todos")
                            .font(.headline)

                        Text("\(pendingCount) pending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { showAddTodo = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // List
                List {
                    ForEach(todos, id: \.id) { todo in
                        TodoItemRow(
                            todo: todo,
                            isSelected: selectedTodo?.id == todo.id,
                            onSelect: {
                                let container = ProviderContainer()
                                container.read(todoNotifier).selectTodo(todo.id)
                            },
                            onToggle: {
                                let container = ProviderContainer()
                                container.read(todoNotifier).toggleTodo(todo.id)
                            },
                            onDelete: {
                                let container = ProviderContainer()
                                container.read(todoNotifier).deleteTodo(todo.id)
                            }
                        )
                    }
                }
            }
            .navigationTitle("SwiftData Sync")
            .sheet(isPresented: $showAddTodo) {
                AddTodoView(isPresented: $showAddTodo)
            }
        }
    }
}

struct TodoItemRow: View {
    let todo: TodoItemDTO
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }

            VStack(alignment: .leading) {
                Text(todo.title)
                    .font(.headline)
                    .strikethrough(todo.isCompleted)

                if !todo.description.isEmpty {
                    Text(todo.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddTodoView: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Todo Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("New Todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let container = ProviderContainer()
                        let notifier = container.read(todoNotifier)
                        notifier.addTodo(title: title, description: description)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SwiftDataIntegrationView()
}
