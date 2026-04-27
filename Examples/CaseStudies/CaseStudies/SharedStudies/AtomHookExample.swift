import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI

struct AtomHookExample: View {
    var body: some View {
        StateScope {
            let draft = useBinding("")
            let (count, setCount) = useAtomState(CounterAtom())
            let name = useAtomBinding(NameAtom())
            let formatted = useAtomValue(FormattedAtom())
            let resetCount = useAtomReset(CounterAtom())
            let refreshProfile = useAtomRefresher(FailingAtom())

            VStack(alignment: .leading, spacing: 16) {
                Text(formatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Local Draft", text: draft)
                    .textFieldStyle(.roundedBorder)

                TextField("Global Name", text: name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("+1 Count") {
                        setCount(count + 1)
                    }

                    Button("Reset") {
                        resetCount()
                    }

                    Button("Refresh") {
                        Task { await refreshProfile() }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
