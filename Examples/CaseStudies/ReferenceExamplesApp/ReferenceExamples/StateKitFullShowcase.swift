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
        "\(context.watch(FSNameAtom())) • \(context.watch(FSCountAtom()))"
    }
}

struct StateKitFullShowcaseView: View {
    @SKState(FSNameAtom()) private var name
    @SKState(FSCountAtom()) private var count
    @SKValue(FSBadgeAtom()) private var badge

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
