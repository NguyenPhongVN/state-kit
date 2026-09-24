import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI
import StateKitMacros
import Riverpods
import StateKitPersistence

// ═══════════════════════════════════════════════════════════════════
//  LESSON L19 · CAPSTONE — Study Tracker
//
//  One small app that uses everything from L01–L18. Every piece below
//  cites the lesson that taught it. If you can read this file top to
//  bottom, you know StateKit's daily-use surface.
//
//  The app: log study minutes per subject, see your total and progress
//  toward a daily goal, and keep a streak that survives relaunches.
// ═══════════════════════════════════════════════════════════════════

// ─── The feature's state (L16: one feature, one home) ─────────────

/// Shared study state: an atom for the per-subject minutes (L04: atoms
/// live outside screens) plus a derived progress value (L06: computed,
/// never stored).
enum StudyTracker {
    @StateAtom
    struct MinutesToday {
        func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
    }

    @StateAtom
    struct Subject {
        func defaultValue(context: SKAtomTransactionContext) -> String { "Swift" }
    }

    // L06: the goal is data; progress toward it is an equation.
    @Computed
    struct Progress {
        @MainActor
        func compute(context: SKAtomTransactionContext) -> Double {
            Double(context.watch(MinutesToday())) / Double(context.watch(Goal()))
        }
    }

    @StateAtom
    struct Goal {
        func defaultValue(context: SKAtomTransactionContext) -> Int { 120 }
    }
}

// ─── Persistence (L13: load at start, save on change) ─────────────

private struct StudyStreak: UserDefaultsSerializable, Codable, Sendable {
    static let userDefaultsKey = "starthere.capstone.streak"
    static let defaultValue = StudyStreak(days: 1)
    var days: Int
}

private enum StreakLoader {
    // L13: the "load at start" half of persistence.
    static func load() -> StudyStreak { userDefaultsAtom(StudyStreak.self)() }
}
private enum StreakStore {
    static func save(_ value: StudyStreak) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: StudyStreak.userDefaultsKey)
        }
    }
}

// ─── A provider (L08/L09: reactive container state) ───────────────

/// Session history: each logged study block lands here, newest first.
private let studySessionsProvider = StateProvider { _ in [String]() }

// ─── The screen ───────────────────────────────────────────────────

struct Lesson19Capstone: View {
    // Global state: minutes, subject, goal (L04/L05: read/write anywhere).
    @SKState(StudyTracker.MinutesToday()) private var minutes
    @SKState(StudyTracker.Subject()) private var subject
    @SKState(StudyTracker.Goal()) private var goal
    // Derived: progress is an equation over minutes & goal (L06).
    @SKValue(StudyTracker.Progress()) private var progress
    // Provider: session history (L09: @Watch gives live reactive state).
    @Watch(studySessionsProvider) private var sessions
    // Local state: screen-private — the picker selection draft (L01–L02).
    @Environment(\.providerContainer) private var container
    @State private var lastAction = "Open me and log your first block."

    var body: some View {
        Form {
            Section("Today") {
                LabeledContent("Minutes", value: "\(minutes)")
                // L06: progress derives from minutes & goal — changing either
                // moves this bar with no extra code.
                ProgressView(value: min(progress, 1.0))
                LabeledContent("Progress to \(goal) min", value: "\(Int(progress * 100))%")
            }

            Section("Log a study block") {
                Picker("Subject", selection: $subject) {
                    Text("Swift").tag("Swift")
                    Text("Design").tag("Design")
                    Text("Math").tag("Math")
                }
                HStack {
                    ForEach([15, 25, 45], id: \.self) { block in
                        Button("+\(block) min") { log(block) }
                            .buttonStyle(.bordered)
                    }
                }
                LabeledContent("Last action", value: lastAction)
                    .font(.footnote)
            }

            Section("Sessions (provider history, L08/L09)") {
                // L12 spirit: render straight from state; no duplicate copy.
                ForEach(sessions, id: \.self) { Text("• \($0)").font(.footnote) }
                    .onDelete { offsets in
                        container.read(studySessionsProvider.notifier).state.remove(atOffsets: offsets)
                    }
            }

            Section("Streak (persisted, L13 — survives a relaunch)") {
                StreakRow()
            }

            StartHereNextButton(current: .capstone)
        }
        .navigationTitle("L19 · Study Tracker")
    }

    /// The only way minutes change: one action, one place (L17: one-way
    /// flow — the UI calls this; state changes; the UI follows).
    private func log(_ block: Int) {
        minutes += block
        container.read(studySessionsProvider.notifier).state.insert("\(subject): +\(block) min", at: 0)
        lastAction = "\(subject) +\(block) min — progress now \(Int(progress * 100))%"
    }
}

/// The streak is its own tiny view so its persistence logic (L13) stays
/// self-contained: load once, save on change.
private struct StreakRow: View {
    @Watch(streakProvider) private var streak
    @Environment(\.providerContainer) private var container

    var body: some View {
        HStack {
            LabeledContent("Day streak", value: "\(streak.days)")
            Button("I studied today!") {
                let next = StudyStreak(days: streak.days + 1)
                container.read(streakProvider.notifier).state = next
                StreakStore.save(next)
            }
            .buttonStyle(.bordered)
        }
    }
}

private let streakProvider = StateProvider { _ in StreakLoader.load() }
