import SwiftUI
import StateKitAtoms
import StateKitUI

private struct ComputedCountAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

private struct ComputedNameAtom: SKStateAtom, Hashable {
    typealias Value = String
    func defaultValue(context: SKAtomTransactionContext) -> String { "StateKit" }
}

private struct ComputedDoubleAtom: SKValueAtom, Hashable {
    typealias Value = Int
    func value(context: SKAtomTransactionContext) -> Int {
        context.watch(ComputedCountAtom()) * 2
    }
}

private struct ComputedSummaryAtom: SKValueAtom, Hashable {
    typealias Value = String
    func value(context: SKAtomTransactionContext) -> String {
        let name = context.watch(ComputedNameAtom())
        let count = context.watch(ComputedCountAtom())
        return "\(name): \(count)"
    }
}

struct ComputedMacroExampleView: View {
    @SKState(ComputedCountAtom()) private var count
    @SKState(ComputedNameAtom()) private var name
    @SKValue(ComputedDoubleAtom()) private var doubled
    @SKValue(ComputedSummaryAtom()) private var summary

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
