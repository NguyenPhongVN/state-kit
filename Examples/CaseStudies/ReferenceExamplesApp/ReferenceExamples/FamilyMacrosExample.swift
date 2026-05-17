import SwiftUI
import StateKitAtoms
import StateKitUI

private let familyScoreAtom = atomFamily { (id: Int) in id * 10 }
private let familyLabelAtom = selectorFamily { (id: Int, context: SKAtomTransactionContext) in
    let score = context.watch(familyScoreAtom(id))
    return "Member \(id): \(score)"
}

struct FamilyMacrosExampleView: View {
    var body: some View {
        Form {
            Section("atomFamily + selectorFamily") {
                ForEach(1...3, id: \.self) { memberID in
                    FamilyRow(memberID: memberID)
                }
            }
        }
        .navigationTitle("Family Atoms")
    }
}

private struct FamilyRow: View {
    let memberID: Int

    var body: some View {
        SKAtomScopeView {
            let score = useAtomBinding(familyScoreAtom(memberID))
            let label = useAtomValue(familyLabelAtom(memberID))

            HStack {
                Text(label)
                Spacer()
                Stepper("", value: score)
                    .labelsHidden()
            }
        }
    }
}

#Preview {
    NavigationStack {
        FamilyMacrosExampleView()
    }
}
