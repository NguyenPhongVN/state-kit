import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI

private struct HKCounterAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

struct HookMacrosExtendedExampleView: View {
    var body: some View {
        StateScope {
            let draft = useBinding("")
            let (count, setCount) = useAtomState(HKCounterAtom())
            let reset = useAtomReset(HKCounterAtom())

            Form {
                Section("StateScope hooks") {
                    TextField("Local draft", text: draft)
                    LabeledContent("Atom count", value: "\(count)")
                }
                Section("Actions") {
                    Button("+1") { setCount(count + 1) }
                    Button("-1") { setCount(count - 1) }
                    Button("Reset") { reset() }
                }
            }
        }
        .navigationTitle("Atom Hooks")
    }
}
