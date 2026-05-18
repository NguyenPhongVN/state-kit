import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

private let allItems = (1...500).map { "Item-\($0)" }

@StateAtom
private struct QueryAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> String { "" }
}

@Computed
private struct FilteredItemsAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> [String] {
        let query = context.watch(QueryAtom())
        guard !query.isEmpty else {
            return Array(allItems.prefix(30))
        }
        return Array(allItems.filter { $0.localizedCaseInsensitiveContains(query) }.prefix(30))
    }
}

struct PerformanceOptimizationExampleView: View {
    @SKState(QueryAtom()) private var query
    @SKValue(FilteredItemsAtom()) private var filtered

    var body: some View {
        Form {
            Section("Filter") {
                TextField("Type to filter 500 items", text: $query)
                LabeledContent("Rendered", value: "\(filtered.count)")
            }
            Section("Results") {
                ForEach(filtered, id: \.self) {
                    Text($0).font(.footnote.monospaced())
                }
            }
        }
        .navigationTitle("Performance")
    }
}

#Preview {
    NavigationStack {
        PerformanceOptimizationExampleView()
    }
}
