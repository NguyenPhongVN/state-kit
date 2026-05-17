import SwiftUI
import StateKitAtoms
import StateKitUI

private struct FSNameAtom: SKStateAtom, Hashable {
    typealias Value = String
    func defaultValue(context: SKAtomTransactionContext) -> String { "StateKit" }
}
private struct FSCountAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}
private struct FSBadgeAtom: SKValueAtom, Hashable {
    typealias Value = String
    func value(context: SKAtomTransactionContext) -> String { "\(context.watch(FSNameAtom())) • \(context.watch(FSCountAtom()))" }
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
