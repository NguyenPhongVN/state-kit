import SwiftUI
import StateKit
import StateKitAtoms
import StateKitUI

struct AtomRootView: View {
    var body: some View {
        SKAtomRoot {
            SharedStudiesShowcase()
        }
    }
}

struct SharedStudiesShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("StateKitAtoms examples")
                    .font(.title2.weight(.semibold))

                Text("Catalog nay gom cac example cho state atom, selector, async atom, family, context, hook bridge va scoped store.")
                    .foregroundStyle(.secondary)

                SharedCard(title: "State + selector") {
                    AtomStateExample()
                }

                SharedCard(title: "Async atoms") {
                    AtomTaskExample()
                }

                SharedCard(title: "Inline atoms") {
                    InlineAtomExample()
                }

                SharedCard(title: "Atom family") {
                    AtomFamilyExample()
                }

                SharedCard(title: "Imperative context") {
                    AtomContextExample()
                }

                SharedCard(title: "Hook bridge") {
                    AtomHookExample()
                }

                SharedCard(title: "Scoped store") {
                    ScopedStoreExample()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

struct AtomStateExample: View {
    @SKState(CounterAtom()) private var count
    @SKState(NameAtom()) private var name
    @SKValue(DoubledCounterAtom()) private var doubled
    @SKValue(FormattedAtom()) private var formatted

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formatted)
                .font(.headline)

            Text("Doubled value: \(doubled)")
                .foregroundStyle(.secondary)

            Stepper("Count: \(count)", value: $count)

            TextField("Shared name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AtomTaskExample: View {
    @SKState(RequestSeedAtom()) private var requestID
    @SKState(RequestShouldFailAtom()) private var shouldFail
    @SKTask(FetchAtom()) private var fetchPhase
    @SKTask(FailingAtom()) private var profilePhase
    @SKContext private var atomContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper("Request id: \(requestID)", value: $requestID, in: 1...9)
            Toggle("Force throwing atom to fail", isOn: $shouldFail)

            LabeledContent("FetchAtom", value: phaseDescription(fetchPhase))
            LabeledContent("FailingAtom", value: phaseDescription(profilePhase))

            HStack {
                Button("Refresh fetch") {
                    Task { await atomContext.refresh(FetchAtom()) }
                }

                Button("Refresh throwing") {
                    Task { await atomContext.refresh(FailingAtom()) }
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phaseDescription(_ phase: AsyncPhase<String>) -> String {
        switch phase {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading..."
        case .success(let value):
            return value
        case .failure(let error):
            return error.localizedDescription
        }
    }
}

struct InlineAtomExample: View {
    @SKState(inlineCounterAtom) private var count
    @SKState(inlineNameAtom) private var name
    @SKValue(inlineSummaryAtom) private var summary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.headline)

            Stepper("Inline count: \(count)", value: $count)

            TextField("Inline label", text: $name)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AtomFamilyExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(1..<4, id: \.self) { memberID in
                AtomFamilyRow(memberID: memberID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AtomFamilyRow: View {
    let memberID: Int

    var body: some View {
        StateScope {
            let score = useAtomBinding(memberScoreAtom(memberID))
            let label = useAtomValue(memberLabelAtom(memberID))

            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.subheadline.weight(.semibold))

                Stepper("Score: \(score.wrappedValue)", value: score, in: 0...100)
            }
        }
    }
}

struct AtomContextExample: View {
    @SKContext private var atomContext
    @State private var snapshot = "Tap Read"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Edit shared name", text: atomContext.binding(for: NameAtom()))
                .textFieldStyle(.roundedBorder)

            Text(snapshot)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
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
                    snapshot = "Counter atom evicted. Next read recreates it."
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AtomHookExample: View {
    var body: some View {
        StateScope {
            let draft = useBinding("")
            let (count, setCount) = useAtomState(CounterAtom())
            let name = useAtomBinding(NameAtom())
            let formatted = useAtomValue(FormattedAtom())
            let resetCount = useAtomReset(CounterAtom())
            let refreshProfile = useAtomRefresher(FailingAtom())

            VStack(alignment: .leading, spacing: 12) {
                Text("Local draft and global atoms in one StateScope")
                    .font(.headline)

                Text(formatted)
                    .foregroundStyle(.secondary)

                TextField("Local draft", text: draft)
                    .textFieldStyle(.roundedBorder)

                TextField("Global name", text: name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("+1 global count") {
                        setCount(count + 1)
                    }

                    Button("Reset count") {
                        resetCount()
                    }

                    Button("Refresh async atom") {
                        Task { await refreshProfile() }
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ScopedStoreExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Outer store")
                .font(.headline)
            ScopedCounterPanel()

            Divider()

            Text("Fresh scoped store")
                .font(.headline)
            SKAtomScopeView {
                ScopedCounterPanel()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScopedCounterPanel: View {
    @SKState(scopedCounterAtom) private var count

    var body: some View {
        HStack {
            Stepper("Scoped count: \(count)", value: $count)
            Button("Reset") {
                count = 0
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct SharedCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    AtomRootView()
}
