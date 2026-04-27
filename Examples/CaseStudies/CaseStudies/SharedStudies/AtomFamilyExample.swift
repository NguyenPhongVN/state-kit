import SwiftUI
import StateKitAtoms
import StateKitUI

struct AtomFamilyExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(1..<4, id: \.self) { memberID in
                AtomFamilyRow(memberID: memberID)
                if memberID < 3 { Divider() }
            }
        }
    }
}

private struct AtomFamilyRow: View {
    let memberID: Int

    var body: some View {
        StateScope {
            let score = useAtomBinding(memberScoreAtom(memberID))
            let label = useAtomValue(memberLabelAtom(memberID))

            LabeledContent {
                Stepper("", value: score, in: 0...100)
                    .labelsHidden()
                Text("\(score.wrappedValue)")
                    .monospacedDigit()
                    .frame(width: 30, alignment: .trailing)
            } label: {
                Text(label)
                    .font(.body)
            }
        }
    }
}
