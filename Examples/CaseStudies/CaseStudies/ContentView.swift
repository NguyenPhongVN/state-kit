import SwiftUI
import Textual

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var selectedCategory: DemoCategory?
    @State private var expandedStudyIDs: Set<String> = ["atomState", "atomTask", "useState", "useAsync"]
    @State private var showsOverview = false

    private let mdString: String = {
        let url = Bundle.main.url(forResource: "StateKit", withExtension: "md")!
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    private var studies: [CaseStudy] {
        [
            CaseStudy(
                id: "atomState",
                title: "State atoms",
                summary: "Doc, ghi va derive du lieu bang @SKState va @SKValue tren cung store.",
                category: .atoms,
                keywords: ["atom", "selector", "shared store", "derived state"]
            ) { AtomStateExample() },
            CaseStudy(
                id: "atomTask",
                title: "Async atoms",
                summary: "Theo doi AsyncPhase cua task atom va throwing task atom, sau do refresh thu cong.",
                category: .atoms,
                keywords: ["async atom", "task", "refresh", "phase"]
            ) { AtomTaskExample() },
            CaseStudy(
                id: "atomInline",
                title: "Inline atoms",
                summary: "Tao atom va selector bang factory de co example ngan gon khong can named type.",
                category: .atoms,
                keywords: ["inline atom", "selector", "factory", "reference identity"]
            ) { InlineAtomExample() },
            CaseStudy(
                id: "atomFamily",
                title: "Atom family",
                summary: "Parameterize atom theo id de moi member co state rieng nhung cung mot factory.",
                category: .atoms,
                keywords: ["family", "parameterized", "per id", "shared logic"]
            ) { AtomFamilyExample() },
            CaseStudy(
                id: "atomContext",
                title: "Atom context",
                summary: "Doc, set, reset, binding va evict atom mot cach imperative trong action handler.",
                category: .atoms,
                keywords: ["context", "imperative", "binding", "evict"]
            ) { AtomContextExample() },
            CaseStudy(
                id: "atomHooks",
                title: "Atom hooks bridge",
                summary: "Mix local hook state voi global atoms bang useAtomState, useAtomBinding va useAtomRefresher.",
                category: .atoms,
                keywords: ["useAtomState", "useAtomBinding", "StateScope", "bridge"]
            ) { AtomHookExample() },
            CaseStudy(
                id: "atomScope",
                title: "Scoped atom store",
                summary: "Tach mot subtree sang store moi bang SKAtomScopeView de state khong bleed sang nhau.",
                category: .atoms,
                keywords: ["scope", "isolated store", "preview", "subtree"]
            ) { ScopedStoreExample() },
            CaseStudy(
                id: "useState",
                title: "useState",
                summary: "State cuc bo voi setter truc tiep cho nhung tuong tac co ban.",
                category: .state,
                keywords: ["local state", "counter", "setter"]
            ) { UseState() },
            CaseStudy(
                id: "useBinding",
                title: "useBinding",
                summary: "Noi state vao TextField, Toggle va Slider bang Binding quen thuoc.",
                category: .state,
                keywords: ["binding", "forms", "input"]
            ) { UseBinding() },
            CaseStudy(
                id: "useReducer",
                title: "useReducer",
                summary: "Group update vao action va reducer de logic ro rang hon.",
                category: .state,
                keywords: ["reducer", "actions", "state machine"]
            ) { UseReducer() },
            CaseStudy(
                id: "useRef",
                title: "useRef",
                summary: "Luu mutable value qua nhieu render ma khong bat buoc refresh UI.",
                category: .state,
                keywords: ["mutable ref", "imperative", "stable value"]
            ) { UseRef() },
            CaseStudy(
                id: "useMemo",
                title: "useMemo",
                summary: "Cache ket qua tinh toan de dependency nao doi thi moi tinh lai.",
                category: .state,
                keywords: ["memo", "cache", "dependencies"]
            ) { UseMemo() },
            CaseStudy(
                id: "useCallback",
                title: "useCallback",
                summary: "Giu callback identity on dinh cho den khi dependency thay doi.",
                category: .state,
                keywords: ["callback", "identity", "performance"]
            ) { UseCallback() },
            CaseStudy(
                id: "useContext",
                title: "useContext",
                summary: "Doc du lieu dung chung tu HookContext ma khong can prop drilling.",
                category: .state,
                keywords: ["context", "shared data", "composition"]
            ) { UseContext() },
            CaseStudy(
                id: "useEnvironment",
                title: "useEnvironment",
                summary: "Truy cap EnvironmentValues ngay trong StateScope.",
                category: .state,
                keywords: ["environment", "locale", "color scheme"]
            ) { UseEnvironment() },
            CaseStudy(
                id: "useOnChange",
                title: "useOnChange",
                summary: "Quan sat transition giua gia tri cu va moi de kich hoat side effect nhe.",
                category: .state,
                keywords: ["observer", "transitions", "callbacks"]
            ) { UseOnChange() },
            CaseStudy(
                id: "useEffect",
                title: "useEffect",
                summary: "Chay passive effect sau render va co cleanup ro rang.",
                category: .effect,
                keywords: ["effect", "cleanup", "side effects"]
            ) { UseEffect() },
            CaseStudy(
                id: "useLayoutEffect",
                title: "useLayoutEffect",
                summary: "Cho thay thu tu flush giua layout effect va passive effect.",
                category: .effect,
                keywords: ["layout", "flush order", "timing"]
            ) { UseLayoutEffect() },
            CaseStudy(
                id: "useAsync",
                title: "useAsync",
                summary: "Wrap mot task bat dong bo va tra phase loading, success, failure.",
                category: .async,
                keywords: ["async task", "phase", "retry"]
            ) { UseAsync() },
            CaseStudy(
                id: "useAsyncSequence",
                title: "useAsyncSequence",
                summary: "Theo doi stream AsyncSequence va hien emission moi nhat.",
                category: .async,
                keywords: ["stream", "async sequence", "events"]
            ) { UseAsyncSequence() },
            CaseStudy(
                id: "usePublisher",
                title: "usePublisher",
                summary: "Subscribe Combine publisher va bind phase vao UI.",
                category: .async,
                keywords: ["combine", "publisher", "subscription"]
            ) { UsePublisher() }
        ]
    }

    private var filteredStudies: [CaseStudy] {
        studies.filter { study in
            let matchesCategory = selectedCategory.map { study.category == $0 } ?? true
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery: Bool

            if trimmedQuery.isEmpty {
                matchesQuery = true
            } else {
                let haystack = ([study.title, study.summary] + study.keywords)
                    .joined(separator: " ")
                    .localizedLowercase
                matchesQuery = haystack.contains(trimmedQuery.localizedLowercase)
            }

            return matchesCategory && matchesQuery
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                heroSection
                overviewSection
                filterSection

                if filteredStudies.isEmpty {
                    emptyState
                } else {
                    ForEach(DemoCategory.allCases) { category in
                        let items = filteredStudies.filter { $0.category == category }
                        if !items.isEmpty {
                            CaseStudySection(
                                category: category,
                                items: items,
                                expandedStudyIDs: $expandedStudyIDs,
                                query: query
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("StateKit Studies")
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("StateKit hook demos")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Catalog nay gom scoped hooks va StateKitAtoms demos, co the tim nhanh, loc theo nhom va mo tung playground de test tuong tac ngay trong app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Text("CaseStudies")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(heroBadgeBackground, in: Capsule())

                    Text("\(studies.count) demos")
                        .font(.headline.monospacedDigit())
                }
            }

            HStack(spacing: 12) {
                MetricBadge(title: "Atoms", value: "\(studies(in: .atoms).count)", tint: .mint)
                MetricBadge(title: "State", value: "\(studies(in: .state).count)", tint: .blue)
                MetricBadge(title: "Effect", value: "\(studies(in: .effect).count)", tint: .orange)
                MetricBadge(title: "Async", value: "\(studies(in: .async).count)", tint: .green)
            }

            SearchField(text: $query)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 24, y: 14)
    }

    private var overviewSection: some View {
        DisclosureGroup(isExpanded: $showsOverview) {
            StructuredText(
                markdown: mdString,
                syntaxExtensions: [.emoji([])]
            )
            .padding(.top, 8)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Framework overview")
                        .font(.headline)
                    Text("Giu tai lieu trong app nhung khong lam dashboard bi qua dai ngay tu dau.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(showsOverview ? "Hide docs" : "Read docs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Browse demos")
                    .font(.title3.weight(.semibold))

                Spacer()

                if selectedCategory != nil || !query.isEmpty {
                    Button("Reset filters") {
                        selectedCategory = nil
                        query = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CategoryChip(
                        title: "All",
                        subtitle: "\(studies.count)",
                        isSelected: selectedCategory == nil,
                        tint: .blue
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(DemoCategory.allCases) { category in
                        CategoryChip(
                            title: category.title,
                            subtitle: "\(studies(in: category).count)",
                            isSelected: selectedCategory == category,
                            tint: category.tint
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Text("\(filteredStudies.count) demo\(filteredStudies.count == 1 ? "" : "s") dang hien thi")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Khong tim thay demo phu hop")
                .font(.headline)

            Text("Thu doi tu khoa, bo filter nhom hoac reset ve tat ca demo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Clear search") {
                query = ""
                selectedCategory = nil
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: colorScheme == .dark
                    ? UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1)
                    : UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1)),
                Color(uiColor: colorScheme == .dark
                    ? UIColor(red: 0.07, green: 0.11, blue: 0.10, alpha: 1)
                    : UIColor(red: 0.95, green: 0.98, blue: 0.97, alpha: 1)),
                Color(uiColor: colorScheme == .dark
                    ? UIColor(red: 0.10, green: 0.08, blue: 0.09, alpha: 1)
                    : UIColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 1))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBackground: some ShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(Color.white.opacity(0.06)) : AnyShapeStyle(.thinMaterial)
    }

    private var heroBadgeBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.75)
    }

    private func studies(in category: DemoCategory) -> [CaseStudy] {
        studies.filter { $0.category == category }
    }
}

private enum DemoCategory: String, CaseIterable, Identifiable {
    case atoms
    case state
    case effect
    case async

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atoms:
            return "StateKitAtoms"
        case .state:
            return "State Hooks"
        case .effect:
            return "Effect Hooks"
        case .async:
            return "Async Hooks"
        }
    }

    var subtitle: String {
        switch self {
        case .atoms:
            return "Global atom store, selectors, task atoms, families va store scoping."
        case .state:
            return "Nhung hook tap trung vao local state, reference va dependency."
        case .effect:
            return "Side effects, cleanup va thu tu flush cua lifecycle."
        case .async:
            return "Task, stream va publisher duoc dua ve mot UI model thong nhat."
        }
    }

    var icon: String {
        switch self {
        case .atoms:
            return "circle.grid.2x2.fill"
        case .state:
            return "square.stack.3d.up.fill"
        case .effect:
            return "sparkles.rectangle.stack"
        case .async:
            return "bolt.horizontal.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .atoms:
            return .mint
        case .state:
            return .blue
        case .effect:
            return .orange
        case .async:
            return .green
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

private struct CaseStudySection: View {
    let category: DemoCategory
    let items: [CaseStudy]
    @Binding var expandedStudyIDs: Set<String>
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(category.title, systemImage: category.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(category.tint)

                    Text(category.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Expand all") {
                        expandedStudyIDs.formUnion(items.map(\.id))
                    }
                    .buttonStyle(.plain)

                    Button("Collapse") {
                        expandedStudyIDs.subtract(items.map(\.id))
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            ForEach(items) { item in
                let isExpanded = query.isEmpty ? expandedStudyIDs.contains(item.id) : true
                CaseStudyCard(
                    item: item,
                    isExpanded: isExpanded,
                    toggleExpansion: {
                        if expandedStudyIDs.contains(item.id) {
                            expandedStudyIDs.remove(item.id)
                        } else {
                            expandedStudyIDs.insert(item.id)
                        }
                    }
                )
            }
        }
    }
}

private struct CaseStudyCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: CaseStudy
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.category.tint.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: item.category.icon)
                        .foregroundStyle(item.category.tint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.title)
                            .font(.headline)

                        Spacer(minLength: 0)

                        Text(item.category.rawValue.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.category.tint)
                    }

                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(item.category.tint.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }

            Button(action: toggleExpansion) {
                HStack {
                    Label(isExpanded ? "Hide interactive demo" : "Open interactive demo", systemImage: isExpanded ? "eye.slash" : "play.circle.fill")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(item.category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.category.tint)

            if isExpanded {
                Divider()

                item.makeDemo()
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.primary.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 18, y: 12)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isExpanded)
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.65)
    }
}

private struct SearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search by hook, concept, or keyword", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(searchBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(searchStroke, lineWidth: 1)
        )
    }

    private var searchBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.86)
    }

    private var searchStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.clear
    }
}

private struct MetricBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(metricBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var metricBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.72)
    }
}

private struct CategoryChip: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color.white.opacity(isSelected ? 0.22 : 0.14),
                        in: Capsule()
                    )
            }
            .foregroundStyle(isSelected ? Color.white : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? tint : tint.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
