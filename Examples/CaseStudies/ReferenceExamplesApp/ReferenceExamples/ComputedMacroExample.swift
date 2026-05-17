import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct ComputedCountAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

@StateAtom
private struct ComputedNameAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> String { "StateKit" }
}

@Computed
private struct ComputedDoubleAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> Int {
        context.watch(ComputedCountAtom.shared) * 2
    }
}

@Computed
private struct ComputedSummaryAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> String {
        let name = context.watch(ComputedNameAtom.shared)
        let count = context.watch(ComputedCountAtom.shared)
        return "\(name): \(count)"
    }
}

struct ComputedMacroExampleView: View {
    @SKState(ComputedCountAtom.shared) private var count
    @SKState(ComputedNameAtom.shared) private var name
    @SKValue(ComputedDoubleAtom.shared) private var doubled
    @SKValue(ComputedSummaryAtom.shared) private var summary

    var body: some View {
        Form {
            Section("Computed API") {
                LabeledContent("Summary", value: summary)
                LabeledContent("Doubled", value: "\(doubled)")
            }
            Section("Inputs") {
                Stepper("Count: \(count)", value: $count)
                TextField("Name", text: $name)
            }
        }
        .navigationTitle("Computed Atom")
    }
}

#Preview {
    NavigationStack {
        ComputedMacroExampleView()
    }
}
