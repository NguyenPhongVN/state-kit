import SwiftUI

// MARK: - Main DevTools View

/// The main StateKit DevTools debugging overlay.
///
/// Displays state history, performance metrics, and provides time-travel debugging controls.
///
/// **Usage:**
/// ```swift
/// #if DEBUG
/// @Environment(\.providerContainer) var container
///
/// var body: some View {
///     ZStack {
///         MyAppView()
///
///         StateDevTools(observer: devTools)
///             .ignoresSafeArea()
///     }
/// }
/// #endif
/// ```
///
/// **Features:**
/// - Real-time state history browser
/// - Performance metrics dashboard
/// - Time-travel navigation
/// - State comparison view
/// - Export/import functionality
/// - Configurable appearance
@MainActor
public struct StateDevTools: View {
    /// The DevTools observer instance.
    @ObservedObject private var observer: ObservedDevToolsObserver

    /// Currently selected tab.
    @State private var selectedTab: Tab = .history

    /// Whether to show detailed view.
    @State private var showDetails = false

    /// Search query for filtering.
    @State private var searchQuery = ""

    enum Tab: String, CaseIterable {
        case history = "History"
        case metrics = "Metrics"
        case inspector = "Inspector"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .history: return "clock.arrow.circlepath"
            case .metrics: return "chart.bar"
            case .inspector: return "magnifyingglass"
            case .settings: return "gear"
            }
        }
    }

    public init(observer: DevToolsObserver) {
        self.observer = ObservedDevToolsObserver(observer: observer)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("StateKit DevTools")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showDetails.toggle() }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(showDetails ? 90 : 0))
                }
                .padding(.trailing)
            }
            .padding()
            .background(Color.black.opacity(0.7))

            if showDetails {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14))
                                Text(tab.rawValue)
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedTab == tab ? .blue : .gray)
                            .background(selectedTab == tab ? Color.white.opacity(0.1) : Color.clear)
                        }
                    }
                }
                .background(Color.black.opacity(0.5))
                .border(Color.white.opacity(0.1), width: 1)

                // Content
                TabView(selection: $selectedTab) {
                    HistoryTabView(observer: observer, searchQuery: $searchQuery)
                        .tag(Tab.history)

                    MetricsTabView(observer: observer, searchQuery: $searchQuery)
                        .tag(Tab.metrics)

                    InspectorTabView(observer: observer)
                        .tag(Tab.inspector)

                    SettingsTabView(observer: observer)
                        .tag(Tab.settings)
                }
                .frame(height: 300)
            }
        }
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(12)
        .padding()
        .zIndex(1000)
    }
}

// MARK: - Observed Wrapper (for binding)

@MainActor
class ObservedDevToolsObserver: ObservableObject {
    @Published var observer: DevToolsObserver

    init(observer: DevToolsObserver) {
        self.observer = observer
    }
}

// MARK: - History Tab

struct HistoryTabView: View {
    @ObservedObject var observer: ObservedDevToolsObserver
    @Binding var searchQuery: String
    @State private var selectedIndex: Int?

    var filteredEntries: [HistoryEntry] {
        observer.observer.history.entries.filter { entry in
            searchQuery.isEmpty ||
                (entry.action?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search history...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            .padding()

            // History list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.offset) { idx, entry in
                        HistoryEntryView(
                            entry: entry,
                            index: idx,
                            isSelected: selectedIndex == idx,
                            onSelect: { selectedIndex = idx }
                        )
                    }
                }
                .padding()
            }

