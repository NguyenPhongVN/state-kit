import SwiftUI
import Riverpods

// ═══════════════════════════════════════════════════════════════════
//  CHAPTER 6 · ARCHITECTURE
//
//  You know the pieces. This chapter is about ARRANGING them: where
//  state lives per feature, which direction data flows, and how you
//  prove it works with a test. No new library API in this chapter.
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// Lesson L16 · One feature, one home
//
// You will learn: group a feature's state in one namespace. When you
// look for "what does the Cart feature own?", the answer is ONE place.
//
// The block below IS the pattern — a real feature file, just tiny:
//
//     enum CartFeature {
//         // 1. the state: what the feature owns
//         static let items = StateProvider { _ in [String]() }
//         // 2. the actions: the only way state changes
//         extension-noted actions live with it (see L17)
//     }
//
// Screens import the feature, never reach into another feature's state.
// ─────────────────────────────────────────────────────────────────

/// The whole "Notes" feature: state + actions, one home. A real project
/// would put this in `Features/Notes/NotesState.swift` — the SIZE is
/// what makes the pattern work: if a feature's state doesn't fit on one
/// screen of code, it is probably two features.
enum NotesFeature {
    /// The feature's state: one provider, starting empty.
    static let notes = StateProvider { _ in ["Welcome note"] }

    /// The feature's actions — the ONLY way state changes (see L17).
    enum Actions {
        static func add(_ text: String, to container: ProviderContainer) {
            container.read(notes.notifier).state.append(text)
        }
        static func removeFirst(from container: ProviderContainer) {
            guard !container.read(notes.notifier).state.isEmpty else { return }
            container.read(notes.notifier).state.removeFirst()
        }
    }
}

struct Lesson16FeatureHome: View {
    @Watch(NotesFeature.notes) private var notes
    @Environment(\.providerContainer) private var container
    @State private var draft = ""

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("`NotesFeature` above owns everything about notes: the state AND the actions. Screens call actions; they never edit state from the side.")
            }
            Section("Try it — drive the feature through its actions") {
                HStack {
                    TextField("New note", text: $draft)
                    Button("Add") {
                        NotesFeature.Actions.add(draft, to: container)
                        draft = ""
                    }
                    .disabled(draft.isEmpty)
                }
                Button("Remove first") {
                    NotesFeature.Actions.removeFirst(from: container)
                }
            }
            Section("The feature's state") {
                ForEach(notes, id: \.self) { Text("• \($0)") }
            }
            Section("What just happened") {
                Text("The view never touched `.state` itself — it called an action. Tomorrow you can move this whole enum to another file (or another module) and no screen changes.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .featureHome)
        }
        .navigationTitle("L16 · Feature home")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L17 · Data flows in one direction
//
// You will learn: unidirectional flow.
//
//     UI  ──(calls action)──▶  state  ──(notifies)──▶  UI
//
// Data never flows backwards (UI never gets edited FROM the inside of
// a state change) and never sideways (features never write each
// other's state). This lesson shows the loop with a visible event log.
// ─────────────────────────────────────────────────────────────────

enum ScoreFeature {
    static let score = StateProvider { _ in 0 }

    enum Actions {
        static func add(points: Int, reason: String, to container: ProviderContainer, log: @escaping (String) -> Void) {
            let next = container.read(score.notifier).state + points
            container.read(score.notifier).state = next
            log("add(\(points)) → score = \(next)")
        }
    }
}

struct Lesson17OneWayFlow: View {
    @Watch(ScoreFeature.score) private var score
    @Environment(\.providerContainer) private var container
    // The log makes the invisible "action → state" step visible.
    @State private var log: [String] = []

    var body: some View {
        Form {
            Section("What you'll learn") {
                Text("Watch the loop: button (UI) → action → state → this screen. The log line is written in the ACTION — the state change is the only thing that updates the score.")
            }
            Section("Try it — the UI only CALLS actions") {
                Button("+1 (tap)") {
                    ScoreFeature.Actions.add(points: 1, reason: "tap", to: container) { log.append($0) }
                }
                Button("+5 (reward)") {
                    ScoreFeature.Actions.add(points: 5, reason: "reward", to: container) { log.append($0) }
                }
                .buttonStyle(.borderedProminent)
            }
            Section("Score (rendered from state)") {
                Text("\(score)").font(.largeTitle.bold())
            }
            Section("Action log (what the actions did)") {
                ForEach(log, id: \.self) { Text($0).font(.footnote.monospaced()) }
            }
            Section("What just happened") {
                Text("If a number on screen is wrong, you ask \"which action ran?\" — the log answers. That debuggability is WHY teams enforce one-way flow.")
                    .font(.footnote)
            }
            StartHereNextButton(current: .oneWayFlow)
        }
        .navigationTitle("L17 · One-way flow")
    }
}

// ─────────────────────────────────────────────────────────────────
// Lesson L18 · Prove it works
//
// You will learn: state with actions is EASY to test — no UI needed.
// This is a read-along: the test below is real Swift Testing code that
// could live in the package's test target, testing L17's feature.
// ─────────────────────────────────────────────────────────────────
struct Lesson18TestReadAlong: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What you'll learn")
                    .font(.headline)
                Text("Because L17's feature keeps state + actions in one namespace, the test creates a throwaway container and calls actions directly. No launching a UI, no taps, no screenshots — and it runs in milliseconds.")

                Text("The test, line by line")
                    .font(.headline)
                Text(
"""
import Testing
@testable import Riverpods   // the library the feature uses

@MainActor
@Test("adding points updates the score")
func addPoints() {
    let container = ProviderContainer()      // ① a FRESH container:
                                             //    tests never share state

    let before = container.read(ScoreFeature.score)
    ScoreFeature.Actions                    // ② call the same action
        .add(points: 5, reason: "test",
             to: container, log: { _ in })  //    the UI would call

    let after = container.read(ScoreFeature.score)
    #expect(after == before + 5)            // ③ assert on STATE, not
}                                           //    on anything visual
""")
                .font(.system(.footnote, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                Text("Why this matters")
                    .font(.headline)
                Text("① A fresh container per test = tests can't infect each other. ② Testing through the public actions means the test breaks when BEHAVIOR breaks, not when internals move. ③ The assertion reads like the requirement: “adding 5 gives +5”. That is the whole testing story for state.")
            }
            .padding()
        }
        .navigationTitle("L18 · Testing")
        .safeAreaInset(edge: .bottom) {
            StartHereNextButton(current: .testReadAlong)
        }
    }
}
