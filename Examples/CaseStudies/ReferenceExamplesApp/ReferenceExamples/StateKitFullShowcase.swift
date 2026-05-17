import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct FSNameAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> String { "StateKit" }
}

@StateAtom
private struct FSCountAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

@ValueAtom
private struct FSBadgeAtom {
    @MainActor
    func value(context: SKAtomTransactionContext) -> String {
        "\(context.watch(FSNameAtom.shared)) • \(context.watch(FSCountAtom.shared))"
    }
}

struct StateKitFullShowcaseView: View {
    @SKState(FSNameAtom.shared) private var name
    @SKState(FSCountAtom.shared) private var count
    @SKValue(FSBadgeAtom.shared) private var badge

    var body: some View {
        Form {
            Section("Atoms") {
                LabeledContent("Badge", value: badge)
                TextField("Name", text: $name)
                Stepper("Count: \(count)", value: $count)
            }
        }
        .navigationTitle("StateKit Showcase")
    }
}

#Preview {
    NavigationStack {
        StateKitFullShowcaseView()
    }
}
