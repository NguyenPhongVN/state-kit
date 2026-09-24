import SwiftUI

// ═══════════════════════════════════════════════════════════════════
//  START HERE · Lesson catalog
//
//  This file is the table of contents for the whole learning path.
//  It contains no library code — only the ordered list of lessons the
//  roadmap screen shows, and the navigation helpers they share.
// ═══════════════════════════════════════════════════════════════════

/// One destination in the learning path. Each case maps to exactly one
/// lesson screen (see `StartHereScreen` at the bottom of this file).
enum StartHereRoute: String, Hashable, CaseIterable {
    // Chapter 1 — local state
    case counter
    case binding
    case todoList
    // Chapter 2 — global state (atoms)
    case sharedAtom
    case editAnywhere
    case derivedAtom
    // Chapter 3 — providers
    case providerRead
    case providerWatch
    case watchWrapper
    // Chapter 4 — async & derived
    case taskAtom
    case throwingTaskAtom
    case selectorFilter
    // Chapter 5 — persistence & cache
    case persistedAtom
    case ttlCache
    case lruCache
    // Chapter 6 — architecture
    case featureHome
    case oneWayFlow
    case testReadAlong
    // Capstone
    case capstone
    // The roadmap itself
    case roadmap
}

/// A single lesson: what it is called, the one sentence describing what
/// you will learn, and where it lives.
struct StartHereLesson: Identifiable {
    let id: String          // "L01"
    let title: String
    let learn: String       // one plain sentence: what you will understand
    let route: StartHereRoute
}

/// A group of lessons that share one mental model.
struct StartHereChapter: Identifiable {
    let id: String          // "Chapter 1"
    let title: String
    let lessons: [StartHereLesson]
}

/// The whole path, in teaching order. The roadmap screen renders this —
/// if you add a lesson, add it here and everything else follows.
enum StartHereCatalog {

    static let chapters: [StartHereChapter] = [

        StartHereChapter(id: "1", title: "Chapter 1 · Local state with hooks", lessons: [
            StartHereLesson(
                id: "L01", title: "Your first counter",
                learn: "How state can change a screen: tap a button, the value updates, SwiftUI redraws.",
                route: .counter),
            StartHereLesson(
                id: "L02", title: "A field that listens",
                learn: "Two-way binding: a text field and your state stay perfectly in sync.",
                route: .binding),
            StartHereLesson(
                id: "L03", title: "A tiny todo list",
                learn: "State is just data — add, complete, and remove items by transforming a list.",
                route: .todoList),
        ]),

        StartHereChapter(id: "2", title: "Chapter 2 · Global state with atoms", lessons: [
            StartHereLesson(
                id: "L04", title: "One counter, two screens",
                learn: "Atoms live OUTSIDE your screens, so two screens can share one value.",
                route: .sharedAtom),
            StartHereLesson(
                id: "L05", title: "Edit it from anywhere",
                learn: "Any screen can write to an atom — the classic settings screen pattern.",
                route: .editAnywhere),
            StartHereLesson(
                id: "L06", title: "Values that compute themselves",
                learn: "Derived state: a value computed from other state that updates automatically.",
                route: .derivedAtom),
        ]),

        StartHereChapter(id: "3", title: "Chapter 3 · Riverpod-style providers", lessons: [
            StartHereLesson(
                id: "L07", title: "Read once",
                learn: "Reading is a snapshot: what you read stays put until you read again.",
                route: .providerRead),
            StartHereLesson(
                id: "L08", title: "Watch it live",
                learn: "Watching means registering interest — the honest difference between read and watch.",
                route: .providerWatch),
            StartHereLesson(
                id: "L09", title: "The SwiftUI wrapper",
                learn: "@Watch: reactive state in any view, with listeners cleaned up automatically.",
                route: .watchWrapper),
        ]),

        StartHereChapter(id: "4", title: "Chapter 4 · Async & derived state", lessons: [
            StartHereLesson(
                id: "L10", title: "Loading… then data",
                learn: "Task atoms: async work with a built-in idle → loading → success lifecycle.",
                route: .taskAtom),
            StartHereLesson(
                id: "L11", title: "When things fail",
                learn: "Throwing task atoms: surfacing errors as state, and retrying safely.",
                route: .throwingTaskAtom),
            StartHereLesson(
                id: "L12", title: "Filter without duplicating",
                learn: "Selectors: several views of one list, without ever copying the list.",
                route: .selectorFilter),
        ]),

        StartHereChapter(id: "5", title: "Chapter 5 · Persistence & cache", lessons: [
            StartHereLesson(
                id: "L13", title: "Survive a relaunch",
                learn: "Persisted atoms: your state is still there after the app is killed and reopened.",
                route: .persistedAtom),
            StartHereLesson(
                id: "L14", title: "Expire after a while",
                learn: "TTL caches: entries that quietly age out — watch one die in real time.",
                route: .ttlCache),
            StartHereLesson(
                id: "L15", title: "Forget the least used",
                learn: "LRU caches: fixed memory, and the least recently used entry is the one that goes.",
                route: .lruCache),
        ]),

        StartHereChapter(id: "6", title: "Chapter 6 · Architecture", lessons: [
            StartHereLesson(
                id: "L16", title: "One feature, one home",
                learn: "Organizing state: each feature owns its atoms and providers in one place.",
                route: .featureHome),
            StartHereLesson(
                id: "L17", title: "Data flows in one direction",
                learn: "Unidirectional flow: screen → action → state → UI. No back-channels, ever.",
                route: .oneWayFlow),
            StartHereLesson(
                id: "L18", title: "Prove it works",
                learn: "Testing state: reading a real test for L17's flow, and why it stays simple.",
                route: .testReadAlong),
        ]),

        StartHereChapter(id: "★", title: "Final capstone", lessons: [
            StartHereLesson(
                id: "L19", title: "Capstone: Study Tracker",
                learn: "One small app using local state, atoms, providers, derived values and persistence — everything from L01–L18.",
                route: .capstone),
        ]),
    ]

