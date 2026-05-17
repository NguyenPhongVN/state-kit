import SwiftUI
import Riverpods

private let allItems = (1...500).map { "Item-\($0)" }
private let queryProvider = StateProvider { _ in "" }
private let filteredProvider = Provider { ref in
    let q = ref.watch(queryProvider)
    guard !q.isEmpty else { return Array(allItems.prefix(30)) }
    return allItems.filter { $0.localizedCaseInsensitiveContains(q) }.prefix(30).map { $0 }
}

struct PerformanceOptimizationExampleView: View {
    @Watch(queryProvider) var query
    @Watch(filteredProvider) var filtered
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            Section("Filter") {
                TextField("Type to filter 500 items", text: Binding(
                    get: { query },
                    set: { container.read(queryProvider.notifier).state = $0 }
                ))
                LabeledContent("Rendered", value: "\(filtered.count)")
            }
            Section("Results") {
                ForEach(filtered, id: \.self) { Text($0).font(.footnote.monospaced()) }
            }
        }
        .navigationTitle("Performance")
    }
}
