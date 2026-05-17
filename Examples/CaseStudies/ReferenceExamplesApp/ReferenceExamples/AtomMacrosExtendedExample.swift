import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct AMCountAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

@StateAtom
private struct AMNameAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> String { "Guest" }
}

@ValueAtom
private struct AMSummaryAtom {
    @MainActor
    func value(context: SKAtomTransactionContext) -> String {
        "\(context.watch(AMNameAtom.shared)) #\(context.watch(AMCountAtom.shared))"
    }
}

struct AtomMacrosExtendedExampleView: View {
    @SKState(AMCountAtom.shared) private var count
    @SKState(AMNameAtom.shared) private var name
    @SKValue(AMSummaryAtom.shared) private var summary
    @SKContext private var context

    var body: some View {
        Form {
            Section("@SKState + @SKValue") {
                LabeledContent("Summary", value: summary)
                Stepper("Count: \(count)", value: $count)
                TextField("Name", text: $name)
            }
            Section("Context") {
                Button("Reset count") { context.reset(AMCountAtom.shared) }
                Button("Set to 42") { context.set(42, for: AMCountAtom.shared) }
            }
        }
        .navigationTitle("Atom State")
    }
}

#Preview {
    NavigationStack {
        AtomMacrosExtendedExampleView()
    }
}
