import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@AtomFamily
private struct FamilyScoreAtom {
    let id: Int
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Int {
        return id * 10
    }
}

@SelectorFamily
private struct FamilyLabelAtom {
    let id: Int
    @MainActor
    func value(context: SKAtomTransactionContext) -> String {
        let score = context.watch(FamilyScoreAtom.family(id))
        return "Member \(id): \(score)"
    }
}

struct FamilyMacrosExampleView: View {
    var body: some View {
        Form {
            Section("atomFamily + selectorFamily") {
                ForEach([1, 2, 3], id: \.self) { memberID in
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
            let score = useAtomBinding(FamilyScoreAtom.family(memberID))
            let label = useAtomValue(FamilyLabelAtom.family(memberID))

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
