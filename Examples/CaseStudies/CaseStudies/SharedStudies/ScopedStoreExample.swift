import SwiftUI
import StateKitAtoms
import StateKitUI

struct ScopedStoreExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Outer Store")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ScopedCounterPanel()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Fresh Scoped Store")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                SKAtomScopeView {
                    ScopedCounterPanel()
                }
            }
        }
    }
}

private struct ScopedCounterPanel: View {
    @SKState(scopedCounterAtom) private var count

    var body: some View {
        HStack {
            Stepper("Count: \(count)", value: $count)
            Spacer()
            Button("Reset") {
                count = 0
            }
            .buttonStyle(.bordered)
        }
    }
}
