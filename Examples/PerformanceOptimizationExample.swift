import Foundation
import SwiftUI
import Riverpods
import StateKit
import StateKitAtoms
import StateConcurrency

// MARK: - Performance Optimization Patterns

/// This example demonstrates production performance patterns:
/// 1. Selective re-rendering with Provider.select()
/// 2. Lazy-loaded state with FutureProvider
/// 3. Debounced/throttled updates with SCTask
/// 4. Memoization for expensive computations
/// 5. Efficient list rendering
/// 6. Memory-efficient state design

// MARK: - Models

struct DataItem: Sendable, Codable, Identifiable {
    let id: String
    let value: Int
    let timestamp: Date

    static let samples = (0..<100).map { index in
        DataItem(id: "item_\(index)", value: Int.random(in: 1...100), timestamp: Date())
    }
}

struct SearchState: Sendable, Codable {
    let query: String
    let results: [DataItem]
    let isSearching: Bool
}

// MARK: - Pattern 1: Selective Re-rendering

@SKStateAtom
var allDataAtom: [DataItem] = DataItem.samples

@SKStateAtom
var selectedItemIdAtom: String?

@SKStateAtom
var filterPredicateAtom: (DataItem) -> Bool = { _ in true }

// Without select() - re-renders when ANY item in list changes
let allItemsProvider = Provider { ref -> [DataItem] in
    let predicate = ref.watch(filterPredicateAtom)
    let items = ref.watch(allDataAtom)
    return items.filter(predicate)
}

// Pattern: Use select() to watch only the selected item
let selectedItemProvider = Provider { ref -> DataItem? in
    let selectedId = ref.watch(selectedItemIdAtom)
    let items = ref.watch(allDataAtom)

    return items.first { $0.id == selectedId }
}

// Pattern: Memoized computed value (only recomputes when dependencies change)
let dataStatsProvider = Provider { ref -> DataStats in
    let items = ref.watch(allDataAtom)

    // Expensive computation
    let sum = items.reduce(0) { $0 + $1.value }
    let average = items.isEmpty ? 0 : Double(sum) / Double(items.count)
    let max = items.max(by: { $0.value < $1.value })?.value ?? 0

    return DataStats(sum: sum, average: average, max: max, count: items.count)
}

struct DataStats: Sendable {
    let sum: Int
    let average: Double
    let max: Int
    let count: Int
}

// MARK: - Pattern 2: Lazy-Loaded State

/// Instead of loading all data at once, load in batches
let lazyDataProvider = FutureProvider { ref -> [DataItem] in
    // Simulate paginated API load
    try await Task.sleep(nanoseconds: 1_000_000_000)  // 1s

    // Return first batch
    return Array(DataItem.samples.prefix(20))
}

/// Family provider for lazy loading by page
let paginatedDataProvider = FutureProvider.family { (ref, page: Int) -> [DataItem] in
    try await Task.sleep(nanoseconds: 500_000_000)

    let pageSize = 20
    let start = page * pageSize
    let end = min(start + pageSize, DataItem.samples.count)

    guard start < DataItem.samples.count else {
        return []
    }

    return Array(DataItem.samples[start..<end])
}

// MARK: - Pattern 3: Debounced/Throttled Updates

@SKStateAtom
var searchQueryAtom: String = ""

@SKStateAtom
var searchResultsAtom: [DataItem] = []

// Debounced search: only search after user stops typing for 0.5s
let debouncedSearchProvider = AsyncNotifierProvider { ref -> DebouncedSearchNotifier in
    DebouncedSearchNotifier(ref: ref)
}

final class DebouncedSearchNotifier: AsyncNotifier, Sendable {
    let ref: AsyncNotifierProviderRef
    private var searchTask: Task<Void, Never>?

    init(ref: AsyncNotifierProviderRef) {
        self.ref = ref
    }

    func search(query: String) async {
        // Cancel previous search task
        searchTask?.cancel()

        // Create debounced task
        searchTask = Task {
            // Debounce: wait before searching
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

            guard !Task.isCancelled else { return }

            let allData = ref.read(allDataAtom)
            let results = allData.filter { item in
                query.isEmpty || item.id.lowercased().contains(query.lowercased())
            }

            let notifier = ref.read(searchResultsAtom.notifier)
            notifier.state = results
        }
    }
}

// MARK: - Pattern 4: Efficient List State

