import SwiftUI
import StateKitAtoms

struct InlineAtomExample: View {
    @SKState(inlineCounterAtom) private var count
    @SKState(inlineNameAtom) private var name
    @SKValue(inlineSummaryAtom) private var summary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary)
                .font(.subheadline.weight(.medium))

            Stepper("Inline Count: \(count)", value: $count)

            TextField("Inline Label", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }
}
