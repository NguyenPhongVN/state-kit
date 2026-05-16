import SwiftUI
import Riverpods
import StateKitDevTools

// MARK: - DevTools Example App

/// Complete example showing DevTools integration with a feature app.
///
/// Features:
/// - Counter with notifier
/// - Todo list management
/// - Real-time performance tracking
/// - Time-travel debugging
/// - Live DevTools overlay

// MARK: - State & Notifiers

struct AppState: Sendable {
    var counter: Int = 0
    var todos: [Todo] = []
    var filter: String = ""
}

struct Todo: Identifiable, Sendable {
    let id: Int
    let title: String
    let completed: Bool
}

@Notifier
class AppNotifier: Notifier<AppState> {
    override func build() -> AppState {
        AppState()
    }

    func incrementCounter() {
        state.counter += 1
    }

    func addTodo(_ title: String) {
        let newTodo = Todo(
            id: state.todos.count,
            title: title,
            completed: false
        )
        state.todos.append(newTodo)
    }

    func toggleTodo(_ id: Int) {
        if let index = state.todos.firstIndex(where: { $0.id == id }) {
            let todo = state.todos[index]
            state.todos[index] = Todo(
                id: todo.id,
                title: todo.title,
                completed: !todo.completed
            )
        }
    }

    func removeTodo(_ id: Int) {
        state.todos.removeAll { $0.id == id }
    }
}

let appProvider = NotifierProvider(name: "appProvider") { AppNotifier() }

let counterProvider = Provider(name: "counter") { ref in
    ref.watch(appProvider).counter
}

let todosProvider = Provider(name: "todos") { ref in
    ref.watch(appProvider).todos
}

// MARK: - Main App

struct DevToolsExampleApp: View {
    @State private var showDevTools = false
    private let devTools = DevToolsObserver()

    var body: some View {
        ZStack {
            // App content
            AppContentView()
                .environment(\.providerContainer, ProviderContainer(observers: [devTools]))

            // DevTools overlay
            if showDevTools {
                StateDevTools(observer: devTools)
                    .ignoresSafeArea()
            }

            // Toggle button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DevToolsHandle(
                        showDevTools: $showDevTools,
                        observer: devTools
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - App Content

struct AppContentView: View {
    @Watch(counterProvider) var counter
    @Watch(todosProvider) var todos
    @Environment(\.providerContainer) var container

    @State private var newTodoTitle = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Counter section
                VStack(spacing: 12) {
                    Text("Counter: \(counter)")
                        .font(.title2)
                        .fontWeight(.bold)

                    Button(action: {
                        let notifier = container.read(appProvider.notifier)
                        notifier.incrementCounter()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Increment")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // Todo section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Todos")
                        .font(.headline)

                    HStack(spacing: 8) {
                        TextField("New todo...", text: $newTodoTitle)
                            .textFieldStyle(.roundedBorder)

                        Button(action: {
                            guard !newTodoTitle.isEmpty else { return }
                            let notifier = container.read(appProvider.notifier)
                            notifier.addTodo(newTodoTitle)
                            newTodoTitle = ""
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }

                    List {
                        ForEach(todos) { todo in
                            HStack {
                                Button(action: {
                                    let notifier = container.read(appProvider.notifier)
                                    notifier.toggleTodo(todo.id)
                                }) {
                                    Image(systemName: todo.completed ? "checkmark.circle.fill" : "circle")
                                }

                                Text(todo.title)
                                    .strikethrough(todo.completed)

                                Spacer()

                                Button(action: {
                                    let notifier = container.read(appProvider.notifier)
                                    notifier.removeTodo(todo.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 200)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("DevTools Example")
        }
    }
}

// MARK: - Preview

#Preview {
    DevToolsExampleApp()
}

// MARK: - Standalone Example for Testing

/// Example showing different DevTools UI components
struct DevToolsComponentsExample: View {
    @State private var showDevTools = false
    private let devTools = DevToolsObserver()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("DevTools Components")
                    .font(.title)
                    .fontWeight(.bold)

                // Quick stats
                DevToolsQuickStats(observer: devTools)

                // Mini panel
                DevToolsMiniPanel(observer: devTools)

                Spacer()
            }
            .padding()
        }
    }
}

#Preview("Components") {
    DevToolsComponentsExample()
}
