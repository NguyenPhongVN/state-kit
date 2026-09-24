import SwiftUI
import StateKit
import StateKitUI

// ═══════════════════════════════════════════════════════════════════
//  CHAPTER 1 · LOCAL STATE WITH HOOKS
//
//  Local state = data that belongs to ONE screen and dies with it.
//  Three lessons: a counter, a bound text field, a todo list.
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// Lesson L01 · Your first counter
//
// You will learn: how state can change a screen.
//
// SwiftUI re-runs your `body` whenever state it depends on changes.
// StateKit's `useState` gives you a value + a setter. Call the setter
// → the value changes → SwiftUI re-runs the body → you see the new
// number. That loop is the WHOLE idea of UI state.
// ─────────────────────────────────────────────────────────────────
struct Lesson01Counter: View {
    var body: some View {
        StateScope {
            // 1. `useState(0)` creates one piece of state for THIS screen,
    //    starting at 0. It returns two things:
    //    - `count`   : the current value (what you display)
    //    - `setCount`: a function to change it (the only way to change it)
            let (count, setCount) = useState(0)

            Form {
                Section("What you'll learn") {
                    Text("Tap the button. The number changes because state changed — and the screen follows the state.")
                }

                Section("Try it") {
                    Text("\(count)")
                        .font(.system(size: 56, weight: .bold))
                        .frame(maxWidth: .infinity)

                    Button("Tap me") {
                        // 2. Changing state is a FUNCTION CALL, not `count += 1`.
                        //    The setter tells StateKit (and SwiftUI) "something
                        //    changed" — that is what triggers the re-render.
                        setCount(count + 1)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("What just happened") {
                    Text("You tapped → setCount(\(count + 1)) ran → count became \(count) → this body re-ran → you saw \(count). Every tap repeats that loop.")
                        .font(.footnote)
                }

                StartHereNextButton(current: .counter)
            }
        }
        .navigationTitle("L01 · Counter")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L02 · A field that listens
//
// You will learn: two-way binding.
//
// Controls like TextField need to WRITE into your state as you type.
// `useBinding` hands them a live connection (a `Binding`) instead of a
// copy: edit the field → state changes → anything reading the state
// updates. No "onChanged" glue code.
// ─────────────────────────────────────────────────────────────────
struct Lesson02Binding: View {
    var body: some View {
        StateScope {
            // 1. `useBinding("")` is useState tuned for controls: instead of
            //    (value, setter) it returns a `Binding<String>` — a live
            //    read/write connection into this screen's state.
            let name = useBinding("")

            Form {
                Section("What you'll learn") {
                    Text("Two-way binding: the field writes to state as you type, and everything reading that state updates instantly.")
                }

                Section("Try it") {
                    // 2. Passing `name` (a Binding) with `$`-free syntax means
                    //    the TextField can READ and WRITE through it. There is
                    //    no delegate, no onChanged handler — the binding IS
                    //    the connection.
                    TextField("Type your name", text: name)
                }

                Section("What just happened") {
                    // 3. This Text reads the SAME state the field writes to.
                    //    One state, two readers/writers, always in sync.
                    let current = name.wrappedValue
                    Text("Hello, \(current.isEmpty ? "stranger" : current)! 👋")
                }

                StartHereNextButton(current: .binding)
            }
        }
        .navigationTitle("L02 · Binding")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L03 · A tiny todo list
//
// You will learn: state is just data.
//
// State doesn't have to be a number or a string. Here it is an ARRAY.
// Adding, completing and removing a todo are all the same move:
// build a new array, call the setter once. The screen always shows
// exactly what the data says.
// ─────────────────────────────────────────────────────────────────
private struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var done: Bool
}

/// One todo row. Extracted into its own view so the toggle/remove data
/// transforms stay small and type-check instantly — a real-world pattern
/// for keeping `body` fast to compile and easy to read.
private struct Lesson03TodoRow: View {
    let todo: TodoItem
    let todos: [TodoItem]
    let setTodos: ([TodoItem]) -> Void

    var body: some View {
        HStack {
            let icon = todo.done ? "checkmark.circle.fill" : "circle"
            Image(systemName: icon)
                .onTapGesture {
                    // TOGGLE = same array, one item flipped.
                    let updated = todos.map { item -> TodoItem in
                        var copy = item
                        if copy.id == todo.id { copy.done.toggle() }
                        return copy
                    }
                    setTodos(updated)
                }
            Text(todo.title)
                .strikethrough(todo.done)
            Spacer()
            Image(systemName: "trash")
                .foregroundStyle(.red)
                .onTapGesture {
                    // REMOVE = keep everything except this one.
                    let remaining = todos.filter { $0.id != todo.id }
                    setTodos(remaining)
                }
        }
    }
}

struct Lesson03TodoList: View {
    // 2. Local text for the input field — plain SwiftUI state is fine
    //    here; only things OTHER views must see need StateKit.
    @State private var draft = ""

    var body: some View {
        StateScope {
            // 1. One array holds the whole list. Everything else on this
            //    screen is COMPUTED from it on the fly (counts below).
            let (todos, setTodos) = useState([TodoItem]())

            Form {
                Section("What you'll learn") {
                    Text("Never mutate a list in place — replace it. Every button below builds a new array and calls the setter once.")
                }

                Section("Try it") {
                    HStack {
                        TextField("New todo", text: $draft)
                        Button("Add") {
                            // 3. ADD = old items + one new item.
                            setTodos(todos + [TodoItem(title: draft, done: false)])
                            draft = ""
                        }
                        .disabled(draft.isEmpty)
                    }

                    // 4. Toggling/removing uses `map`/`filter`: classic data
                    //    transforms, not UI code. The UI follows the data.
                    ForEach(todos) { todo in
                        Lesson03TodoRow(todo: todo, todos: todos, setTodos: setTodos)
                    }
                }

                Section("What just happened") {
                    let done = todos.filter(\.done).count
                    Text("\(todos.count) items, \(done) done. Both numbers are computed from the array each render — there is no second 'count' state to keep in sync.")
                        .font(.footnote)
                }

                StartHereNextButton(current: .todoList)
            }
        }
        .navigationTitle("L03 · Todos")
    }
}
