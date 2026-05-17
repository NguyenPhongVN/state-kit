import SwiftUI
import StateKitAtoms
import StateKitUI

private struct AMCountAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

private struct AMNameAtom: SKStateAtom, Hashable {
    typealias Value = String
    func defaultValue(context: SKAtomTransactionContext) -> String { "Guest" }
}

private struct AMSummaryAtom: SKValueAtom, Hashable {
    typealias Value = String
    func value(context: SKAtomTransactionContext) -> String {
        "\(context.watch(AMNameAtom())) #\(context.watch(AMCountAtom()))"
    }
}

struct AtomMacrosExtendedExampleView: View {
    @SKState(AMCountAtom()) private var count
    @SKState(AMNameAtom()) private var name
    @SKValue(AMSummaryAtom()) private var summary
    @SKContext private var context

    var body: some View {
        Form {
            Section("@SKState + @SKValue") {
                LabeledContent("Summary", value: summary)
                Stepper("Count: \(count)", value: $count)
                TextField("Name", text: $name)
            }
            Section("Context") {
                Button("Reset count") { context.reset(AMCountAtom()) }
                Button("Set to 42") { context.set(42, for: AMCountAtom()) }
            }
        }
        .navigationTitle("Atom State")
    }
}