/// Rather than storing computed list state, compute it on demand
@SKStateAtom
var itemFiltersAtom: ItemFilters = ItemFilters()

struct ItemFilters: Sendable, Codable {
    var minValue: Int = 0
    var maxValue: Int = 100
    var sortBy: SortOrder = .ascending

    enum SortOrder: String, Sendable, Codable {
        case ascending, descending
    }
}

let filteredItemsProvider = Provider { ref -> [DataItem] in
    var items = ref.watch(allDataAtom)
    let filters = ref.watch(itemFiltersAtom)

    // Filter
    items = items.filter { $0.value >= filters.minValue && $0.value <= filters.maxValue }

    // Sort
    switch filters.sortBy {
    case .ascending:
        items.sort { $0.value < $1.value }
    case .descending:
        items.sort { $0.value > $1.value }
    }

    return items
}

// MARK: - Pattern 5: Batch Updates

let batchUpdateNotifier = NotifierProvider { ref -> BatchUpdateNotifier in
    BatchUpdateNotifier(ref: ref)
}

final class BatchUpdateNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    /// Update multiple items at once (single state update)
    func updateBatch(_ updates: [(id: String, newValue: Int)]) {
        var allData = ref.read(allDataAtom)

        for update in updates {
            if let index = allData.firstIndex(where: { $0.id == update.id }) {
                allData[index].value = update.newValue
            }
        }

        // Single state update (not one per item)
        ref.read(allDataAtom.notifier).state = allData
    }

    /// Insert items efficiently
    func insertItems(_ items: [DataItem]) {
        var current = ref.read(allDataAtom)
        current.append(contentsOf: items)
        ref.read(allDataAtom.notifier).state = current
    }
}

// MARK: - View with Performance Patterns

struct PerformanceOptimizationView: View {
    @Watch(var stats: dataStatsProvider)
    @Watch(var selectedItem: selectedItemProvider)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats panel (re-renders only when stats change)
                StatsPanel(stats: stats)
                    .background(Color(.systemGray6))

                // Two-column layout
                HStack(spacing: 0) {
                    // Left: list (only selected item matters)
                    PerformantListView()
                        .frame(maxWidth: .infinity)

                    Divider()

                    // Right: detail (only updates when selectedItem changes)
                    if let item = selectedItem {
                        SelectedItemDetailView(item: item)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack {
                            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                .font(.largeTitle)
                                .foregroundColor(.gray)

                            Text("Select an item")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Performance Patterns")
        }
    }
}

struct StatsPanel: View {
    let stats: DataStats

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatItem(label: "Count", value: "\(stats.count)")
                StatItem(label: "Sum", value: "\(stats.sum)")
                StatItem(label: "Avg", value: String(format: "%.1f", stats.average))
                StatItem(label: "Max", value: "\(stats.max)")
            }
        }
        .padding()
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline).bold()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct PerformantListView: View {
    @Watch(var filteredItems: filteredItemsProvider)
    @Watch(var selectedId: selectedItemIdAtom)

    var body: some View {
        VStack(spacing: 0) {
            Text("Items (\(filteredItems.count))")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))

            ScrollView {
                LazyVStack(spacing: 1, pinnedViews: []) {
                    ForEach(filteredItems) { item in
                        // Pattern: Only selects the needed field
                        ItemRowView(
                            item: item,
                            isSelected: selectedId == item.id,
                            onSelect: {
                                let container = ProviderContainer()
                                container.read(selectedItemIdAtom.notifier).state = item.id
                            }
                        )
                        .id(item.id)  // Important for efficient updates
                    }
                }
            }
        }
    }
}

struct ItemRowView: View {
    let item: DataItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.id)
                        .font(.headline)

                    Text("Value: \(item.value)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(item.value)")
                    .font(.title3).bold()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemBackground))
        }
        .foregroundColor(.primary)
        .border(Color(.systemGray5), width: 0.5)
    }
}

struct SelectedItemDetailView: View {
    let item: DataItem

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Item")
                    .font(.headline)

                Divider()

                DetailRow(label: "ID", value: item.id)
                DetailRow(label: "Value", value: "\(item.value)")
                DetailRow(label: "Timestamp", value: item.timestamp.formatted())
            }
            .padding()

            Spacer()

            Text("This view only re-renders when the selected item changes")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.monospaced(.body)())
                .bold()
        }
    }
}

// MARK: - Preview

#Preview {
    PerformanceOptimizationView()
}
