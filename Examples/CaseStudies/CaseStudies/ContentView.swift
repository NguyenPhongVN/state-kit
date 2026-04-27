import SwiftUI
import Textual

struct ContentView: View {
    @State private var query = ""
    @State private var showingInfo = false

    private let mdString: String = {
        let url = Bundle.main.url(forResource: "StateKit", withExtension: "md")!
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    private var studies: [CaseStudy] {
        [
            CaseStudy(
                id: "atomState",
                title: "State atoms",
                summary: "Read, write, and derive data using @SKState and @SKValue on the same store.",
                category: .atoms,
                keywords: ["atom", "selector", "shared store", "derived state"]
            ) { AtomStateExample() },
            CaseStudy(
                id: "atomTask",
                title: "Async atoms",
                summary: "Track AsyncPhase of task atoms and throwing task atoms, then refresh manually.",
                category: .atoms,
                keywords: ["async atom", "task", "refresh", "phase"]
            ) { AtomTaskExample() },
            CaseStudy(
                id: "atomInline",
                title: "Inline atoms",
                summary: "Create atoms and selectors via factory for concise examples without named types.",
                category: .atoms,
                keywords: ["inline atom", "selector", "factory", "reference identity"]
            ) { InlineAtomExample() },
            CaseStudy(
                id: "atomFamily",
                title: "Atom family",
                summary: "Parameterize atoms by ID so each member has its own state but shared factory logic.",
                category: .atoms,
                keywords: ["family", "parameterized", "per id", "shared logic"]
            ) { AtomFamilyExample() },
            CaseStudy(
                id: "atomContext",
                title: "Atom context",
                summary: "Read, set, reset, binding, and evict atoms imperatively in action handlers.",
                category: .atoms,
                keywords: ["context", "imperative", "binding", "evict"]
            ) { AtomContextExample() },
            CaseStudy(
                id: "atomHooks",
                title: "Atom hooks bridge",
                summary: "Mix local hook state with global atoms using useAtomState, useAtomBinding, and useAtomRefresher.",
                category: .atoms,
                keywords: ["useAtomState", "useAtomBinding", "StateScope", "bridge"]
            ) { AtomHookExample() },
            CaseStudy(
                id: "atomScope",
                title: "Scoped atom store",
                summary: "Isolate a subtree to a new store using SKAtomScopeView so state doesn't bleed.",
                category: .atoms,
                keywords: ["scope", "isolated store", "preview", "subtree"]
            ) { ScopedStoreExample() },

            // MARK: - Riverpod Section

            CaseStudy(
                id: "rpCounter",
                title: "Riverpod: Counter",
                summary: "Standard StateProvider and derived Provider with auto-dispose and dependency tracking.",
                category: .riverpod,
                keywords: ["riverpod", "state provider", "dependency tracking", "auto-dispose"]
            ) { RiverpodCounterView() },
            CaseStudy(
                id: "rpNotifier",
                title: "Riverpod: Notifier",
                summary: "Complex logic encapsulated in a Notifier class, accessed via NotifierProvider.",
                category: .riverpod,
                keywords: ["notifier", "controller", "business logic"]
            ) { RiverpodNotifierView() },
            CaseStudy(
                id: "rpFuture",
                title: "Riverpod: Future",
                summary: "Handle one-shot async tasks with FutureProvider and AsyncPhase.",
                category: .riverpod,
                keywords: ["future", "async", "task", "loading"]
            ) { RiverpodFutureView() },
            CaseStudy(
                id: "rpAdvanced",
                title: "Riverpod: Advanced",
                summary: "Family, StreamProvider, and Selector (select) with performance optimization.",
                category: .riverpod,
                keywords: ["family", "stream", "selector", "performance"]
            ) { RiverpodAdvancedView() },

            CaseStudy(
                id: "useState",
                title: "useState",
                summary: "Local state with direct setter for basic interactions.",
                category: .state,
                keywords: ["local state", "counter", "setter"]
            ) { UseState() },
            CaseStudy(
                id: "useBinding",
                title: "useBinding",
                summary: "Connect state to TextField, Toggle, and Slider with familiar Binding.",
                category: .state,
                keywords: ["binding", "forms", "input"]
            ) { UseBinding() },
            CaseStudy(
                id: "useReducer",
                title: "useReducer",
                summary: "Group updates into actions and a reducer for clearer logic.",
                category: .state,
                keywords: ["reducer", "actions", "state machine"]
            ) { UseReducer() },
            CaseStudy(
                id: "useRef",
                title: "useRef",
                summary: "Store mutable values across renders without forcing UI refresh.",
                category: .state,
                keywords: ["mutable ref", "imperative", "stable value"]
            ) { UseRef() },
            CaseStudy(
                id: "useMemo",
                title: "useMemo",
                summary: "Cache computation results and only recompute when dependencies change.",
                category: .state,
                keywords: ["memo", "cache", "dependencies"]
            ) { UseMemo() },
            CaseStudy(
                id: "useCallback",
                title: "useCallback",
                summary: "Keep callback identity stable until dependencies change.",
                category: .state,
                keywords: ["callback", "identity", "performance"]
            ) { UseCallback() },
            CaseStudy(
                id: "useContext",
                title: "useContext",
                summary: "Read shared data from HookContext without prop drilling.",
                category: .state,
                keywords: ["context", "shared data", "composition"]
            ) { UseContext() },
            CaseStudy(
                id: "useEnvironment",
                title: "useEnvironment",
                summary: "Access EnvironmentValues directly inside StateScope.",
                category: .state,
                keywords: ["environment", "locale", "color scheme"]
            ) { UseEnvironment() },
            CaseStudy(
                id: "useOnChange",
                title: "useOnChange",
                summary: "Observe transitions between old and new values to trigger side effects.",
                category: .state,
                keywords: ["observer", "transitions", "callbacks"]
            ) { UseOnChange() },
            CaseStudy(
                id: "useEffect",
                title: "useEffect",
                summary: "Run passive effects after render with explicit cleanup.",
                category: .effect,
                keywords: ["effect", "cleanup", "side effects"]
            ) { UseEffect() },
            CaseStudy(
                id: "useLayoutEffect",
                title: "useLayoutEffect",
                summary: "Demonstrates flush order between layout effects and passive effects.",
                category: .effect,
                keywords: ["layout", "flush order", "timing"]
            ) { UseLayoutEffect() },
            CaseStudy(
                id: "useAsync",
                title: "useAsync",
                summary: "Wrap an async task and return loading, success, failure phases.",
                category: .async,
                keywords: ["async task", "phase", "retry"]
            ) { UseAsync() },
            CaseStudy(
                id: "useAsyncSequence",
                title: "useAsyncSequence",
                summary: "Track an AsyncSequence stream and show the latest emission.",
                category: .async,
                keywords: ["stream", "async sequence", "events"]
            ) { UseAsyncSequence() },
            CaseStudy(
                id: "usePublisher",
                title: "usePublisher",
                summary: "Subscribe to Combine publisher and bind phases to UI.",
                category: .async,
                keywords: ["combine", "publisher", "subscription"]
            ) { UsePublisher() }
        ]
    }

    private var filteredStudies: [CaseStudy] {
        if query.isEmpty { return studies }
        return studies.filter { study in
            let haystack = ([study.title, study.summary] + study.keywords)
                .joined(separator: " ")
                .localizedLowercase
            return haystack.contains(query.localizedLowercase)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(DemoCategory.allCases) { category in
                    let items = filteredStudies.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.title) {
                            ForEach(items) { item in
                                NavigationLink(destination: CaseStudyDetailView(item: item)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                        Text(item.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("StateKit")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingInfo) {
                NavigationStack {
                    ScrollView {
                        StructuredText(markdown: mdString, syntaxExtensions: [.emoji([])])
                            .padding()
                    }
                    .navigationTitle("Overview")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingInfo = false }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Detail View

struct CaseStudyDetailView: View {
    fileprivate let item: CaseStudy

    var body: some View {
        Form {
            Section("Demo") {
                item.makeDemo()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }

            Section("Description") {
                Text(item.summary)
                    .font(.body)
                
                if !item.keywords.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(item.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Views

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxRowWidth = max(maxRowWidth, currentX)
        }

        return CGSize(width: maxRowWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Models

private enum DemoCategory: String, CaseIterable, Identifiable {
    case atoms, riverpod, state, effect, async

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atoms: return "StateKitAtoms"
        case .riverpod: return "Riverpods (Swift)"
        case .state: return "State Hooks"
        case .effect: return "Effect Hooks"
        case .async: return "Async Hooks"
        }
    }
}

private struct CaseStudy: Identifiable {
    let id: String
    let title: String
    let summary: String
    let category: DemoCategory
    let keywords: [String]
    let makeDemo: () -> AnyView

    init<Demo: View>(
        id: String,
        title: String,
        summary: String,
        category: DemoCategory,
        keywords: [String],
        @ViewBuilder demo: @escaping () -> Demo
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.keywords = keywords
        self.makeDemo = { AnyView(demo()) }
    }
}

#Preview {
    ContentView()
}
