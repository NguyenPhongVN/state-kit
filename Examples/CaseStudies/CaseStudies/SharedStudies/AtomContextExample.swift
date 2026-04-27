import SwiftUI
import StateKitAtoms

struct AtomContextExample: View {
    @SKContext private var atomContext
    @State private var snapshot = "Tap Read"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Shared Name", text: atomContext.binding(for: NameAtom()))
                .textFieldStyle(.roundedBorder)

            Text(snapshot)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Read") {
                    let name = atomContext.read(NameAtom())
                    let count = atomContext.read(CounterAtom())
                    snapshot = "Read -> \(name): \(count)"
                }

                Button("Set 42") {
                    atomContext.set(42, for: CounterAtom())
                }

                Button("Reset") {
                    atomContext.reset(CounterAtom())
                }

                Button("Evict") {
                    atomContext.evict(CounterAtom())
                    snapshot = "Counter atom evicted."
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
