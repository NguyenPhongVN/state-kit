import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI
import StateKitMacros

// ═══════════════════════════════════════════════════════════════════
//  CHAPTER 4 · ASYNC & DERIVED STATE
//
//  Real apps load data over time. This chapter shows state that has a
//  LIFECYCLE (idle → loading → success/failure) and lists that are
//  filtered without being copied.
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// Lesson L10 · Loading… then data
//
// You will learn: a task atom is async state with a built-in
// lifecycle. You never write `isLoading` booleans yourself — the atom
// IS the phase machine.
// ─────────────────────────────────────────────────────────────────

// 1. The fake network: how slow the "request" is, controlled by the
//    Stepper in the lesson screen.
@StateAtom
struct StartHereDelayAtom {
    func defaultValue(context: SKAtomTransactionContext) -> UInt64 { 500 }
}

// 2. A task atom = async work + phase machine. The `task` runs when the
//    atom is first used; whatever it returns becomes `.success`.
@TaskAtom
struct StartHereProfileAtom {
    func task(context: SKAtomTransactionContext) async -> String {
        let delay = context.watch(StartHereDelayAtom())
        try? await Task.sleep(nanoseconds: delay * 1_000_000)
        return "Profile loaded after \(delay) ms"
    }
}

struct Lesson10TaskAtom: View {
    // 3. `@SKTask` connects to the task atom's PHASE, not a plain value:
    //    it starts as .loading while the work runs, then .success(result).
    @SKTask(StartHereProfileAtom()) private var profile
    @SKState(StartHereDelayAtom()) private var delay
    @SKContext private var atomContext

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("Async state has phases. You render the phase — there is no separate `isLoading` flag to forget.")
            }
            Section("Controls") {
                Stepper("Fake delay: \(Int(delay)) ms", value: $delay, in: 100...2_000, step: 100)
                Button("Reload") {
                    // 4. Restart the task. The phase flips back to .loading
                    //    first — even the reload is just state.
                    Task { await atomContext.refresh(StartHereProfileAtom()) }
                }
            }
            Section("Phase — render it like data") {
                switch profile {
                case .idle: Text("Idle (not started yet)")
                case .loading: ProgressView("Loading…")
                case .success(let value): Text("✅ \(value)")
                case .failure(let error): Text("❌ \(error.localizedDescription)")
                }
            }
            Section("What just happened") {
                Text("The label above changed shape by itself: spinner → text. Because the phase IS the state, UI code stays a `switch`.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .taskAtom)
        }
        .navigationTitle("L10 · Task atom")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L11 · When things fail
//
// You will learn: errors are a phase too. A throwing task atom can end
// in `.failure(error)` — and "try again" is just running the task
// again. No error booleans, no alert gymnastics in this lesson.
// ─────────────────────────────────────────────────────────────────

private struct StartHereNetworkError: LocalizedError {
    var errorDescription: String? { "The imaginary server said no." }
}

@ThrowingTaskAtom
struct StartHereScoresAtom {
    func task(context: SKAtomTransactionContext) async throws -> Int {
        let delay = context.watch(StartHereDelayAtom())
        try await Task.sleep(nanoseconds: delay * 1_000_000)
        // 1. The "server" fails whenever the toggle below is on. Real apps
        //    throw here instead of returning sentinel values like -1.
        if context.watch(StartHereForceFailAtom()) {
            throw StartHereNetworkError()
        }
        return Int.random(in: 60...100)
    }
}

@StateAtom
struct StartHereForceFailAtom {
    func defaultValue(context: SKAtomTransactionContext) -> Bool { false }
}

struct Lesson11ThrowingTaskAtom: View {
    @SKTask(StartHereScoresAtom()) private var scores
    @SKState(StartHereForceFailAtom()) private var forceFail
    @SKContext private var atomContext

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("Failure is a state, not an exception in your UI. Render `.failure` like any other phase — and retrying is just reloading.")
            }
            Section("Controls") {
                Toggle("Make the request fail", isOn: $forceFail)
                Button("Fetch score") {
                    Task { await atomContext.refresh(StartHereScoresAtom()) }
                }
                .buttonStyle(.borderedProminent)
            }
            Section("Phase") {
                switch scores {
                case .idle: Text("Idle — press Fetch")
                case .loading: ProgressView("Contacting the imaginary server…")
                case .success(let score): Text("🏆 Score: \(score)")
                case .failure(let error): Text("💥 \(error.localizedDescription)")
                }
            }
            Section("What just happened") {
                Text("Toggle \"fail\" on, fetch: you get the failure phase with a human message. Toggle off, fetch: success. Same screen, same switch — errors never leaked into your view logic.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .throwingTaskAtom)
        }
        .navigationTitle("L11 · Failure")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L12 · Filter without duplicating
//
// You will learn: selectors/computed views of a collection. Keep ONE
// list, derive "completed" and "active" from it. Copying data into a
// second "filtered" array is how lists drift out of sync — deriving
// makes drift impossible.
// ─────────────────────────────────────────────────────────────────

struct StartHereTask: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var done: Bool
}

@StateAtom
struct StartHereTaskListAtom {
    func defaultValue(context: SKAtomTransactionContext) -> [StartHereTask] {
        [StartHereTask(title: "Read chapter 4", done: true),
         StartHereTask(title: "Try the examples", done: false),
         StartHereTask(title: "Build something small", done: false)]
    }
}

// 2. Two derived views of the SAME list. Neither stores anything.
@Computed
struct StartHereDoneTasksAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> [StartHereTask] {
        context.watch(StartHereTaskListAtom()).filter(\.done)
    }
}

@Computed
struct StartHereActiveTasksAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> [StartHereTask] {
        context.watch(StartHereTaskListAtom()).filter { !$0.done }
    }
}

struct Lesson12SelectorFilter: View {
    @SKState(StartHereTaskListAtom()) private var tasks
    @SKValue(StartHereDoneTasksAtom()) private var done
    @SKValue(StartHereActiveTasksAtom()) private var active

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("One list in, two live views out. Tap a row's circle — notice BOTH sections stay correct with zero extra code.")
            }
            Section("The one true list — tap to toggle") {
                ForEach(tasks) { task in
                    HStack {
                        Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        Text(task.title)
                    }
                    .onTapGesture {
                        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                            tasks[index].done.toggle()
                        }
                    }
                }
            }
            Section("Derived: active") {
                ForEach(active) { Text("• \($0.title)") }
            }
            Section("Derived: done") {
                ForEach(done) { Text("• \($0.title)").strikethrough() }
            }
            Section("What just happened") {
                Text("`done` and `active` are computed from the list atom. You never maintained a second array — that's why they can't disagree.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .selectorFilter)
        }
        .navigationTitle("L12 · Selectors")
    }
}
