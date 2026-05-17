import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

@StateAtom
private struct AsyncSeedAtom {
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

@StateAtom
private struct AsyncFailAtom {
    func defaultValue(context: SKAtomTransactionContext) -> Bool { false }
}

private enum AsyncDemoError: LocalizedError {
    case forced
    var errorDescription: String? { "Forced error for demo." }
}

@ThrowingTaskAtom
private struct AsyncProfileAtom {
    func task(context: SKAtomTransactionContext) async throws -> String {
        let id = context.watch(AsyncSeedAtom.shared)
        let shouldFail = context.watch(AsyncFailAtom.shared)
        try await Task.sleep(nanoseconds: 500_000_000)
        if shouldFail { throw AsyncDemoError.forced }
        return "Loaded profile #\(id)"
    }
}

struct AsyncHookMacroExampleView: View {
    @SKState(AsyncSeedAtom.shared) private var requestID
    @SKState(AsyncFailAtom.shared) private var shouldFail
    @SKTask(AsyncProfileAtom.shared) private var profile
    @SKContext private var atomContext

    var body: some View {
        Form {
            Section("Async Atom API") {
                Stepper("Request: \(requestID)", value: $requestID, in: 1...9)
                Toggle("Force failure", isOn: $shouldFail)
                Button("Refresh") {
                    Task { await atomContext.refresh(AsyncProfileAtom.shared) }
                }
            }
            Section("Phase") {
                Text(phaseText)
            }
        }
        .navigationTitle("Async Task Atom")
    }

    private var phaseText: String {
        switch profile {
        case .idle: return "Idle"
        case .loading: return "Loading..."
        case .success(let value): return value
        case .failure(let error): return error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        AsyncHookMacroExampleView()
    }
}
