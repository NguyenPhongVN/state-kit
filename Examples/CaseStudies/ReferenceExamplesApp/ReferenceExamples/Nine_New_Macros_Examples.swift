import SwiftUI
import Riverpods

private let searchProvider = StateProvider { _ in "" }
private let debouncedResultsProvider = Provider { ref in
    let q = ref.watch(searchProvider)
    let pool = ["StateKit", "Riverpods", "Atoms", "Selectors", "Hooks", "Families"]
    guard !q.isEmpty else { return pool }
    return pool.filter { $0.localizedCaseInsensitiveContains(q) }
}

struct NineNewMacrosExamplesView: View {
    @Watch(searchProvider) var query
    @Watch(debouncedResultsProvider) var results
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            Section("Composed Providers") {
                TextField("Search APIs", text: Binding(
                    get: { query },
                    set: { container.read(searchProvider.notifier).state = $0 }
                ))
            }
            Section("Results") {
                ForEach(results, id: \.self) { Text($0) }
            }
        }
        .navigationTitle("Provider Compose")
    }
}
