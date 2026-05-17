import SwiftUI
import Riverpods

private let observableCounterProvider = StateProvider { _ in 0 }
private let observableDoubleProvider = Provider { ref in
    ref.watch(observableCounterProvider) * 2
}

struct ObservableStateMacroExampleView: View {
    @Watch(observableCounterProvider) var count
    @Watch(observableDoubleProvider) var doubled
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            Section("Riverpods @Watch") {
                LabeledContent("Count", value: "\(count)")
                LabeledContent("Derived", value: "\(doubled)")
            }
            Section("Actions") {
                Button("-1") {
                    container.read(observableCounterProvider.notifier).state -= 1
                }
                Button("+1") {
                    container.read(observableCounterProvider.notifier).state += 1
                }
                Button("Reset") {
                    container.refresh(observableCounterProvider)
                }
            }
        }
        .navigationTitle("Riverpods State")
    }
}

#Preview {
    NavigationStack {
        ObservableStateMacroExampleView()
    }
}