    /// The lesson that follows `route`, or nil when `route` is the capstone
    /// (the capstone loops back to the roadmap instead).
    static func lesson(after route: StartHereRoute) -> StartHereLesson? {
        let all = chapters.flatMap(\.lessons)
        guard let index = all.firstIndex(where: { $0.route == route }) else { return nil }
        let next = index + 1
        return next < all.count ? all[next] : nil
    }
}

// ═══════════════════════════════════════════════════════════════════
//  Shared navigation pieces
// ═══════════════════════════════════════════════════════════════════

/// Every lesson ends with this footer. It links to the next lesson so a
/// learner can walk the whole path without going back to the roadmap.
struct StartHereNextButton: View {
    let current: StartHereRoute

    var body: some View {
        let next = StartHereCatalog.lesson(after: current)
        Group {
            if let next {
                NavigationLink(value: next.route) {
                    Label("Next · \(next.id) \(next.title)", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                NavigationLink(value: StartHereRoute.roadmap) {
                    Label("Back to the roadmap — you made it! 🎉", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}

/// Resolves a route to its lesson screen. The app installs ONE
/// `navigationDestination(for: StartHereRoute.self)` that calls this, so
/// every lesson can link to every other lesson.
struct StartHereScreen: View {
    let route: StartHereRoute

    var body: some View {
        switch route {
        case .counter: Lesson01Counter()
        case .binding: Lesson02Binding()
        case .todoList: Lesson03TodoList()
        case .sharedAtom: Lesson04SharedAtom()
        case .editAnywhere: Lesson05EditAnywhere()
        case .derivedAtom: Lesson06DerivedAtom()
        case .providerRead: Lesson07ProviderRead()
        case .providerWatch: Lesson08ProviderWatch()
        case .watchWrapper: Lesson09WatchWrapper()
        case .taskAtom: Lesson10TaskAtom()
        case .throwingTaskAtom: Lesson11ThrowingTaskAtom()
        case .selectorFilter: Lesson12SelectorFilter()
        case .persistedAtom: Lesson13PersistedAtom()
        case .ttlCache: Lesson14TTLCache()
        case .lruCache: Lesson15LRUCache()
        case .featureHome: Lesson16FeatureHome()
        case .oneWayFlow: Lesson17OneWayFlow()
        case .testReadAlong: Lesson18TestReadAlong()
        case .capstone: Lesson19Capstone()
        case .roadmap: StartHereRoadmapView()
        }
    }
}

/// The roadmap itself: the ordered path a learner sees first.
struct StartHereRoadmapView: View {
    var body: some View {
        List {
            Section {
                Text("Work top to bottom. Every lesson is one small idea, one tiny screen, and explains **why** — not just what to type.")
                    .font(.subheadline)
            }

            ForEach(StartHereCatalog.chapters) { chapter in
                Section(chapter.title) {
                    ForEach(chapter.lessons) { lesson in
                        NavigationLink(value: lesson.route) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(lesson.id) · \(lesson.title)")
                                    .font(.headline)
                                Text(lesson.learn)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Start Here")
    }
}
