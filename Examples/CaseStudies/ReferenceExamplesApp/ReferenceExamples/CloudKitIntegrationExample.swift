import SwiftUI
import StateKitAtoms
import StateKitUI

private struct CloudNotesAtom: SKStateAtom, Hashable {
    typealias Value = [String]
    func defaultValue(context: SKAtomTransactionContext) -> [String] { ["Welcome"] }
}

private struct UnsyncedCountAtom: SKValueAtom, Hashable {
    typealias Value = Int
    func value(context: SKAtomTransactionContext) -> Int { context.watch(CloudNotesAtom()).count }
}

struct CloudKitIntegrationExampleView: View {
    @SKState(CloudNotesAtom()) private var notes
    @SKValue(UnsyncedCountAtom()) private var unsyncedCount

    var body: some View {
        Form {
            Section("Offline queue") {
                Button("Add local change") { notes.append("Note \(notes.count + 1)") }
                Button("Mark synced") { notes.removeAll() }
            }
            Section("Status") {
                LabeledContent("Unsynced", value: "\(unsyncedCount)")
            }
        }
        .navigationTitle("Cloud Sync")
    }
}
