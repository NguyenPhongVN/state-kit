import SwiftUI
import Riverpods

struct Flags: Hashable {
    var newCheckout = false
    var recommendations = true
    var debugBanner = false
}

private let flagsProvider = StateProvider { _ in Flags() }
private let enabledCountProvider = Provider { ref in
    let f = ref.watch(flagsProvider)
    return [f.newCheckout, f.recommendations, f.debugBanner].filter { $0 }.count
}

struct FeatureFlagsExampleView: View {
    @Watch(flagsProvider) var flags
    @Watch(enabledCountProvider) var enabledCount
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            Section("Flags (StateProvider)") {
                Toggle("New checkout", isOn: binding(\.newCheckout))
                Toggle("Recommendations", isOn: binding(\.recommendations))
                Toggle("Debug banner", isOn: binding(\.debugBanner))
            }
            Section("Derived") {
                LabeledContent("Enabled", value: "\(enabledCount)/3")
            }
        }
        .navigationTitle("Feature Flags")
    }

    private func binding(_ keyPath: WritableKeyPath<Flags, Bool>) -> Binding<Bool> {
        Binding(
            get: { flags[keyPath: keyPath] },
            set: { newValue in
                var updated = flags
                updated[keyPath: keyPath] = newValue
                container.read(flagsProvider.notifier).state = updated
            }
        )
    }
}
