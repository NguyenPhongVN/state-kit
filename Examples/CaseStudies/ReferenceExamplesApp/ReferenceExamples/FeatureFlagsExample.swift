import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

struct Flags: Hashable {
    var newCheckout = false
    var recommendations = true
    var debugBanner = false
}

@StateAtom
private struct FlagsAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Flags { Flags() }
}

@Computed
private struct EnabledCountAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> Int {
        let flags = context.watch(FlagsAtom())
        return [flags.newCheckout, flags.recommendations, flags.debugBanner].filter { $0 }.count
    }
}

struct FeatureFlagsExampleView: View {
    @SKState(FlagsAtom()) private var flags
    @SKValue(EnabledCountAtom()) private var enabledCount

    var body: some View {
        Form {
            Section("Flags") {
                Toggle("New checkout", isOn: $flags.newCheckout)
                Toggle("Recommendations", isOn: $flags.recommendations)
                Toggle("Debug banner", isOn: $flags.debugBanner)
            }
            Section("Derived") {
                LabeledContent("Enabled", value: "\(enabledCount)/3")
            }
        }
        .navigationTitle("Feature Flags")
    }
}

#Preview {
    NavigationStack {
        FeatureFlagsExampleView()
    }
}
