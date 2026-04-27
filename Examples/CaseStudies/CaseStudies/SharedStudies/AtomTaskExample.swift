import SwiftUI
import StateKitAtoms

struct AtomTaskExample: View {
    @SKState(RequestSeedAtom()) private var requestID
    @SKState(RequestShouldFailAtom()) private var shouldFail
    @SKTask(FetchAtom()) private var fetchPhase
    @SKTask(FailingAtom()) private var profilePhase
    @SKContext private var atomContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Stepper("Request ID: \(requestID)", value: $requestID, in: 1...9)
            Toggle("Force failure", isOn: $shouldFail)

            Divider()

            LabeledContent("Fetch Status", value: phaseDescription(fetchPhase))
            LabeledContent("Profile Status", value: phaseDescription(profilePhase))

            HStack {
                Button("Refresh Fetch") {
                    Task { await atomContext.refresh(FetchAtom()) }
                }

                Button("Refresh Profile") {
                    Task { await atomContext.refresh(FailingAtom()) }
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func phaseDescription(_ phase: AsyncPhase<String>) -> String {
        switch phase {
        case .idle: return "Idle"
        case .loading: return "Loading..."
        case .success(let value): return value
        case .failure(let error): return error.localizedDescription
        }
    }
}
