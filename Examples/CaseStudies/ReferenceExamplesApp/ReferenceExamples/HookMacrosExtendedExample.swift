import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct HKCounterAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

@HookView
struct HookMacrosExtendedExampleView: View {
    var stateBody: some View {
        let draft = useBinding("")
        let (count, setCount) = useAtomState(HKCounterAtom.shared)
        let reset = useAtomReset(HKCounterAtom.shared)

        return Form {
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
}

#Preview {
    NavigationStack {
        HookMacrosExtendedExampleView()
    }
}