            // Controls
            HStack(spacing: 12) {
                Button(action: {
                    _ = observer.observer.goBack()
                }) {
                    Image(systemName: "arrow.left")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!observer.observer.history.canGoBack)

                Button(action: {
                    _ = observer.observer.goForward()
                }) {
                    Image(systemName: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!observer.observer.history.canGoForward)

                Button(action: {
                    observer.observer.clearHistory()
                }) {
                    Image(systemName: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
}

struct HistoryEntryView: View {
    let entry: HistoryEntry
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.action ?? "initialization")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(String(format: "%.2fms", entry.computeTime))
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
        .cornerRadius(6)
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Metrics Tab

struct MetricsTabView: View {
    @ObservedObject var observer: ObservedDevToolsObserver
    @Binding var searchQuery: String
    @State private var sortBy: SortOption = .computeTime

    enum SortOption: String, CaseIterable {
        case computeTime = "Slowest"
        case frequency = "Frequent"
        case calls = "Most Called"
    }

    var sortedMetrics: [PerformanceData] {
        let metrics = observer.observer.metrics.allMetrics.filter { metric in
            searchQuery.isEmpty ||
                metric.providerName.localizedCaseInsensitiveContains(searchQuery)
        }

        switch sortBy {
        case .computeTime:
            return metrics.sorted { $0.averageComputeTime > $1.averageComputeTime }
        case .frequency:
            return metrics.sorted { $0.updateFrequency > $1.updateFrequency }
        case .calls:
            return metrics.sorted { $0.totalCallCount > $1.totalCallCount }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter controls
            HStack {
                Picker("Sort", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()
            }
            .padding()

            // Metrics list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedMetrics, id: \.providerName) { metric in
                        MetricCardView(metric: metric)
                    }
                }
                .padding()
            }
        }
    }
}

struct MetricCardView: View {
    let metric: PerformanceData

    var scoreColor: Color {
        switch metric.performanceScore {
        case 80...: return .green
        case 50...: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.providerName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Text("\(metric.performanceScore)")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(scoreColor)
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg Time")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f ms", metric.averageComputeTime))
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Frequency")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f Hz", metric.updateFrequency))
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calls")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(metric.totalCallCount)")
                        .font(.caption)
                }

                Spacer()
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Color.white.opacity(0.1)

                    Color.blue.opacity(0.5)
                        .frame(width: geometry.size.width *
                            min(metric.averageComputeTime / 100, 1.0))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Inspector Tab

struct InspectorTabView: View {
    @ObservedObject var observer: ObservedDevToolsObserver

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current State")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                if observer.observer.history.currentIndex >= 0 {
                    Text("[\(observer.observer.history.currentIndex)]")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            ScrollView {
                if let currentState = observer.observer.history.currentState {
                    VStack(alignment: .leading, spacing: 0) {
                        StateValueView(value: String(describing: currentState.value))
                    }
                    .padding()
                } else {
                    Text("No state recorded")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                }
            }

            Spacer()

            // Export button
            Button(action: {
                let json = observer.observer.exportAsJSON()
                UIPasteboard.general.string = json
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Export")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
}

struct StateValueView: View {
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.cyan)
                .lineLimit(10)
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(4)
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @ObservedObject var observer: ObservedDevToolsObserver
    @State private var maxHistory: Int = 100
    @State private var debugLogging = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration")
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack {
                    Text("Max History")
                        .font(.caption)

                    Spacer()

                    Stepper("", value: $maxHistory, in: 10...500, step: 10)
                        .onChange(of: maxHistory) { newValue in
                            observer.observer.maxHistoryEntries = newValue
                        }

                    Text("\(maxHistory)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(width: 40)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 8) {
                Text("Features")
                    .font(.caption)
                    .fontWeight(.semibold)

                Toggle("Debug Logging", isOn: $debugLogging)
                    .onChange(of: debugLogging) { newValue in
                        observer.observer.debugLoggingEnabled = newValue
                    }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)

            Spacer()
        }
        .padding()
        .onAppear {
            maxHistory = observer.observer.maxHistoryEntries
            debugLogging = observer.observer.debugLoggingEnabled
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            Text("App Content")
                .foregroundColor(.white)
            Spacer()
        }

        StateDevTools(observer: DevToolsObserver())
            .ignoresSafeArea()
    }
}
#endif
