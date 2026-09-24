import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI
import StateKitMacros

// ═══════════════════════════════════════════════════════════════════
//  CHAPTER 2 · GLOBAL STATE WITH ATOMS
//
//  Local state (Chapter 1) dies with its screen. Atoms live OUTSIDE
//  any screen, in a store — so any screen can read or write them and
//  every reader stays in sync. Three lessons: share, edit anywhere,
//  and values that compute themselves.
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// Lesson L04 · One counter, two screens
//
// You will learn: an atom is a named piece of state that lives in a
// store, not in a view. Two views can hold `@SKState` for the SAME
// atom and they see the same value — change one, both update.
// ─────────────────────────────────────────────────────────────────

// 1. An atom TYPE describes a piece of global state: its name is the
//    type, its `defaultValue` is the starting value. Nothing here is
//    tied to any screen.
@StateAtom
struct StartHereSharedCounterAtom {
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

/// Screen A — reads and writes the shared counter.
struct Lesson04ScreenA: View {
    // 2. `@SKState` connects this view to the atom in the store. Both
    //    ScreenA and ScreenB below connect to the SAME atom type, so
    //    they show the SAME number.
    @SKState(StartHereSharedCounterAtom()) private var count

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen A").font(.caption).foregroundStyle(.secondary)
            Text("\(count)").font(.largeTitle.bold())
            Button("+1 from A") {
                // 3. Writing is just assigning to the wrapper. The store
                //    notices, and EVERY connected view re-renders.
                count += 1
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Screen B — a different view, same atom, same value.
struct Lesson04ScreenB: View {
    @SKState(StartHereSharedCounterAtom()) private var count

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen B").font(.caption).foregroundStyle(.secondary)
            Text("I see \(count) too").font(.title3)
            Button("+10 from B") {
                count += 10
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct Lesson04SharedAtom: View {
    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("These two panels pretend to be two screens. They never talk to each other — they both talk to the ATOM.")
            }
            Section("Try it") {
                Lesson04ScreenA()
                Lesson04ScreenB()
            }
            Section("What just happened") {
                Text("+1 from A and B both changed the SAME stored value. That is the whole point of global state: one owner, many readers.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .sharedAtom)
        }
        .navigationTitle("L04 · Shared atom")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L05 · Edit it from anywhere
//
// You will learn: the settings pattern. Because atoms live in the
// store, a settings screen can write a value the main screen reads —
// navigation direction doesn't matter to the data.
// ─────────────────────────────────────────────────────────────────

@StateAtom
struct StartHereCityAtom {
    func defaultValue(context: SKAtomTransactionContext) -> String { "Hanoi" }
}

/// The "main screen" of a weather app: it only READS the city.
struct Lesson05MainScreen: View {
    @SKState(StartHereCityAtom()) private var city

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Main screen").font(.caption).foregroundStyle(.secondary)
            Text("Weather for \(city) 🌤️")
                .font(.title3.bold())
            Text("(This screen has no way to change the city — and doesn't need one.)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// The "settings screen": it only WRITES the city.
struct Lesson05SettingsScreen: View {
    @SKState(StartHereCityAtom()) private var city

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings screen").font(.caption).foregroundStyle(.secondary)
            Picker("City", selection: $city) {
                // `$city` gives the picker a Binding into the atom — same
                // two-way connection as useBinding in L02, but global.
                Text("Hanoi").tag("Hanoi")
                Text("Da Nang").tag("Da Nang")
                Text("Ho Chi Minh City").tag("Ho Chi Minh City")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct Lesson05EditAnywhere: View {
    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("The main screen reads the city. The settings screen writes it. Neither knows the other exists — the atom is the single source of truth.")
            }
            Section("Try it") {
                Lesson05MainScreen()
                Lesson05SettingsScreen()
            }
            Section("What just happened") {
                Text("Change the city below and watch the card above update instantly. Direction of navigation never mattered — data lives in the store, not in the navigation stack.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .editAnywhere)
        }
        .navigationTitle("L05 · Settings")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L06 · Values that compute themselves
//
// You will learn: derived state. A computed atom is a VALUE EXPRESSION
// over other atoms. You never store "doubled" — you describe how to
// compute it, and it stays correct forever.
// ─────────────────────────────────────────────────────────────────

@StateAtom
struct StartHereBaseCountAtom {
    func defaultValue(context: SKAtomTransactionContext) -> Int { 3 }
}

@StateAtom
struct StartHereNameAtom {
    func defaultValue(context: SKAtomTransactionContext) -> String { "StateKit" }
}

// 1. A computed atom never stores anything. Its `compute` reads OTHER
//    atoms (each `context.watch` is a dependency) and returns the result.
@Computed
struct StartHereDoubledAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> Int {
        // "I depend on the base count." Change the base → this recomputes.
        context.watch(StartHereBaseCountAtom()) * 2
    }
}

@Computed
struct StartHereSummaryAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> String {
        // Multiple watches = multiple dependencies. Any of them changing
        // recomputes this summary.
        "\(context.watch(StartHereNameAtom())) has base \(context.watch(StartHereBaseCountAtom()))"
    }
}

struct Lesson06DerivedAtom: View {
    // 2. Writable atoms use @SKState; computed (read-only) atoms use @SKValue.
    @SKState(StartHereBaseCountAtom()) private var base
    @SKState(StartHereNameAtom()) private var name
    @SKValue(StartHereDoubledAtom()) private var doubled
    @SKValue(StartHereSummaryAtom()) private var summary

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("Never store a value you can compute. `doubled` and `summary` are not saved anywhere — they are equations over the inputs below.")
            }
            Section("Inputs — change these") {
                Stepper("Base count: \(base)", value: $base, in: 0...20)
                TextField("Name", text: $name)
            }
            Section("Derived — these update themselves") {
                LabeledContent("Doubled", value: "\(doubled)")
                LabeledContent("Summary", value: summary)
            }
            Section("What just happened") {
                Text("There is no code anywhere that says \"update doubled when base changes\". The dependency graph handles it: doubled watched base, base changed, doubled recomputed.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .derivedAtom)
        }
        .navigationTitle("L06 · Derived")
    }
}
