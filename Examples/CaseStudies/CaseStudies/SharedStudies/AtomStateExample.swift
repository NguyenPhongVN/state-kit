import SwiftUI
import StateKitAtoms

struct AtomStateExample: View {
    @SKState(CounterAtom()) private var count
    @SKState(NameAtom()) private var name
    @SKValue(DoubledCounterAtom()) private var doubled
    @SKValue(FormattedAtom()) private var formatted

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("Formatted", value: formatted)
            LabeledContent("Doubled", value: "\(doubled)")

            Divider()

            Stepper("Count: \(count)", value: $count)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Enter name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
